# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**Academy Platform** — a Flutter learning platform for delivering **SCORM**
training to a single company's employees. Currently at the **proof-of-concept**
stage: it plays a SCORM 1.2 package and tracks course completion.

- Product vision & production architecture: [documentation/academyBrainstorm.md](documentation/academyBrainstorm.md)
- How the working POC is built: [documentation/scormPocImplementation.md](documentation/scormPocImplementation.md)

**Read both docs before making non-trivial changes.**

## Current scope (POC)

- Platform: **Windows desktop** only so far.
- One hard-coded course ("Golf Explained", ADL sample under `assets/golf/`).
- Completion tracking is **in-memory** (resets on restart).
- No auth, no backend, no admin upload yet.

These are deliberate POC limits, not bugs. The intended next layers (persistence,
Microsoft/Entra sign-in, admin SCORM upload, `scorm-again` runtime) are listed in
the brainstorm doc — do not assume they exist.

## Commands

```bash
flutter pub get          # install deps
flutter analyze          # lint/type-check (keep this clean)
flutter run -d windows   # run the app
flutter build windows --debug   # verify native compilation
```

Run `flutter analyze` after changes; the project is expected to report
**"No issues found"**.

## Architecture

Flutter + **Cubit** (`flutter_bloc`). SCORM plays inside a **WebView2** surface
(`webview_windows`); a tiny loopback HTTP server feeds the package to the WebView,
and an injected JavaScript **SCORM API adapter** bridges SCORM calls back to Dart.

```
lib/
  main.dart                      # app root, provides CoursesCubit
  models/course.dart             # Course + CourseStatus
  cubit/courses_cubit.dart       # state + SCORM lesson_status -> status mapping
  cubit/courses_state.dart       # Equatable state
  data/scorm_asset_server.dart   # loopback HTTP server (serves from rootBundle)
  scorm/scorm_adapter.dart       # injected SCORM 1.2 window.API (JS string)
  ui/scorm_player.dart           # WebView2 host: serve -> init -> inject -> listen -> load
  ui/home_page.dart              # wide/landscape UI: sidebar + player + status bar
  utils/log.dart                 # tagged console logging
```

Data flow: user selects course → `CoursesCubit.selectCourse` → `ScormPlayer`
serves + loads the package → injected `window.API` posts SCORM events via
`window.chrome.webview.postMessage` → `ScormPlayer._onWebMessage` →
`CoursesCubit.onScormSetValue` → UI updates.

## Key gotchas (important)

- **`window.API` must be non-writable.** The Golf package's `scormfunctions.js`
  runs `var API = null;` at global scope; injecting into the same frame would
  clobber the adapter. `scorm/scorm_adapter.dart` defines `window.API` with
  `Object.defineProperty({ writable: false })` so the null assignment no-ops.
  Don't "simplify" this back to `window.API = {...}`. See
  [scormPocImplementation.md §5](documentation/scormPocImplementation.md).
- **Serve over HTTP, never `file://`.** SCORM uses relative URLs + an inner
  `<iframe>`; `file://` breaks them.
- **WebView2 Runtime required at runtime.** A player init error usually means it's
  missing.
- **`webview_windows` API names:** the incoming-message stream is `webMessage`
  (the plugin JSON-decodes the payload before emitting); the pre-load injection
  hook is `addScriptToExecuteOnDocumentCreated`.
- **Assets must be declared per-folder** in `pubspec.yaml` (`assets/golf/`,
  `assets/golf/Etiquette/`, …) — Flutter asset globbing is not recursive.

## Conventions

- Use the `log*` helpers in `lib/utils/log.dart` for console output (tagged
  `[SCORM]` / `[SERVER]` / `[CUBIT]` / `[ERROR]`), not bare `print`.
- State changes go through `CoursesCubit`; keep UI widgets stateless where
  practical and read state via `BlocBuilder`.
- Keep `flutter analyze` clean.
