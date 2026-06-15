# Academy Platform — Brainstorm & Technical Notes

> Status: exploration / proof-of-concept stage
> Last updated: 2026-06-15

## 1. Goal

Build a corporate **learning platform** where employees of a specific company
consume training materials authored as **SCORM** packages. The app is built with
**Flutter**.

### Core requirements

| # | Requirement | Notes |
|---|-------------|-------|
| 1 | Normal users **sign in** (no self-registration) | Microsoft account, restricted to one company |
| 2 | **Admin** creates a course (name) and uploads the SCORM material | Admin-only |
| 3 | Users **play** the material | SCORM packages are mini web apps (HTML/JS/CSS) |
| 4 | App **tracks progress** — did the user finish the material or not | Per user, per course |
| 5 | Possible **website version** | Same product on the web |

## 2. Is it applicable? — Yes

Every piece is achievable. The only part needing careful architecture is **SCORM
playback**, because SCORM is a web technology and Flutter has no native way to
"play" it.

| Piece | Feasibility | Approach |
|-------|-------------|----------|
| Microsoft sign-in (company only) | Easy | Azure Entra ID (Azure AD), **single-tenant** so only that company's directory can log in. Packages: `aad_oauth`, `msal_auth`, or `flutter_appauth`. No passwords managed by us. |
| SCORM playback | Feasible (the hard part) | Render the package in a **WebView** and inject a JavaScript **SCORM API adapter** that the content discovers and reports progress to. |
| Progress tracking | Easy (once playback works) | SCORM itself emits completion/score; we just store it. |
| Admin upload | Easy | Backend unzips the package, reads `imsmanifest.xml` to find the launch file, stores files. |
| Website version | Available, with a caveat | Flutter Web can't host SCORM the same way; use an `<iframe>` + cross-frame bridge, or run the SCORM player as plain JS outside Flutter. |

## 3. How SCORM actually works (the key concept)

A SCORM package is **not a video** — it is a small website. When it runs it looks
for a JavaScript **"API adapter"** in the browser window hierarchy and reports
progress to it.

- **SCORM 1.2** → looks for `window.API` with methods `LMSInitialize`,
  `LMSGetValue`, `LMSSetValue`, `LMSCommit`, `LMSFinish`, `LMSGetLastError`, …
- **SCORM 2004** → looks for `window.API_1484_11` with `Initialize`, `GetValue`,
  `SetValue`, `Commit`, `Terminate`, …

The content walks up `window.parent` (the ADL "API discovery algorithm") until it
finds that object. **Our job is to provide that object** and listen to what the
content writes into it.

Key data elements:
- `cmi.core.lesson_status` (1.2) / `cmi.completion_status` + `cmi.success_status`
  (2004) → `completed` / `incomplete` / `passed` / `failed`.
- `cmi.core.score.raw` → score.
- `cmi.core.lesson_location` / `cmi.suspend_data` → bookmark / resume state.
- `cmi.core.session_time` → time spent.

## 4. GitHub research (existing work)

Searched GitHub for prior art. Conclusions:

- **There is no popular, ready-made Flutter SCORM player.** All Flutter-specific
  repos are POC-grade (0–6 stars).
- **The winning pattern is a WebView + a proven JS runtime, bridged to the host
  app.**

Most relevant repos:

