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
- **Native playback (Android/iOS/Windows): code written, NOT yet tested.**
  Blocked only by a local Android emulator that won't boot. This is the one
  remaining task.

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

## The remaining task: native playback

### Goal
Make self-paced SCORM courses play inside the app on **Android / iOS / Windows**,
not just the browser.

### Approach (already coded — see `lib/enrollments/scorm/`)
- **Web** → `<iframe>` + `window.API` on the parent page (`scorm_player_web.dart`).
- **Native** → `flutter_inappwebview` loads the cloud serving URL and injects
  `window.API` at document-start (`scorm_player_io.dart`). One code path covers
  Android/iOS/Windows/macOS. No same-origin constraint on native.
- The SCORM API JS (`scorm_api_js.dart`) and the CMI→progress interpreter
  (`scorm_session.dart`) are **shared** across web and native.
- Native serving URL is built from `kScormHostingOrigin` in `scorm_config.dart`
  (currently `https://academyplatform-12c05.web.app`) — already correct.

### Current blocker
The Android **emulator won't start** on the current Windows machine
(`flutter emulators --launch academy_test` → "exited with code 1"). This is an
environment issue, **not a code issue** — `minSdk 23` is fine and the app is wired.

### How to unblock + test (do this to resume)
1. Get a working Android target. Easiest options, in order:
   - **Physical Android phone**: Developer Options → USB debugging → plug in USB →
     accept the prompt.
   - **Android Studio emulator**: open **Device Manager → Create Device**, pick a
     phone, **download a system image** (e.g. API 34), launch it. (The CLI-created
     AVD likely had no system image — the GUI handles the download. Also ensure
     Windows Hypervisor Platform / Hyper-V + BIOS virtualization are enabled.)
2. Confirm it appears:
   ```bash
   flutter devices     # should list an Android device/emulator
   ```
3. Run the app on it:
   ```bash
   flutter run -d <device-id>
   ```
4. In the app: sign in as the **trainee** → **Courses → My learning** → open the
   course. Watch whether it **plays**, is **blank**, or **errors**. Capture any
   red errors from the run console — that's what to debug from.

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
