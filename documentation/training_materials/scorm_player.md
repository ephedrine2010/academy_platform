# SCORM Player & Serving Pipeline

How an uploaded SCORM package gets **hosted, served, played, and tracked** across
web and native. This is the implementation companion to the design in
[training_materials_brainstorm.md](training_materials_brainstorm.md) (§5 hosting,
§8 viewer, §9 progress) — read that for the *why*; this doc is the *how*.

> **Status:** **Web verified working** — deployed to Firebase Hosting
> (`academyplatform-12c05.web.app`), a real package uploads → unzips → serves →
> plays end-to-end. Functions live in **us-east1** (`processMaterialUpload` +
> `serveScorm`). **Native (Android/iOS/Windows) is built but not yet
> runtime-tested** — needs a device/emulator and `kScormHostingOrigin` set.

---

## 1. The one insight that shapes everything

A SCORM package is HTML/JS that expects to run inside an LMS. The SCO (the
content) finds the LMS by walking the window chain for an `API` object:
`window.API` → `window.parent.API` → `window.opener.API` (SCORM 1.2).

That discovery is subject to the browser's **same-origin policy**. So the whole
architecture bends around one rule:

> **The `window.API` the SCO reaches must be same-origin with the SCO.**

- **Web:** the SCO runs in an `<iframe>` inside the Flutter page, so it looks for
  `window.parent.API`. The iframe content therefore **must be served from the
  same origin as the app** — achieved with a Firebase **Hosting rewrite**
  (`/scorm/** → serveScorm`). If we served it straight from
  `cloudfunctions.net`, the cross-origin `window.parent.API` access would be
  blocked and nothing would initialize.
- **Native:** there is no cross-origin parent hop. The webview loads the SCORM
  page as its top document and we inject `window.API` **into that same page**.
  So native has no same-origin constraint and can hit the serving URL directly.

Everything else (unzip, serve bytes, map SCORM calls to progress) is shared.

---

## 2. Component map

```
Upload (admin)                Serve + Play (trainee)
──────────────                ──────────────────────
materials/{id}/pkg.zip        functions/index.js
  │  (Storage finalize)         ├─ processMaterialUpload  (unzip + parse)
  ▼                             └─ serveScorm             (stream a file)
processMaterialUpload                    │
  ├─ unzip → materials/{id}/extracted/…  │ Hosting rewrite  /scorm/** → serveScorm
  ├─ parse imsmanifest.xml               ▼
  └─ material doc:                lib/enrollments/scorm/
       status: ready               ├─ scorm_player.dart        (conditional export)
       entry_point: index.html     ├─ scorm_player_web.dart    (<iframe>, js_interop)
                                    ├─ scorm_player_io.dart     (flutter_inappwebview)
                                    ├─ scorm_player_stub.dart   (unsupported fallback)
                                    ├─ scorm_api_js.dart        (window.API — shared JS)
                                    ├─ scorm_session.dart       (CMI → progress — shared)
                                    └─ scorm_config.dart        (serving URL builder)

lib/enrollments/ui/material_viewer_page.dart   hosts ScormPlayer, seeds resume
lib/enrollments/data/enrollment_repository.dart updateProgress() persists it
```

Relevant files:

| File | Role |
| --- | --- |
| [functions/index.js](../../functions/index.js) | `processMaterialUpload` + `serveScorm` |
| [firebase.json](../../firebase.json) | Hosting rewrite `/scorm/** → serveScorm`, functions/hosting/rules config |
| [storage.rules](../../storage.rules) | client access to `materials/…` (functions use Admin SDK, bypass rules) |
| [lib/enrollments/scorm/scorm_player.dart](../../lib/enrollments/scorm/scorm_player.dart) | conditional export picks the host |
| [lib/enrollments/scorm/scorm_player_web.dart](../../lib/enrollments/scorm/scorm_player_web.dart) | web `<iframe>` host |
| [lib/enrollments/scorm/scorm_player_io.dart](../../lib/enrollments/scorm/scorm_player_io.dart) | native webview host |
| [lib/enrollments/scorm/scorm_api_js.dart](../../lib/enrollments/scorm/scorm_api_js.dart) | shared SCORM 1.2 `window.API` JS |
| [lib/enrollments/scorm/scorm_session.dart](../../lib/enrollments/scorm/scorm_session.dart) | shared CMI → `ScormProgress` interpreter |
| [lib/enrollments/scorm/scorm_config.dart](../../lib/enrollments/scorm/scorm_config.dart) | `kScormHostingOrigin`, `scormContentUrl()` |
| [lib/enrollments/ui/material_viewer_page.dart](../../lib/enrollments/ui/material_viewer_page.dart) | viewer shell that hosts the player |

