/**
 * Academy platform — SCORM material pipeline (2nd-gen Cloud Functions).
 *
 * Two functions:
 *
 *  1. processMaterialUpload  (Storage trigger)
 *     Fires when an admin uploads a `.zip` to `materials/{id}/…zip`. Unzips it
 *     into `materials/{id}/extracted/…`, parses `imsmanifest.xml` for the launch
 *     file + title, and updates the Firestore `materials/{id}` doc:
 *       status: uploaded → processing → ready | failed, plus `entry_point`.
 *
 *  2. serveScorm  (HTTP)
 *     Streams an extracted file so a SCORM package behaves like it's in a real
 *     LMS (relative URLs + inner iframe resolve). Reached same-origin via a
 *     Firebase Hosting rewrite: `/scorm/** → serveScorm` — see firebase.json.
 *     Same-origin matters: the SCO walks `window.parent.API`, which the browser
 *     blocks cross-origin.
 */

const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");
const { getFirestore } = require("firebase-admin/firestore");
const AdmZip = require("adm-zip");

initializeApp();

// Must match the Storage bucket's region (a storage-triggered function can only
// listen to a bucket in its own region). This project's bucket is us-east1.
const REGION = "us-east1";

// --- content types -------------------------------------------------------

const CONTENT_TYPES = {
  html: "text/html", htm: "text/html",
  js: "text/javascript", mjs: "text/javascript",
  css: "text/css",
  json: "application/json", xml: "application/xml",
  png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg",
  gif: "image/gif", svg: "image/svg+xml", webp: "image/webp",
  ico: "image/x-icon", bmp: "image/bmp",
  mp3: "audio/mpeg", ogg: "audio/ogg", wav: "audio/wav",
  mp4: "video/mp4", webm: "video/webm", m4v: "video/mp4",
  woff: "font/woff", woff2: "font/woff2", ttf: "font/ttf",
  otf: "font/otf", eot: "application/vnd.ms-fontobject",
  txt: "text/plain", pdf: "application/pdf",
  swf: "application/x-shockwave-flash",
};

function contentTypeFor(path) {
  const ext = (path.split(".").pop() || "").toLowerCase();
  return CONTENT_TYPES[ext] || "application/octet-stream";
}

// macOS "Compress" adds a `__MACOSX/` folder of resource forks (`._name`) and
// `.DS_Store` files. They must be ignored, or `._imsmanifest.xml` gets mistaken
// for the real manifest and `__MACOSX/` becomes the (wrong) package root.
function isJunkPath(name) {
  const base = name.split("/").pop();
  return name.startsWith("__MACOSX/") ||
    base.startsWith("._") ||
    base === ".DS_Store" ||
    base === "Thumbs.db";
}

// --- manifest parsing ----------------------------------------------------

/**
 * Finds the launch file from an `imsmanifest.xml` (relative to the manifest's
 * folder). Prefers the resource referenced by the first organization item;
 * falls back to the first resource with an `href`. Returns null if none.
 */
function parseEntryPoint(xml) {
  const resources = {};
  let firstHref = null;
  const resRe = /<resource\b[^>]*>/gi;
  let m;
  while ((m = resRe.exec(xml)) !== null) {
    const tag = m[0];
    const href = /href\s*=\s*"([^"]+)"/i.exec(tag);
    const id = /identifier\s*=\s*"([^"]+)"/i.exec(tag);
    if (href) {
      const value = decodeURIComponent(href[1]);
      if (id) resources[id[1]] = value;
      if (!firstHref) firstHref = value;
    }
  }
  const item = /<item\b[^>]*\bidentifierref\s*=\s*"([^"]+)"[^>]*>/i.exec(xml);
  if (item && resources[item[1]]) return resources[item[1]];
  return firstHref;
}

function parseTitle(xml) {
  const t = /<title>\s*([^<]+?)\s*<\/title>/i.exec(xml);
  return t ? t[1].trim() : null;
}

// Common launch file names, tried when the manifest has no usable href.
const FALLBACK_ENTRIES = [
  "index_lms.html", "index.html", "story.html", "index.htm",
  "launch.html", "scormdriver/indexAPI.html",
];

// --- 1. unzip + parse on upload ------------------------------------------

