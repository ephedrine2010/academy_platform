# Windows SCORM Playback — Blocked & Deferred (Investigation Log)

**Status: DEFERRED (2026-07-04).** Self-paced SCORM courses do **not** play on the
Windows desktop build. Web ✅, Android ✅ (verified), iOS ⚠️ (same code path,
unrun). On Windows the app now shows a graceful "open on web/mobile" placeholder
instead of a player.

This file is the full record of *why* Windows is blocked and *exactly* how to
turn it on later. Design/overview lives in
[status_and_next_steps.md](status_and_next_steps.md); this is the Windows-specific
deep dive.

---

## TL;DR

- Windows can't use `flutter_inappwebview` (our Android/iOS backend): its Windows
  implementation **hard-`abort()`s the whole process** mid-load on a real SCORM
  package.
- We wrote a `webview_windows` (WebView2) host as the Windows backend — it's the
  plugin the original SCORM POC proved on Windows. Code is done and kept in the
  repo: `lib/enrollments/scorm/scorm_player_windows.dart`.
- **But it can't initialize while `flutter_inappwebview_windows` is in the build.**
  Both plugins try to create the thread's **one-and-only** WebView2
  `DispatcherQueueController` at startup; `flutter_inappwebview_windows` registers
  first and wins, so `webview_windows` fails with
  `PlatformException(unsupported_platform, ...)`.
- Flutter has no one-line "exclude plugin X on platform Y" switch, and
  `flutter_inappwebview_windows` is pulled in **transitively and endorsed** by
  `flutter_inappwebview` (which we need for Android/iOS). Excluding it durably
  needs a `dependency_overrides` **stub package** — real build-system work.
- Windows is a **secondary target** (web is primary), so we deferred it rather
  than take on that risk now.

---

## Timeline of what we observed

1. **First Windows attempt (flutter_inappwebview path).** The page loaded — logs
   showed `onLoadStart`, `onProgressChanged {progress: 33}` → `66`, and the tab
   title changed to *"Interactive SWMS guidance tool"*. So **WebView2 runtime and
   the `serveScorm` serving pipeline are fine.** Then the process died mid-load:
   ```
   Lost connection to device.
   Exited.
   ```
   That is a native `abort()` **inside `flutter_inappwebview_windows`**, not a
   catchable Dart exception (no error surfaced to Dart; the whole app vanished).
   This is the known "young, crash-prone" state of that plugin's Windows backend.

2. **Second attempt (webview_windows path).** We added `scorm_player_windows.dart`
   (webview_windows / WebView2) and routed Windows to it. Init failed immediately:
   ```
   Creating DispatcherQueueController failed.
   [SCORM] WindowsScormPlayer init failed:
     PlatformException(unsupported_platform, The platform is not supported, null, null)
   ```
   WebView2 itself is present (it worked in attempt 1) — so `unsupported_platform`
   here is misleading. The real cause is the DispatcherQueueController conflict
   below.

---

## Root cause (verified in plugin source)

WebView2 visual hosting requires a **`DispatcherQueueController`**, and Windows
allows **only one per thread**. Both plugins create it with `DQTYPE_THREAD_CURRENT`
in their manager/platform constructor, log-and-bail on failure:

- **`webview_windows`** —
  `windows/webview_platform.cc` (`WebviewPlatform` ctor):
  ```cpp
  if (FAILED(rohelper_->CreateDispatcherQueueController(options, ...))) {
    std::cerr << "Creating DispatcherQueueController failed." << std::endl;
    return;                      // -> valid_ stays false -> unsupported_platform
  }
  ```
- **`flutter_inappwebview_windows`** —
  `windows/in_app_webview/in_app_webview_manager.cpp` (`InAppWebViewManager` ctor):
  **identical copy-pasted code.** This manager is constructed inside
  `FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar` — i.e. **at app
  startup**, unconditionally.

Registration order is set by the generated
`windows/flutter/generated_plugin_registrant.cc`, which lists plugins
alphabetically:

```
... flutter_inappwebview_windows ... webview_windows   // inappwebview is earlier
```

So the sequence on every Windows launch is:

1. `flutter_inappwebview_windows` registers → **grabs** the thread's
   DispatcherQueueController (even though we never open an InAppWebView on Windows).
2. Later, `webview_windows.initialize()` runs (when a course opens) → tries to
   create a second one on the same thread → **fails** → `unsupported_platform`.

Neither plugin crashes on the *loser* path (each just `return`s and goes inert);
the process death in attempt 1 was a separate abort deeper in the inappwebview
WebView2 code. The DispatcherQueue conflict is what specifically blocks
`webview_windows`.

They are, in short, **incompatible siblings**: any app that ships both
`flutter_inappwebview_windows` and `webview_windows` on Windows can only ever use
whichever registers first.

---