---

## 3. Serving pipeline (Cloud Functions)

Two 2nd-gen functions in [functions/index.js](../../functions/index.js), Node 20,
region **`us-east1`** — a storage-triggered function must run in the **same
region as the bucket** (`academyplatform-12c05.firebasestorage.app` is us-east1),
so `REGION` and the Hosting rewrite region both use it.

### `processMaterialUpload` (Storage trigger)

Fires on any finalized object. It only acts on the **original zip**
(`materials/{id}/*.zip`, and never on its own `extracted/` output, which would
retrigger).

1. Sets the `materials/{id}` doc `status: processing`.
2. Downloads + unzips the package (`adm-zip`, in memory; function memory 1 GiB).
3. Finds `imsmanifest.xml`; the folder that contains it is the **package root**
   (a common gotcha — some tools nest everything under one folder). Every file
   under that root is uploaded to `materials/{id}/extracted/{relative-path}`, so
   `extracted/` mirrors the package with the entry + assets resolving at root.
4. Parses the manifest for the **launch file** (`parseEntryPoint`: the resource
   referenced by the first organization item → else first resource `href`) and
   title, with a fallback scan for common names (`index_lms.html`, `index.html`,
   `story.html`, …).
5. Writes `status: ready` + `entry_point` (or `status: failed` + `error`).

### `serveScorm` (HTTP)

Streams one extracted file. Reached same-origin via the Hosting rewrite, so the
incoming path is `/scorm/{materialId}/{file…}` (it also tolerates the direct
function path). It reads `materials/{materialId}/extracted/{file}` from Storage,
sets the right `Content-Type` (inline map) + `Cache-Control`, and pipes it. Path
traversal (`..`) is blocked. Uses the Admin SDK, so Storage rules don't apply.

---

## 4. The player (Flutter)

[scorm_player.dart](../../lib/enrollments/scorm/scorm_player.dart) is a
conditional export — the compiler picks one implementation, all with the same
`ScormPlayer({contentUrl, initialCmi, onProgress})` API:

```dart
export 'scorm_player_stub.dart'
    if (dart.library.js_interop) 'scorm_player_web.dart'
    if (dart.library.io) 'scorm_player_io.dart';
```

> Conditional import can't tell Android from Windows (both are `dart.library.io`),
> so **all native platforms share `_io.dart`** via `flutter_inappwebview` — the
> one webview with document-start script injection, which SCORM needs. That's
> also why we don't use `webview_flutter` (no clean pre-content injection) or the
> `webview_windows` POC (Windows-only) here.

### Web host (`scorm_player_web.dart`)

- Exposes a Dart receiver on the window (`__scormDartSend`), then appends a
  `<script>` (built by `buildScormBootstrapJs`) that defines **`window.API` on
  the parent (Flutter) window**.
- Registers an `<iframe>` view factory (`dart:ui_web` + `package:web`) pointing
  at the same-origin `/scorm/{id}/{entry}` URL, rendered via `HtmlElementView`.
- The SCO in the iframe finds `window.parent.API`; its calls post JSON back to
  `__scormDartSend`.

### Native host (`scorm_player_io.dart`)

- `InAppWebView` loads the serving URL (absolute, against `kScormHostingOrigin`).
- A `UserScript` at `UserScriptInjectionTime.AT_DOCUMENT_START` injects the same
  bootstrap JS, so `window.API` exists **before** the SCO runs.
- The SCO's calls go to `flutter_inappwebview.callHandler('scorm', …)`, received
  by `addJavaScriptHandler`.

### Shared JS — `window.API` (`scorm_api_js.dart`)

`buildScormBootstrapJs({initialCmi, sendBody})` returns the JS both hosts inject.
Only `sendBody` differs (web: `window.__scormDartSend(p)`; native:
`flutter_inappwebview.callHandler('scorm', p)`).

It implements SCORM 1.2: `LMSInitialize/Finish/GetValue/SetValue/Commit/
GetLastError/…`, keeps the CMI map in JS (seeded from `initialCmi`), and posts a
JSON `{type, cmi, key?, value?}` to the host on init/set/commit/finish. `LMSGetValue`
returns from the seeded map so **resume** works.