| Repo | Stars | Relevance |
|------|-------|-----------|
| [jcputney/scorm-again](https://github.com/jcputney/scorm-again) | ~317 | Modern, maintained JS SCORM runtime (1.2/2004). The production-grade API adapter. Has `lmsCommitUrl` (auto-POST progress to your backend), offline support, and cross-frame mode for iframes. |
| [willyelns/scorm_mobile_player_poc](https://github.com/willyelns/scorm_mobile_player_poc) | 0 | POC of SCORM in native iOS/Android/Flutter. Confirms: no SDK exists, use WebViews; recommends `flutter_inappwebview`; warns SCORM packages often lack a viewport meta-tag so content renders tiny on mobile — inject one. |
| [shripal17/dart_scorm](https://github.com/shripal17/dart_scorm) | 6 | Integrate SCORM APIs in a Flutter/Dart web app. |
| [mlgarrido/node-scorm-player](https://github.com/mlgarrido/node-scorm-player) | 18 | Full web player + backend API; good reference for upload + serve + track flow. |
| [jcputney/elearning-module-parser](https://github.com/jcputney/elearning-module-parser) | — | Java lib to parse `imsmanifest.xml` (for the admin upload step). |
| [OpenOLAT/OpenOLAT](https://github.com/OpenOLAT/OpenOLAT) | ~425 | Full open-source LMS — reference for completion/tracking data model. |

**Alternative to building the engine:** SCORM Cloud (Rustici) hosts & plays SCORM
and returns completion via API. Costs money but removes the hardest part.

## 5. Recommended production architecture

```
ADMIN UPLOAD
  Admin uploads course.zip
    -> backend unzips, parses imsmanifest.xml (find launch .html)
    -> stores files in cloud storage, course row in DB

MOBILE (Flutter)
  flutter_inappwebview (WebView mode)
    -> loads launch.html + injects scorm-again as window.API / API_1484_11
    -> inject viewport meta-tag (fix mobile scaling)
    -> scorm-again configured with lmsCommitUrl = backend
    -> on commit, scorm-again POSTs {completionStatus, score, time} -> backend

WEB (Flutter Web or plain JS)
  SCORM content in an <iframe>
    -> scorm-again CrossFrameAPI in iframe + CrossFrameLMS in parent
    -> same lmsCommitUrl -> backend

AUTH
  Azure Entra ID, single-tenant (company-only sign-in)

BACKEND / DB
  users . courses . progress(user_id, course_id, status, score, time, updated_at)
```

Suggested stack: Flutter + `flutter_inappwebview` + `scorm-again`, Azure Entra ID
single-tenant, backend on Supabase or Firebase.

## 6. Current proof-of-concept (this repo)

Scope: prove SCORM playback + completion tracking with a real package, minimal UI.

- **Example content:** ADL "Golf Examples" under `assets/golf/` — a **SCORM 1.2,
  single SCO** package. Launch file: `assets/golf/shared/launchpage.html`. It marks
  itself `completed` (via `cmi.core.lesson_status`) when the learner reaches the
  last page (see `shared/launchpage.html` and `shared/scormfunctions.js`).
- **Platform:** Windows desktop.
- **WebView:** `webview_windows` (WebView2). Requires the Microsoft **WebView2
  Runtime** (usually pre-installed on Win10/11 with Edge).
- **Serving:** a tiny in-app `HttpServer` (loopback) serves the golf files from the
  Flutter asset bundle, so relative paths and the inner `<iframe>` work (a plain
  `file://` load would break them).
- **SCORM adapter:** a hand-written **minimal SCORM 1.2 `window.API`** injected
  before the page loads. On `LMSSetValue("cmi.core.lesson_status", …)` it posts the
  value to Flutter via the WebView2 message channel.
- **State:** **Cubit** (`flutter_bloc`). One course in the side list. Selecting it
  opens the player; the completion message flips the course to *completed* and the
  UI shows **"The user has finished this course"** in a label. (In-memory only for
  the POC — no persistence yet.)
- **UI:** wide / landscape layout — a left **course list** + a right **content /
  player** area.

### POC -> production upgrade path
- Replace the hand-written adapter with **`scorm-again`** (full 1.2/2004, offline,
  cross-frame) and point its `lmsCommitUrl` at a real backend.
- Swap in-memory state for a backend + DB and persist progress per user.
- Add Azure Entra ID single-tenant sign-in.
- Add admin upload (unzip + manifest parse + storage).
- For the web build, use the `<iframe>` + cross-frame bridge approach.

## 7. Open questions / decisions to revisit
- Are courses authored in-house or supplied as vendor SCORM packages? (Decides
  whether full SCORM is worth it vs. simpler video + quiz.)
- SCORM 1.2 vs 2004 (and AICC?) — which versions must we support in production.
- Backend choice: Supabase vs Firebase vs custom.
- Build vs buy for the SCORM engine (self-host `scorm-again` vs SCORM Cloud).
