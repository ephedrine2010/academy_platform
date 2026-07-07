# Training Materials — Brainstorm (WORK IN PROGRESS)

> **Status: unfinished brainstorm.** This captures an in-progress design
> conversation about how the Academy platform models, hosts, displays, and
> tracks the different kinds of learning material. Decisions marked ✅ are
> settled; ❓ are open questions to resume. Nothing here is built yet.
>
> Sibling docs: product vision [academyBrainstorm.md](../academyBrainstorm.md) ·
> courses [courses/courses_implementation.md](../courses/courses_implementation.md) ·
> trainee UI [ui_design/trainee_ui.md](../ui_design/trainee_ui.md) ·
> attendance [instructor/attendance_implementation.md](../instructor/attendance_implementation.md).

---

## 1. The four material types

For now there are ~4 kinds of learning material:

| Type | Description |
| --- | --- |
| **Physical** | In-person (e.g. at a hotel), with specific appointments. Attendance is marked (geofence flow already exists). |
| **Self-Paced** (on-website SCORM) | Online course watched anytime, **no appointment**. Trainee must finish watching the assigned material and pass the exam if there is one. |
| **Webinar** | Attend only. Has appointments (a time), usually **not mandatory**. Attendance captured after the fact. |
| **Onboarding Path** | For new users. An **ordered, sequential** set of SCORM/PDF items the trainee must finish and pass. |

> **Naming decision** ✅ — "on-website SCORM" is called **Self-Paced** internally
> and in the UI. It reads naturally next to *Physical · Webinar · Onboarding Path*.
> (Alternatives considered: On-Demand, eLearning.)

---

## 2. The underlying model — properties, not types