## Why we can't just "remove the other plugin"

- `flutter_inappwebview_windows` is **not** a direct dependency. It's the endorsed
  Windows federated implementation of `flutter_inappwebview`, which we depend on
  directly for **Android/iOS** playback. Depending on `flutter_inappwebview`
  auto-includes its Windows impl.
- Flutter provides **no** app-level "exclude plugin on this platform" knob.
- The generated `generated_plugins.cmake` / `generated_plugin_registrant.cc`
  regenerate on every `flutter pub get` / build, so hand-editing them is not
  durable.

---

## The current (deferred) behavior in code

- `lib/enrollments/scorm/scorm_player.dart` — unchanged conditional export
  (web → `scorm_player_web.dart`; native `dart.library.io` → `scorm_player_io.dart`).
  There is no `dart.library.windows`, so Windows can't be split at the export
  level; it's branched at runtime instead.
- `lib/enrollments/scorm/scorm_player_io.dart` — `ScormPlayer.build()` branches:
  - `defaultTargetPlatform == TargetPlatform.windows` → **`_WindowsUnsupported`**
    placeholder ("Course playback isn't available on Windows desktop yet — open
    in the web app or on your phone"). It does **not** touch any WebView2 plugin,
    so there's no crash and no half-initialized state.
  - otherwise → `_InAppWebViewScormPlayer` (Android/iOS/macOS).
- `lib/enrollments/scorm/scorm_player_windows.dart` — the `webview_windows` host,
  **kept and complete but not routed to.** It reuses the shared
  `buildScormBootstrapJs` (injected `window.API`) and `ScormSession` (CMI→progress),
  injects at document-start via `addScriptToExecuteOnDocumentCreated`, and receives
  SCO callbacks on the `webMessage` stream (`window.chrome.webview.postMessage`).
  It is ready to use the moment the plugin conflict is resolved.

---

## How to enable Windows later (the fix, in order of preference)

### Option A — Exclude `flutter_inappwebview_windows` via a stub override (durable)
Author a minimal local package **named `flutter_inappwebview_windows`** that
declares Windows support but whose native plugin class does nothing (no
DispatcherQueue). Point the app at it:

```yaml
# pubspec.yaml
dependency_overrides:
  flutter_inappwebview_windows:
    path: packages/flutter_inappwebview_windows_stub   # folder; package name must
                                                        # be flutter_inappwebview_windows
```

Requirements for the stub to link:
- Package name in its `pubspec.yaml` must be `flutter_inappwebview_windows`.
- It must declare a Windows plugin whose generated C-API registrant symbol matches
  what `generated_plugin_registrant.cc` expects:
  `FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(...)` from
  `<flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h>` —
  make it a no-op.
- Provide a trivial Dart entrypoint (no platform-interface registration needed;
  we never use InAppWebView on Windows).

`dependency_overrides` with `path:` bypasses version constraints, so
`flutter_inappwebview`'s Android/iOS impls are untouched. After adding it:
1. In `scorm_player_io.dart`, change the Windows branch from `_WindowsUnsupported`
   back to `WindowsScormPlayer(contentUrl:…, initialCmi:…, onProgress:…)`
   (re-import `scorm_player_windows.dart`).
2. `flutter clean && flutter pub get`.
3. `flutter run -d windows`, open a self-paced course, watch for `[SCORM]` logs.
   Expect it to play and to write progress/resume to `enrollments` like Android/web.

### Option B — Drop `webview_windows`, wait for an upstream `flutter_inappwebview` fix
Simplest code (one plugin everywhere) but Windows stays broken until the
inappwebview Windows abort is fixed upstream. Not recommended while it hard-crashes.

### Option C — Consider `scorm-again` + CrossFrame (tracked in status doc)
Independent of the plugin conflict, but its **CrossFrame** mode removes the
same-origin/Hosting-rewrite requirement and is a more robust SCORM runtime. Doesn't
fix the DispatcherQueue conflict by itself, but worth pairing with Option A if we
ever invest in Windows seriously.

---

## Facts worth keeping (so we don't relearn them)

- **WebView2 runtime is present** on the test machine and **`serveScorm` serves
  fine** — proven by the page loading to 66% with the correct title in attempt 1.
  Windows being broken is **not** a runtime or serving problem.
- `PlatformException(unsupported_platform)` from `webview_windows` is **misleading**
  — it does not mean the OS/WebView2 is unsupported; it means its
  `DispatcherQueueController` creation failed (here: already taken).
- Only **one** WebView2 `DispatcherQueueController` per thread. Two WebView2
  plugins in one app = the second one loses at startup.
- `flutter_inappwebview_windows` grabs it **at plugin registration**, not lazily —
  so merely having `flutter_inappwebview` in the dep tree is enough to block
  `webview_windows`, even if no InAppWebView is ever created on Windows.
