# Training Materials / SCORM — Status & Next Steps (Handoff)

A running snapshot so work can resume on any machine. Design lives in
[training_materials_brainstorm.md](training_materials_brainstorm.md); the player
implementation in [scorm_player.md](scorm_player.md). This file is the **"where
are we right now"** doc.

_Last updated: 2026-07 (session that built + deployed the SCORM pipeline)._

---

## TL;DR — where we are

- **Admin side: done.** Upload `.zip` → shared **Materials** library (search /
  year / type filters) → attach to a session by type (`physical | selfPaced |
  webinar`) → assign trainees. Enrollments pre-created at assignment.
- **Serving + web playback: DONE and DEPLOYED, verified working.** A trainee can
  open a self-paced course from **My learning** and it **plays in the browser**,
  on the live site.
- **Native playback (Android): VERIFIED WORKING** on a physical device
  (2026-07-04). Tested via a connected Samsung SM S938B (Android 16) with
  `flutter run`. iOS shares the same `flutter_inappwebview` path but hasn't been
  run yet.
- **Windows playback: DEFERRED (blocked).** Two WebView2 plugins
  (`flutter_inappwebview_windows` + `webview_windows`) collide over the
  one-per-thread DispatcherQueueController; Windows now shows a graceful
  "open on web/mobile" placeholder. Full investigation + how to enable later:
  [windows_scorm_playback.md](windows_scorm_playback.md).

---

## Setting up on a new machine

The code is in the repo; **all data (admin/trainee accounts, sessions, uploaded
materials, enrollments) lives in the shared Firebase project** — nothing to
recreate, just sign in.

```bash
flutter pub get          # fetch deps added this session (firebase_storage,
                         # file_picker, flutter_inappwebview, web)
firebase login           # Firebase CLI auth is per-machine — log in as
                         # ephedrine2010x@gmail.com (the project owner)
flutter analyze          # sanity check — expect "No issues found"
```
For running the app: `flutter run -d chrome` (dev) — but **SCORM playback only
works on the deployed site** (see note below), so to test playback use
`https://academyplatform-12c05.web.app`. To redeploy functions you'll also need
`cd functions && npm install` once.

---

## What is live in Firebase (project `academyplatform-12c05`)

- **Cloud Functions (region `us-east1`)** — deployed & working:
  - `processMaterialUpload` — Storage trigger: unzips the uploaded zip →
    `materials/{id}/extracted/…`, parses the manifest, sets the material doc
    `status: ready` + `entry_point`.
  - `serveScorm` — HTTP: streams extracted files.
- **Hosting** — deployed at **https://academyplatform-12c05.web.app**, with the
  rewrite `/scorm/** → serveScorm` (this is what makes SCORM same-origin so the
  player works).
- **Storage rules** — "Option A" (any signed-in user can read/write `materials/`).
- Firebase CLI is logged in as **ephedrine2010x@gmail.com** (the project owner).

### Redeploy commands (from repo root)
```bash
# functions (after editing functions/index.js)
cd functions && npm install && cd ..
firebase deploy --only functions

# web app (after editing Dart / to publish playback)
flutter build web
firebase deploy --only hosting
```

> **Playback only works on deployed Hosting**, never a local `flutter run` — locally
> `/scorm/...` has no rewrite, so the iframe reloads the app and the session
> breaks (looks like a **signout**). Always test playback on the `.web.app` URL.

---

## Native playback — DONE (Android verified 2026-07-04)

### Goal (met on Android)
Self-paced SCORM courses play inside the app on **Android / iOS / Windows**, not
just the browser. Android is verified on a physical device; iOS/Windows share the
same code path but haven't been run yet.

### Approach (see `lib/enrollments/scorm/`)
- **Web** → `<iframe>` + `window.API` on the parent page (`scorm_player_web.dart`).
- **Native** → loads the cloud serving URL and injects `window.API` at
  document-start (`scorm_player_io.dart`). No same-origin constraint on native.
  The WebView backend is chosen at runtime:
  - **Android / iOS / macOS** → `flutter_inappwebview` (`InAppWebView`).
  - **Windows** → **deferred/blocked**. A `webview_windows` (WebView2) host is
    written and ready (`scorm_player_windows.dart`) but can't initialize while
    `flutter_inappwebview_windows` is in the build (DispatcherQueue conflict), so
    Windows currently shows a placeholder. Details + fix path:
    [windows_scorm_playback.md](windows_scorm_playback.md).