> **Gotcha (same as CLAUDE.md):** `window.API` is defined with
> `Object.defineProperty(..., { writable: false })`. Some packages run
> `var API = null;` at global scope; without the non-writable guard that would
> clobber the adapter when the SCO shares the frame (the native case). Don't
> "simplify" it to `window.API = {…}`.

### Shared interpreter — CMI → progress (`scorm_session.dart`)

`ScormSession.ingest(rawPayload)` merges the CMI snapshot and maps it to a
`ScormProgress` (lifecycle + outcome + progress% + score + bookmark + suspend
data):

- `lesson_status` `passed`/`failed` → `done` + that outcome; `completed` →
  `done`; anything else → `inProgress`.
- progress%: `done` → 100; else `cmi.progress_measure`×100 (SCORM 2004) if
  present, else `score.raw`.

It returns a value **only when a write is worthwhile** — on the SCO's own
`commit`/`finish`, or when a tracked field actually changed — implementing the
§9 "don't write every `LMSSetValue`" strategy. Both hosts call `ingest`; a
non-null result is handed to `onProgress`.

---

## 5. Enrollment integration (progress + resume)

The viewer ([material_viewer_page.dart](../../lib/enrollments/ui/material_viewer_page.dart)):

1. On open, marks the enrollment started (`markStarted`).
2. Fetches the material (`MaterialRepository.getById`) for `entry_point` +
   `status`. If not `ready`, shows a processing/failed/unavailable state instead
   of a player.
3. Builds `initialCmi` from the enrollment — identity, prior `lesson_status`,
   and the saved `lesson_location` / `suspend_data` with
   `cmi.core.entry = resume`, so the SCO restores position.
4. Hosts `ScormPlayer`; on each `onProgress` it updates the top-bar % and calls
   `MyEnrollmentsCubit.saveProgress` →
   [`EnrollmentRepository.updateProgress`](../../lib/enrollments/data/enrollment_repository.dart),
   which writes `progress`, `lifecycle_state`, `outcome`, `score`,
   `lesson_location`, `suspend_data` (and `completed_at` when done).

The content URL is built by `scormContentUrl(materialId, entryPoint)`
([scorm_config.dart](../../lib/enrollments/scorm/scorm_config.dart)): a
same-origin relative path on web (`kIsWeb`), an absolute URL against
`kScormHostingOrigin` on native.

---

## 6. Deploy & configure

```bash
# 1. install function deps
cd functions && npm install && cd ..

# 2. deploy functions + rules (first run enables the required Google APIs)
firebase deploy --only functions,firestore:rules,storage

# 3. build + deploy the web app (this also activates the /scorm rewrite)
flutter build web
firebase deploy --only hosting
```

- Requires the **Blaze** plan (Cloud Functions).
- The trigger fires only on **new** uploads — materials uploaded before the
  functions existed won't process until re-uploaded.
- **Native:** set `kScormHostingOrigin` in
  [scorm_config.dart](../../lib/enrollments/scorm/scorm_config.dart) to your
  Hosting domain. Android needs `minSdkVersion ≥ 21`; Windows needs the WebView2
  runtime.

### Verify

Upload a `.zip` in the **Materials** tab → its pill goes **Processing… →
Ready** (the doc gains `entry_point`). Open it from a trainee's **My learning**;
progress/resume should round-trip through the `enrollments` doc. On **Failed**,
the material doc's `error` field and the function logs say why.

> SCORM only plays on **deployed Hosting** (or the Firebase emulator), never a
> bare `flutter run -d chrome` — there's no `/scorm` rewrite locally, so the
> iframe would be cross-origin.

---

## 7. Known limitations & next

- **Untested at runtime** — compiles only; validate on a real deploy/device.
- **SCORM 1.2 only** — SCORM 2004 (`window.API_1484_11`) is a straightforward
  addition to `scorm_api_js.dart` (partly anticipated in the interpreter).
- **No CDN** in front of `serveScorm` yet — fine for HTML/image packages at
  company scale; add one before video-heavy content (brainstorm §6).
- **Serving is open** — `serveScorm` doesn't check auth. Acceptable for an
  internal library; tighten if content becomes sensitive.
- **Firestore rules for `enrollments`** — trainees currently write progress under
  open/default rules. Lock to "own enrollment, progress fields only" (§9 trust
  model) before real users.
```