exports.processMaterialUpload = onObjectFinalized(
  { region: REGION, memory: "1GiB", timeoutSeconds: 300 },
  async (event) => {
    const object = event.data;
    const name = object.name || "";

    // Only handle the original zip: `materials/{id}/<file>.zip`, never our own
    // extracted output (which would retrigger).
    const match = /^materials\/([^/]+)\/[^/]+\.zip$/i.exec(name);
    if (!match || name.includes("/extracted/")) return;
    const materialId = match[1];

    const db = getFirestore();
    const docRef = db.collection("materials").doc(materialId);
    const bucket = getStorage().bucket(object.bucket);

    logger.info(`processMaterialUpload: ${name} → material ${materialId}`);
    await docRef.set({ status: "processing" }, { merge: true });

    try {
      const [buffer] = await bucket.file(name).download();
      const zip = new AdmZip(buffer);
      const entries = zip.getEntries();

      // Locate the manifest; its folder is the package root to strip so that
      // `extracted/` mirrors the package (entry + assets resolve at the root).
      const manifest = entries.find((e) =>
        !isJunkPath(e.entryName) &&
        e.entryName.toLowerCase().endsWith("imsmanifest.xml"));
      const rootPrefix = manifest
        ? manifest.entryName.slice(0, manifest.entryName.lastIndexOf("/") + 1)
        : "";

      // Upload every file under the root into `extracted/`.
      const relPaths = [];
      const uploads = [];
      for (const entry of entries) {
        if (entry.isDirectory) continue;
        if (isJunkPath(entry.entryName)) continue;
        if (rootPrefix && !entry.entryName.startsWith(rootPrefix)) continue;
        const rel = entry.entryName.slice(rootPrefix.length);
        if (!rel) continue;
        relPaths.push(rel);
        uploads.push(
          bucket.file(`materials/${materialId}/extracted/${rel}`).save(
            entry.getData(),
            { contentType: contentTypeFor(rel), resumable: false },
          ),
        );
      }
      await Promise.all(uploads);

      // Determine the launch file.
      let entryPoint = manifest ? parseEntryPoint(zip.readAsText(manifest)) : null;
      const title = manifest ? parseTitle(zip.readAsText(manifest)) : null;
      const lowerSet = new Set(relPaths.map((p) => p.toLowerCase()));
      if (!entryPoint || !lowerSet.has(entryPoint.toLowerCase())) {
        entryPoint = FALLBACK_ENTRIES.find((f) => lowerSet.has(f)) || entryPoint;
      }

      if (!entryPoint) {
        await docRef.set({
          status: "failed",
          error: "No launch file found in the package (no manifest href / index).",
        }, { merge: true });
        logger.warn(`material ${materialId}: no entry point`);
        return;
      }

      await docRef.set({
        status: "ready",
        entry_point: entryPoint,
        file_count: relPaths.length,
        ...(title ? { manifest_title: title } : {}),
      }, { merge: true });
      logger.info(`material ${materialId}: ready (entry=${entryPoint}, ${relPaths.length} files)`);
    } catch (err) {
      logger.error(`material ${materialId}: unzip failed`, err);
      await docRef.set({
        status: "failed",
        error: String(err && err.message ? err.message : err),
      }, { merge: true });
    }
  },
);

// --- 2. serve extracted files --------------------------------------------

exports.serveScorm = onRequest(
  { region: REGION, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
    // Path arrives as `/scorm/{id}/{file...}` (via the Hosting rewrite) or
    // `/{id}/{file...}` (direct function URL). Normalize both.
    const parts = req.path.replace(/^\/+/, "").split("/");
    if (parts[0] === "scorm") parts.shift();
    const materialId = parts.shift();
    const filePath = parts.join("/");
    if (!materialId || !filePath) {
      res.status(404).send("Not found");
      return;
    }

    // Block path traversal.
    if (filePath.includes("..")) {
      res.status(400).send("Bad request");
      return;
    }

    try {
      const bucket = getStorage().bucket();
      const file = bucket.file(`materials/${materialId}/extracted/${filePath}`);
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).send("Not found");
        return;
      }
      res.set("Content-Type", contentTypeFor(filePath));
      res.set("Cache-Control", "public, max-age=3600");
      file.createReadStream()
        .on("error", (err) => {
          logger.error(`serveScorm read error: ${filePath}`, err);
          if (!res.headersSent) res.status(500).end();
        })
        .pipe(res);
    } catch (err) {
      logger.error("serveScorm failed", err);
      res.status(500).send("Server error");
    }
  },
);
