# SCORM Player POC — Implementation Notes

> Status: **working** — proven on Windows desktop with the ADL Golf SCORM 1.2 package.
> See [academyBrainstorm.md](academyBrainstorm.md) for the product vision and the
> production architecture this POC is a step toward.

## 1. What this POC proves

The single hardest unknown of the whole product — *can we play a SCORM package
inside Flutter and reliably detect when the learner finishes?* — is answered:
**yes**. The app:

1. Lists available courses in a side panel (one course: "Golf Explained").
2. Plays the SCORM package in an embedded WebView.
3. Detects completion (`cmi.core.lesson_status` → `completed`/`passed`) and shows
   **"The user has finished this course ✓"** in a status label, with a green check
   in the sidebar.

State is **in-memory only** (resets on restart) — persistence is a later layer.

## 2. Platform & runtime requirements

- **Target:** Windows desktop.
- **WebView:** [`webview_windows`](https://pub.dev/packages/webview_windows) (wraps
  Microsoft **WebView2** / Edge Chromium).
- **Runtime dependency:** the **WebView2 Runtime** must be installed (ships with
  current Edge, so usually already present on Win10/11). If the player shows an
  init error instead of content, this is almost always the cause.
- **State management:** `flutter_bloc` (Cubit).

## 3. How it works (the data flow)

```
User clicks course (sidebar)
  -> CoursesCubit.selectCourse(id)  -> status = inProgress, opens ScormPlayer
       |
ScormPlayer._init():
  1. ScormAssetServer starts a loopback HTTP server (127.0.0.1:<random port>)
     serving the package straight from the Flutter asset bundle.
  2. WebviewController initialized.
  3. SCORM 1.2 adapter JS injected via addScriptToExecuteOnDocumentCreated
     (runs BEFORE any page script).
  4. controller.webMessage stream is listened to.
  5. loadUrl(http://127.0.0.1:<port>/shared/launchpage.html)
       |
SCORM package runs in WebView:
  - Its ADL discovery algorithm finds window.API (our injected adapter).
  - On each LMSSetValue/Initialize/Commit/Finish, the adapter posts a JSON
    message via window.chrome.webview.postMessage(...).
       |
ScormPlayer._onWebMessage(message):
  - Forwards cmi.* SetValue calls to CoursesCubit.onScormSetValue(key, value).
       |
CoursesCubit.onScormSetValue("cmi.core.lesson_status", "completed"):
  - status = completed -> UI shows the completion label + green check.
```

## 4. Why a local HTTP server (not `file://`)

SCORM content uses **relative URLs** and an inner `<iframe>`
(`launchpage.html` loads `../Playing/Playing.html`, etc.). Loading via `file://`
breaks relative resolution and cross-frame behavior. Serving over
`http://127.0.0.1` makes the package behave exactly as it would inside a real LMS.
The server reads files on demand from `rootBundle`, so it works in a release build
without unpacking anything to disk.

## 5. The critical gotcha: `var API = null` clobbering the adapter

**Symptom seen during bring-up:** `[SERVER] 404 undefined (asset not found:
assets/golf/undefined)` and **no** `Initialize` message in the log.

**Cause:** `assets/golf/shared/scormfunctions.js` line ~96 runs `var API = null;`
at global scope. In a real LMS the SCORM API lives in a **parent** window, so that
line only nulls the *content frame's* copy and the discovery algorithm walks up to
the parent to find the real API. But this POC injects the adapter into the **same
frame** as `launchpage.html`, so `var API = null;` overwrote our adapter with
`null`. Since it is the top frame (`window.parent === window`), discovery could not
walk up, gave up, and SCORM init silently failed → `LMSGetValue` returned
`undefined` → the nav code built an iframe `src` of `../undefined` → the 404.

**Fix:** define `window.API` as **non-writable** with `Object.defineProperty`.
`scormfunctions.js` is non-strict, so its `API = null;` assignment silently
no-ops and our adapter survives. The adapter also posts an `AdapterReady` message
right after injection so the console confirms injection actually applied.

> Production note: the robust, standard alternative is to host the SCORM content in
> an `<iframe>` and put the API on the **parent** page (which is how real LMSs and
> `scorm-again` work). The non-writable trick is a deliberate POC shortcut.

## 6. File map

| File | Responsibility |
|------|----------------|
| [lib/main.dart](../lib/main.dart) | App root; provides `CoursesCubit`. |
| [lib/models/course.dart](../lib/models/course.dart) | `Course` + `CourseStatus` (notStarted / inProgress / completed / failed). |
| [lib/cubit/courses_cubit.dart](../lib/cubit/courses_cubit.dart) | Course list, selection, and SCORM `lesson_status` → status mapping. |
| [lib/cubit/courses_state.dart](../lib/cubit/courses_state.dart) | Equatable state (courses, selectedCourseId, status message). |
| [lib/data/scorm_asset_server.dart](../lib/data/scorm_asset_server.dart) | Loopback HTTP server serving the package from `rootBundle`. |
| [lib/scorm/scorm_adapter.dart](../lib/scorm/scorm_adapter.dart) | The injected minimal **SCORM 1.2 `window.API`** JS. |
| [lib/ui/scorm_player.dart](../lib/ui/scorm_player.dart) | WebView2 host: serve → init → inject → listen → load. |
| [lib/ui/home_page.dart](../lib/ui/home_page.dart) | Wide/landscape UI: sidebar list + content/player + status bar. |
| [lib/utils/log.dart](../lib/utils/log.dart) | Tagged console logging helpers. |

## 7. SCORM API the adapter implements (SCORM 1.2)

`LMSInitialize`, `LMSFinish`, `LMSGetValue`, `LMSSetValue`, `LMSCommit`,
`LMSGetLastError`, `LMSGetErrorString`, `LMSGetDiagnostic`. Data is held in an
in-memory CMI map. Only `cmi.core.lesson_status` is acted upon by the cubit; all
calls are logged.

## 8. Console logging

Tagged lines stream to the `flutter run` console:

- `[CUBIT]` — `selectCourse(...)`, `lesson_status = "..."`.
- `[SCORM]` — player lifecycle, WebView loading state, and every JS→Flutter
  message (`AdapterReady`, `Initialize`, `SetValue`, `Commit`, `Finish`).
- `[SERVER]` — listening port, `200 <path> (bytes)` per file, `404 <path>` for
  missing assets.
- `[ERROR]` — init/load/message failures with stack traces.

A healthy run shows `AdapterReady` → `Initialize` → `200` page loads → on finish a
`SetValue` with `cmi.core.lesson_status = completed` and a matching `[CUBIT]` line.

## 9. How to run

```
flutter pub get
flutter run -d windows
```

Then: pick **Golf Explained** → click **Next** through to the last page → the
status label flips to the completion message.

## 10. Known limitations (POC scope)

- In-memory only — no persistence of completion.
- No authentication.
- No admin upload — the single course is hard-coded in `CoursesCubit`.
- SCORM **1.2 only**, and only `lesson_status` is interpreted (score, time,
  bookmark/resume are captured but not used).
- `alert()`/`confirm()` dialogs from SCORM content are not surfaced by WebView2.

See [academyBrainstorm.md §6](academyBrainstorm.md) for the POC → production
upgrade path.