The four types are **not** four separate systems — they're combinations of a few
independent properties. Modelling the properties keeps the system flexible (a
5th type later won't need a rewrite).

**Axes every material varies on:**

| Axis | Question |
| --- | --- |
| Time-bound? | Does it have appointment(s) with date/time/place? |
| Completion signal | attendance mark / watched-to-end / exam passed |
| Content payload | SCORM · PDF · video · none |
| Mandatory? | Must complete, or optional? |
| Assessed? | Is there a pass/fail exam gate? |
| Grouped? | Standalone, or part of an ordered path? |

**The four types as points in that space:**

| Type | Time-bound | Completion signal | Payload | Mandatory | Assessed |
| --- | --- | --- | --- | --- | --- |
| Physical | ✅ appointment + place | instructor attendance (geofence) | usually none in-app | yes | sometimes |
| Self-Paced | ❌ (no time, no place) | finished watching (+ pass) | SCORM | yes | maybe |
| Webinar | ✅ time (maybe link) | attendance | maybe recording | usually **no** | no |
| Onboarding Path | ❌ | finish + pass all items | SCORM + PDFs | yes | yes |

### Two completion engines (key insight ✅)

Everything reduces to **two** engines:

1. **Attendance** — physical, webinar. "Done" = someone/something marked attended.
2. **Content-completion** — self-paced, path items. "Done" = SCORM says finished (+ exam passed).

The **Onboarding Path** is just a **container**: an ordered list of
content-completion items with a "must finish all, in sequence" rule.

### Proposed shape

```
Material
  ├─ deliveryType: physical | webinar | selfPaced | pathItem
  ├─ scheduling:   none | appointment(s)
  ├─ completion:   attendance | contentFinished | examPassed
  ├─ mandatory:    true | false
  └─ payload:      scorm | pdf | none
Path = ordered collection of pathItems + "complete all (sequential)" rule
```

The four named types are **presets** over these fields. Keep `session` as the
unit a trainee is assigned to; add a `deliveryType` discriminator that drives
scheduling, completion rule, and payload. This reuses the existing
assignment / home / attendance plumbing.

---

## 3. Decisions locked so far ✅

- **Naming:** on-website SCORM → **Self-Paced**.
- **Webinar attendance:** capture the **attendee emails from the webinar**
  (mostly Microsoft Teams) → match to `users` → mark attended. Start with
  **manual CSV upload** by the admin (Graph API auto-pull is a later upgrade).
  Since webinars are usually optional, "attended yes/no" may be all that's stored.
- **Onboarding path:** **sequential** — step 2 is locked until step 1 is passed.
- **Player layout:** **framed in-app** (see §7), with fullscreen as a one-tap
  option.
- **Material library is separate from sessions.** Admin uploads a material once
  (a `.zip`) → it lands in a shared **`materials`** library → **any** admin can
  attach **any** material to **any** session. A session *points at* a material;
  it never owns one. Never delete a material's files on session delete; block
  deleting a material still used by sessions.
- **Upload format:** a single **`.zip`** to Firebase Storage. (Server-side unzip +
  manifest parse is a later step — see §12; the admin enters title/type manually
  for now.)
- **Enrollment key:** one record per **(trainee × session)**, id `sessionId_userId`,
  **pre-created** at assignment (so "never started / overdue" can be reported).
  Status is split into `lifecycleState` (notStarted/inProgress/done) +
  `outcome` (passed/failed/attended/absent/null). See §9.
- **Onboarding paths deferred** — different progress shape; build the other three
  types (physical · self-paced · webinar) first.

---

## 4. Existing SCORM code to reuse (`lib/courses_old/`)

There's an already-built SCORM POC under
[lib/courses_old/](../../lib/courses_old/) that's more complete than the current
`lib/academy/` tab. Reusable pieces:

| File | What it does | Reuse on web? |
| --- | --- | --- |
| `academy/data/scorm_file_source.dart` | `ScormFileSource` abstraction: `DiskScormSource` (local) + `OneDriveScormSource` (Graph, on-demand) | ✅ logic reusable |
| `academy/data/manifest_parser.dart` | robust `imsmanifest.xml` → entry point + title (with fallbacks) | ✅ as-is |
| `academy/scorm/scorm_adapter.dart` | `window.API` injection (SCORM 1.2) | ✅ port `postMessage` bridge |
| `academy/data/scorm_asset_server.dart` | **local loopback HTTP server** streaming files one path at a time | ❌ desktop-only (`dart:io HttpServer`) |
| `academy/ui/scorm_player.dart` | `webview_windows` host | ❌ Windows-only |
| `academy/data/onedrive_graph_client.dart` | thin Graph client (`/shares/{shareId}/driveItem`), on-demand file reads | ✅ logic reusable (server-side) |
| `academy/data/onedrive_config.dart` | share-link config; requires courses stored **extracted**, not `.zip` | ref |

**Critical realization:** the old design works because a **local loopback HTTP
server** (`http://127.0.0.1`) fakes an HTTP root so SCORM's relative URLs + inner
iframe resolve — reading bytes from disk *or* OneDrive on demand. This is
**desktop-only**: `dart:io HttpServer` and `webview_windows` don't exist on web.
Also `OneDriveScormSource` uses the **signed-in user's Microsoft token**
(delegated), but the platform uses **Firebase email/password** (Microsoft/Entra
is dormant) — so browser learners have no Graph token anyway.

---

## 5. SCORM hosting & serving (web-first)

Judge every hosting option by one test: **can the browser load the entry HTML and
have all its relative links resolve?** (Same rule as CLAUDE.md: serve over HTTP,
never `file://`.)

### Recommendation ✅ (relocate the loopback idea to the cloud)

Keep `ScormFileSource` / `manifest_parser` / `scorm_adapter` logic; replace only
the **host**:

1. **Upload:** admin uploads the extracted folder or a `.zip` in-app →
   **Firebase Storage** (`scorm/{pkgId}/…`). A **Cloud Function** unzips it and
   runs `parseManifest` to record the entry point + title in Firestore.
2. **Serve:** a **Cloud Run / Function proxy** at `/scorm/{pkgId}/{**path}` — this
   is literally `ScormAssetServer._handleRequest` moved to the cloud (same
   content-type map, same "read one relative path" model). It preserves relative
   paths → the package behaves like it's in a real LMS.
   - ⚠️ Raw Storage `getDownloadURL` per file does **not** work — tokenized
     per-object URLs break relative links (the classic "SCORM on Firebase
     Storage" trap). The proxy is what avoids it.
3. **Display:** Flutter web renders `<iframe src="/scorm/{pkgId}/{entryPoint}">`
   with the SCORM `window.API` injected into the **parent** page → messages →
   Cubit → Firestore (mirrors the existing `onScormSetValue` flow; Windows
   `postMessage` becomes web `postMessage`).

> **Why not OneDrive as the serving root:** Graph gives per-file, tokenized
> download URLs, not a path-preserving web root — relative links won't resolve
> without rewriting them or proxying every request through Graph. OneDrive works
> fine as a *byte source behind a proxy* (as the old loopback server proved), but
> as a direct web root it's the wrong tool. It also drags Microsoft auth back in.

**Quickest ways to *see* a package today:**
- Throwaway: drop the extracted folder in `assets/courses/` (or point
  `DiskScormSource` at it) and run on **Windows** — the old player plays it now.
- Real path: build the Storage upload + cloud proxy + web player above.

**The real build item** is the **web SCORM player** (iframe + `window.API`
bridge → Cubit → Firestore). Hosting is easy once the proxy route exists.

---

## 6. Cost — Firebase at scale

For a **single company's bounded user base**, Firebase is cheap and predictable —
**tens of dollars/month**, *unless courses are video-heavy served without a CDN*.

### What you pay for (Firebase Storage = Google Cloud Storage)

| Line item | Price | Notes |
| --- | --- | --- |
| Storage | ~$0.026 / GB / mo | trivial — SCORM shells are small |
| **Egress (download)** | **~$0.12 / GB** | the dominant variable cost |
| Storage ops | ~$0.004 / 10k | negligible |
| Cloud Run/Functions (proxy) | 2M req/mo free, then $0.40/M | negligible at this scale |
| Firestore | $0.18 / 100k writes | negligible if writes are debounced |

Requires the **Blaze (pay-as-you-go)** plan for Cloud Functions, but Blaze keeps
the free tiers.

### Estimate — 5,000 employees

Assume 20 self-paced courses/yr, ~40 MB each (HTML+images+light audio), ~10
completed per employee, browser caching on:

- Egress: 5,000 × 10 × 40 MB ≈ **2 TB/yr → ~$240/yr (~$20/mo)**
- Storage: 20 × 40 MB = 800 MB → **~$0.02/mo**
- Firestore progress: ~500k writes/yr → **~$1/yr**
- Cloud Run: ~5M req/yr vs 24M/yr free → **$0**

**≈ $20–25/month at 5,000 users.**

### The budget-buster: video

Video-heavy courses (~500 MB each) → same 5,000 users ≈ **25 TB/yr → ~$3,000/yr**.
Mitigations, by impact:

1. **Put a CDN in front** (Cloud CDN / Cloudflare) — SCORM files are static and
   identical for everyone; first learner in a region pulls origin, rest hit cache.
   Cuts egress 80–95%. **Biggest lever.**
2. **Cache-Control headers** on the proxy — re-opened pages + shared runtime
   JS/CSS download once.
3. **Offload heavy video** out of the SCORM package to a streaming host.
4. **Same region** for proxy + bucket (Storage→Run free; only Run→learner billed).
5. **Debounce Firestore writes** — one per commit/section, not per `LMSSetValue`.

**Doc rule:** Firebase is safe/cheap for HTML/image SCORM at company scale.
Budget seriously only for **video**; always front content with a **CDN** and
offload big video to a streaming host.

---

## 7. Video hosting decision

The real question isn't "OneDrive vs Firebase" — it's **where big video lives**.

| Option | Egress cost | Complexity | Streaming quality |
| --- | --- | --- | --- |
| **All Firebase + CDN** (default ✅) | Low (CDN absorbs it) | Simplest — one auth, one pipeline | Good enough |
| Video on OneDrive | Very low (bundled in M365) | Two pipelines + Microsoft auth + must externalize video URLs from the package | Basic, no adaptive bitrate |
| Video on a real video host (Cloudflare Stream / Mux / unlisted Vimeo/YouTube) | Low–moderate | Medium but purpose-built | Best — adaptive, CDN, thumbnails |

**Catches with "video on OneDrive"** (the user's hybrid idea — valid but middle-row):
1. Breaks SCORM self-containment — each `<video src>` must be rewritten to an
   external URL (per-course authoring/build step).
2. Auth wrinkle — needs short-lived Graph pre-signed URLs (they support range/seek)
   minted by a function, or a proxy; browser can't hit OneDrive with a Firebase login.
3. OneDrive isn't a streaming platform — no adaptive bitrate, Graph throttling
   under load, awkward to CDN.

**Recommendation:**
- Modest video → **all-Firebase + CDN** (simplest; CDN already kills the egress cost).
- Serious video → a **purpose-built video host**, not OneDrive (same "externalize
  the URL" work, but you get adaptive streaming + real CDN).
- OneDrive-for-video only if "free M365 egress" is a hard requirement and basic,
  low-concurrency playback is acceptable.

---

## 8. Trainee viewing experience (aligned to the trainee design system)

Tokens from [lib/theme/app_theme.dart](../../lib/theme/app_theme.dart): teal
`#00444F` header, warm-paper canvas `#FBFAF7`, hairline cards, `StatusColors`
chips, Bricolage Grotesque / Manrope.

### The core idea: one "Material Viewer," swappable body

One viewer **shell** (same top bar, progress, completion celebration) with a
**type-specific body** dropped in the middle. Add a new material type later = add
one body; everything else is free.

```
Material Viewer (shell — identical for every type)
 ├─ SCORM  → <iframe> player            (self-paced, onboarding)
 ├─ PDF    → paged reader + "I've read this" ack
 └─ Video  → video player + resume position
```

### The journey — three moments

**1. Course card (Courses grid)** — cover image, category chip + duration,
title (Bricolage 17/w700), progress bar (teal on `track`), status chip
(`Not started` · `In progress` · `Completed` · `Passed ✓` via `StatusColors`).

**2. Pre-launch detail** — teal hero + cover, description / "what you'll learn",
exam info (e.g. pass ≥ 80%), your-progress bar, and a **smart button**
(**Start / Resume / Review** by state; Resume jumps to the SCORM bookmark).

**3. The viewer — framed in-app** ✅ (decision):

```
┌──────────────────────────────────────┐
│ ✕  Fire Safety   ▓▓▓▓░ 60%        ⛶  │ ← thin teal bar: close · title · progress · fullscreen
├──────────────────────────────────────┤
│        SCORM content (iframe)         │  responsive, capped to contentMaxWidth,
│           letterboxed                 │  centered on canvas (never distorted)
├──────────────────────────────────────┤
│  ◀ Prev            Next ▶ (path only) │ ← footer only for onboarding-path steps
└──────────────────────────────────────┘
```

- Content capped to existing `contentMaxWidth` buckets (phone full · tablet 680 ·
  desktop 860) so wide windows keep the mobile rhythm.
- **Fullscreen (⛶) is a one-tap escape hatch** — framed default *and* immersive
  when a course needs it.
- **Path footer** appears only for onboarding-path steps; hidden for standalone.

### Behaviors that make it feel nice

- **Resume where you left off** — restore SCORM bookmark (`cmi.core.lesson_location`)
  + `suspend_data` on open.
- **Live progress** — top bar fills as the package reports `lesson_status`/progress.
- **Graceful loading** — branded skeleton while the iframe streams, no white flash.
- **Fullscreen / responsive** — letterbox fixed-aspect SCORM; suggest landscape on phone.
- **Completion celebration** — checkmark + score + confetti, then a **single clear
  next action** ("Next step →" in a path, or "Back to courses").
- **Error honesty** — friendly retry, not a stack trace.

### Full picture

```
Courses grid ──tap──▶ Pre-launch detail ──Start/Resume──▶ Framed Viewer ──pass──▶ Celebration ──▶ next step
```

Same shell serves SCORM · PDF (with ack) · video — only the middle body swaps.

### Where each type lives (trainee)

| Type | Tab | Trainee sees / does |
| --- | --- | --- |
| Physical | **Schedule** | date, hotel, map; attendance marked *for* them |
| Webinar | **Schedule** | date + **Join** (Teams); "optional" badge if not mandatory |
| Self-Paced | **Courses/Home** | **Watch** → viewer; progress bar; Passed/Failed |
| Onboarding Path | **Home** (pinned for new users) | vertical stepper: Step 1 ✅ → 2 🔓 → 3 🔒 |

**Rule:** anything with a date → Schedule; anything self-driven → Courses/Home.

---

## 9. Progress recording in Firebase

The unit is **one record per (trainee × material)**, stored as a **top-level
`enrollments` collection** — the only shape that cheaply answers both
"my courses" (`where userId == me`) and "who's on course X?"
(`where materialId == X`). A user subcollection would make admin reporting painful.

```
enrollments/{enrollmentId}
  userId          "abc"
  materialId      "fire-101"
  pathId          "onboard-1"   # if part of a path, else null
  deliveryType    selfPaced | physical | webinar | pathItem

  status          notStarted | inProgress | completed | passed
                  | failed | attended | absent
  progress        0..100        # % for content types
  score           0..100        # exam score, null if none
  mandatory       true

  # SCORM resume state
  lessonStatus    "incomplete"  # cmi.core.lesson_status
  lessonLocation  "page7"       # cmi.core.lesson_location  (bookmark)
  suspendData     "…"           # cmi.suspend_data
  totalTime       "0000:12:30"  # cmi.core.total_time

  # attendance (physical / webinar)
  attendedAt      ts
  markedBy        "instructorUid" | "teamsCsv"

  # lifecycle
  assignedAt      ts
  startedAt       ts
  completedAt     ts
  lastAccessedAt  ts
  attempts        2
```

The `status` enum spans **both completion engines** — content types resolve to
`completed/passed/failed`, attendance types to `attended/absent`. Same doc feeds
the same admin tables.

### Write strategy (keeps cost low, enables resume)

SCORM fires `LMSSetValue` constantly — **do not** write each to Firestore. The
Cubit buffers and writes on meaningful moments:

- on **`LMSCommit` / `LMSFinish`** (the SCO's own save signal)
- on **section change** + a **~30s throttle** safety net
- each write updates `progress`, `lessonLocation`, `suspendData`, `status`,
  `score`, `lastAccessedAt`

→ a handful of writes per session, not hundreds. `lessonLocation` + `suspendData`
are what the **Resume** button restores.

Other types: **PDF** → write on the "I've read this" ack; **attendance** → one
write when marked / when the Teams CSV reconciles (reuse the existing attendance flow).

### ⚠️ Trust gotcha (exams)

SCORM runs client-side and the client writes to Firestore → a savvy trainee could
spoof `status: "passed"`.

- **Firestore rules:** a trainee may write **only their own** enrollment and
  **only** the progress fields — never someone else's, never
  `mandatory`/`assignedAt`.
- **Graded exams:** validate the pass **server-side** (a Cloud Function recomputes
  score from submitted answers) rather than trusting the client `score`. Decide
  **per material**: "trust SCORM score" (cheap) vs "server-validated" (tamper-proof).

---

## 10. Admin tracking

Two report surfaces, both querying `enrollments`; one reporting engine covers all
four types.

**1. Per-material** ("who's doing Fire Safety?") — `material_table_view`:

```
Fire Safety Basics          ▓▓▓▓▓▓▓░░░  72% complete (36/50)
┌───────────────┬──────────┬──────┬───────┬───────────┐
│ Trainee       │ Status   │ %    │ Score │ Last seen │
├───────────────┼──────────┼──────┼───────┼───────────┤
│ Sara A.       │ Passed ✓ │ 100  │ 88    │ 2d ago    │
│ Omar K.       │ In prog. │  60  │  —    │ 3h ago    │
│ Lina M.       │ Overdue  │   0  │  —    │ never     │
└───────────────┴──────────┴──────┴───────┴───────────┘
   Filter: [Region ▾] [Contractor ▾] [Status ▾]   [Export CSV]
```

**2. Per-trainee** ("how is Omar doing?") — all his enrollments across
courses/paths; onboarding path shown as a stepper of passed/locked steps.

**Plus a dashboard tile:** completion rate per course, overdue counts,
filterable by region/contractor (reuses the existing Regions/Contractors grouping).

---

## 11. Open questions — resume here ❓

1. **Exam mechanism** — SCORM-reported pass/score, or a separate quiz built in the
   app? Where does the pass threshold live (package vs Firestore)? (Affects
   self-paced + path completion logic and the trust model in §9.)
2. **Path item types** — can a path mix Self-Paced SCORM *and* standalone PDFs as
   steps? Does a PDF step need an "I've read this" acknowledgment to count as passed?
3. **Retention / OneDrive scope** — does on-demand streaming apply to all payloads
   (PDFs, recordings) or just SCORM?
4. **Attempts / retakes** — on exam failure, retry the *same* enrollment (increment
   `attempts`, overwrite `score`) or spawn a new attempt record (full history)?
5. **Assignment source** — is an `enrollment` pre-created when the admin assigns
   (status `notStarted`, so "never started / overdue" shows up) or created lazily
   on first open? (Pre-creating is what surfaces "Lina M. — never started".)
6. **Webinar auto-pull** — start with manual Teams CSV upload; when/if to move to
   Graph API auto-reconcile.
7. **Admin authoring flow** — the "New Session" wizard: step 1 picks
   `deliveryType`, then the form adapts (physical: location/appointments/instructor/
   geofence; webinar: time/link/host + CSV upload; self-paced: SCORM upload + exam;
   path: ordered item builder with drag-reorder). To be detailed.
8. **Web SCORM player** — the real build item (iframe + `window.API` bridge → Cubit
   → Firestore). To be specified.

---

## 12. Build order — admin side first (in progress)

We're building the **admin plumbing** before any trainee viewing. What a trainee
sees, and the whole SCORM serve/play pipeline, comes after.

**Step 1 — this pass (admin only):**
- New **`lib/materials/`** feature: `materials` collection + Firebase Storage.
  - **Materials tab** in the app shell for both **managers** (admin01) and
    **instructors** (admin02): list + **Upload** / edit / delete. Managers get it
    from the shared shell-level `MaterialsCubit`; the instructor tab provides its
    own `MaterialsCubit` since that shared provider is manager-only.
  - Upload = pick a `.zip` → store at `materials/{id}/…` in Storage → write a
    Firestore doc (title, type, size, exam info, `created_by`). Status `uploaded`.
  - Library is **shared/unscoped** — every admin sees every material.
- **Session gets a type + material:** add `deliveryType`
  (`physical | selfPaced | webinar`) and `material_id` to the session doc. The
  "Add/Edit session" dialog gains a **type dropdown** + a **material picker**
  (hidden for `physical`; required for `selfPaced`). Trainee assignment unchanged.
- **Scale — choosing from many materials:** each material stores a `year`
  (auto = upload year). Both the Materials tab and the session material picker
  are **searchable (by title) + filterable by year + type**. The picker is a
  searchable dialog, not a dropdown. Filtering is **client-side** for now (fine
  up to ~1–2k materials); beyond that, move the year/type legs to server-side
  `where` queries + pagination (Firestore has no full-text search, so title
  search stays client-side or needs a search service).

**Step 2 — trainee side, slice 1 (this pass): enrollments + viewer scaffold.**
- New **`lib/enrollments/`** feature: top-level `enrollments` collection,
  `enrollments/{sessionId}_{userId}` (one per trainee × session).
  - **Pre-created at assignment:** `CourseRepository.addSession` / `editSession`
    call `EnrollmentRepository.syncSessionEnrollments` — creates a `notStarted`
    record per assigned trainee for material-backed (self-paced) sessions,
    prunes on unassign, removes on session/course delete. Physical/webinar
    attendance still uses the appointment flow (not enrollments) for now.
  - Status split: `lifecycle_state` (notStarted/inProgress/done) + `outcome`
    (passed/failed/…); display fields (`title`, exam) denormalized at assignment.
  - **Trainee Courses tab** shows a **"My learning"** list (their self-paced
    enrollments) with progress + Start/Resume/Review → opens the **Material
    Viewer** shell (§8). Opening marks the enrollment started.
- **Viewer body is a placeholder** — the real SCORM `<iframe>` + `window.API`
  bridge lands with the serving pipeline. `EnrollmentRepository.updateProgress`
  is written and ready for the player to call.

**Step 3 — serving pipeline (this pass): built, deploy required.**
- New **`functions/`** package (2nd-gen Cloud Functions, Node 20):
  - `processMaterialUpload` (Storage trigger) — unzips `materials/{id}/*.zip`
    into `materials/{id}/extracted/…`, parses `imsmanifest.xml` for the launch
    file + title, updates the material doc: `status` uploaded → processing →
    ready|failed, plus `entry_point`.
  - `serveScorm` (HTTP) — streams an extracted file with the right content-type.
- **Served same-origin** via a Firebase **Hosting rewrite** `/scorm/** →
  serveScorm` (firebase.json). Same-origin is required: the SCO reads
  `window.parent.API`, which the browser blocks cross-origin. So SCORM only
  plays on **deployed Hosting** (or the emulator), not `flutter run` alone.
- Flutter: `TrainingMaterial` reads `entry_point` + `status`; the admin Materials
  list shows a Pending/Processing/Ready/Failed pill.
- Repo config added: `functions` + `hosting` + `storage`/`firestore` rules in
  firebase.json, `.firebaserc`, `storage.rules`.

**Step 4 — cross-platform SCORM player (this pass): wired + compiling, untested.**
Full write-up: [scorm_player.md](scorm_player.md).
- New **`lib/enrollments/scorm/`**. One `ScormPlayer` widget, platform-selected
  by conditional import:
  - **web** (`_web.dart`) — `<iframe>` (`HtmlElementView`) + `window.API` on the
    parent window via `dart:js_interop`. Same-origin (Hosting rewrite).
  - **native** (`_io.dart`, Android/iOS/Windows/macOS) — `flutter_inappwebview`
    loading the serving URL, `window.API` injected at **document start** (a
    `UserScript`); SCO → `callHandler('scorm', …)`. No same-origin constraint.
- **Shared, written once:** the SCORM 1.2 `window.API` JS (`scorm_api_js.dart`,
  non-writable `window.API` per the CLAUDE.md gotcha) and the CMI→progress
  interpreter (`scorm_session.dart`) that decides when to persist (commit/finish
  or meaningful change) → `updateProgress`. Resume seeds `lesson_location` /
  `suspend_data` / entry mode into the CMI map.
- Viewer plays the package when `status == ready`; otherwise shows a
  processing/failed/unavailable state. Progress + resume flow through Firestore.
- **Not runtime-tested:** compiles (analyze + `build web`) but needs a live
  deploy (web) and a device/emulator (native) to validate. Native setup notes:
  Android `minSdkVersion` ≥ 21 for `flutter_inappwebview`; Windows needs the
  WebView2 runtime; set `kScormHostingOrigin` (scorm_config.dart) to your
  Hosting domain for native.

**Deferred to later passes:**
- **Admin reporting** off `enrollments` (per-session / per-material / overdue).
- Unify physical/webinar attendance into `enrollments`; exam trust/rules;
  material deletion guard ("used in N sessions") for the picker; versioning;
  CDN in front of `serveScorm`; video hosting; SCORM 2004 (`API_1484_11`).