- All backends share `scorm_api_js.dart` (the injected `window.API`) and
  `scorm_session.dart` (CMI→progress) — only the WebView shell differs.
- The SCORM API JS (`scorm_api_js.dart`) and the CMI→progress interpreter
  (`scorm_session.dart`) are **shared** across web and native.
- Native serving URL is built from `kScormHostingOrigin` in `scorm_config.dart`
  (currently `https://academyplatform-12c05.web.app`) — already correct.

### Fixes made to get Android working (2026-07-04)
- Added `<uses-permission android:name="android.permission.INTERNET"/>` to
  `android/app/src/main/AndroidManifest.xml` (auto-injected in debug, but
  **required for release APKs** — otherwise the WebView is blank in release).
- In `scorm_player_io.dart`: removed `transparentBackground: true` (blank-WebView
  risk on some Android devices), added
  `mixedContentMode: MIXED_CONTENT_ALWAYS_ALLOW`, and added diagnostic handlers
  (`onLoadStart/Stop`, `onReceivedError`, `onReceivedHttpError`,
  `onConsoleMessage`) that log with a `[SCORM]` tag — keep these; they're how we
  debug silent native failures.

### To test on a device
1. Physical phone: Developer Options → USB debugging → plug in USB → accept prompt.
   (`flutter devices` should list it.) Emulator alternative: Android Studio →
   Device Manager → Create Device → download a system image → launch.
2. `flutter run -d <device-id>`, then sign in as **trainee** → **Courses → My
   learning** → open the course. Manifest changes need a **full restart**, not
   hot reload.

### If native playback misbehaves — the upgrade in reserve
We found **[scorm-again](https://github.com/jcputney/scorm-again)** (a robust
SCORM 1.2/2004 JS runtime, built for mobile/webviews). If a real package breaks
our minimal `window.API` (e.g. a SCORM 2004 course, strict error codes), swap the
API definition inside `scorm_api_js.dart` for a bundled `scorm-again`:
`window.API = new Scorm12API(...)`, seed resume with
`API.loadFromFlattenedJSON(initialCmi)`, and forward `API.on('LMSCommit'/'LMSFinish')`
to `__scormSend`. Because that JS is shared, it upgrades **web and native at once**.
It also has a **CrossFrame** mode that would remove the same-origin/Hosting-rewrite
requirement if ever needed.

---

## Other open items (not blocking native)

1. **Confirm progress/resume persistence** on web — open a course, make progress,
   close, reopen: the %/status should update and it should resume. If % stays 0,
   Firestore rules are likely blocking the trainee's `enrollments` write.
2. **Security hardening** (before real users):
   - Firestore rules: a trainee may write only *their own* enrollment, only the
     progress fields.
   - Storage/serving: currently open; tighten to a custom `admin` claim.
3. **Admin reporting** off `enrollments` (per-session / per-material / overdue) —
   designed (brainstorm §10) but not built.
4. **`serveScorm` is unauthenticated** — fine for an internal library; revisit if
   content becomes sensitive. Add a CDN before serving heavy video.

---

## Gotchas learned this session (so we don't repeat them)

- **Function region must match the Storage bucket's region.** Bucket is
  `us-east1`, so functions are `us-east1` (was `us-central1` → failed).
- **First functions deploy** needs IAM roles on Eventarc/Pub-Sub service agents;
  re-running the deploy as the project owner fixed it once identities propagated.
- **Upload writes the Firestore doc *first*, then the zip** (repo:
  `material_repository.uploadMaterial`) so the trigger can't be clobbered.
- **macOS "Compress"** adds `__MACOSX/` junk; the function now skips it, but prefer
  a clean zip (`imsmanifest.xml` at root, or one wrapping folder — both work).
- **Playback needs deployed Hosting** (same-origin), not local `flutter run`.
