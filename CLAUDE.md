# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**Academy Platform** — a Flutter learning/training platform for a single
company's employees (regions, contractors, trainees, courses, scheduling). It is
growing out of a **SCORM-player proof-of-concept**; the platform layers (Firebase
auth, admin management, role-based shell) are being built on top of it,
milestone by milestone.

- Product vision & production architecture: [documentation/academyBrainstorm.md](documentation/academyBrainstorm.md)
- Kickoff requirements for the platform: [documentation/academy_firstmeet.md](documentation/academy_firstmeet.md)
- How the SCORM player POC is built: [documentation/scormPocImplementation.md](documentation/scormPocImplementation.md)
- **Milestone 1 (auth + role shell + admin Regions/Contractors):** [documentation/foundationAdminImplementation.md](documentation/foundationAdminImplementation.md)
- **Trainee UI (design system + Home/Courses/Schedule/Profile):** [documentation/ui_design/trainee_ui.md](documentation/ui_design/trainee_ui.md)
- **Courses (Firestore courses → sessions → appointments + admin authoring):** [documentation/courses/courses_implementation.md](documentation/courses/courses_implementation.md)

**Read the relevant docs before making non-trivial changes.**

## Current scope

- **Primary target: web.** Also intended for Windows / Android / iOS.
- **Backend: Firebase** (project `academyplatform-12c05`) — email/password auth +
  Firestore. Microsoft/Entra sign-in is wired but **dormant**.
- **Done (Milestone 1):** Firebase email/password auth, role gating (`admins`
  collection → admin vs. trainee), responsive role-aware shell (NavigationRail /
  Drawer), admin **Regions** and **Contractors** screens (Firestore-backed).
- **SCORM player POC** is preserved under `lib/academy/` as the **Courses** tab.
  It plays one ADL sample and tracks completion **in-memory**. The player uses
  `webview_windows` and so is **Windows-only** — it throws on web.

Layers listed in the brainstorm/firstmeet docs but **not yet built** (trainees,
courses/sessions/appointments, enrollment/attendance, Firestore security rules,
account provisioning) — do not assume they exist.

## Commands

```bash
flutter pub get          # install deps
flutter analyze          # lint/type-check (keep this clean)
flutter run -d chrome    # run the app (primary target: web)
flutter build web        # verify the web build
```

Run `flutter analyze` after changes; the project is expected to report
**"No issues found"**.

> The Windows desktop build (`flutter build windows`) pulls Firestore's native
> gRPC/C++ SDK (~8 GB of build output) and needs several GB free on the build
> drive to link — it filled `D:` and failed with `LNK1116 … error code 112`
> (disk full). Prefer the web build for verification.

## Dev preview switch

[lib/main.dart](lib/main.dart) has `const bool kSkipAuthForPreview`: `true` skips
login and opens `AppShell(isAdmin: true)` directly (to eyeball the layout);
`false` restores the normal login → role-gated flow.

## Architecture

Flutter + **Cubit** (`flutter_bloc`) throughout. Firebase (`firebase_auth` +
`cloud_firestore`) for auth and data. Tables use `material_table_view`; icons use
`flutter_tabler_icons`. The app is organised into feature modules under `lib/`:

```
lib/
  main.dart                # app root: Firebase init, AuthCubit, theme, kSkipAuthForPreview
  firebase_options.dart    # generated (flutterfire configure)
  theme/app_theme.dart     # AppColors (Nahdi palette) + AppTheme.light()
  shell/app_shell.dart     # responsive role-aware NavigationRail / Drawer + tabs

  auth/                    # Firebase email/password (+ dormant Microsoft/Entra)
    cubit/auth_cubit.dart  #   signInWithEmail / signInWithMicrosoft / _resolveRole
    cubit/auth_state.dart  #   AuthStatus + AppRole + isAdmin
    models/auth_user.dart  #   AuthUser.fromFirebase()
    data/microsoft_auth_service.dart   # OAuth2+PKCE (dormant)
    ui/login_page.dart     #   email/password form
    ui/auth_gate.dart      #   signed-in? -> AppShell : LoginPage

  admin/                   # admin-only screens (Regions, Contractors)
    models/   region.dart, contractor.dart
    data/     region_repository.dart, contractor_repository.dart   # Firestore
    cubit/    regions_cubit.dart, contractors_cubit.dart           # live streams
    ui/       regions_page.dart, contractors_page.dart,
              contractor_edit_dialog.dart, admin_dashboard_page.dart, admin_widgets.dart

  academy/                 # the SCORM player POC (Courses tab) — Windows-only
    models/course.dart, cubit/courses_cubit.dart, data/scorm_asset_server.dart,
    data/course_repository.dart, scorm/scorm_adapter.dart,
    ui/scorm_player.dart, ui/home_page.dart, utils/log.dart
```

**Auth/role flow:** `LoginPage` → `AuthCubit.signInWithEmail` → role resolved from
the `admins` collection → `AuthGate` shows `AppShell(isAdmin)`. Admin tabs share a
`RegionsCubit` + `ContractorsCubit`; the Courses tab lazily provides `CoursesCubit`.

**Firestore model:** `admins/{uid}{email}` · `regions/{id}{name}` ·
`contractors/{id}{name,email,phone,address,regionIds[]}`. The region↔contractor
link is **many-to-many, stored on the contractor** (`regionIds`); deleting a
region scrubs it from all contractors.

**SCORM data flow (academy/):** user selects course → `CoursesCubit.selectCourse`
→ `ScormPlayer` serves + loads the package → injected `window.API` posts SCORM
events via `window.chrome.webview.postMessage` → `ScormPlayer._onWebMessage` →
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

- Use the `log*` helpers in `lib/academy/utils/log.dart` for console output
  (tagged `[SCORM]` / `[SERVER]` / `[CUBIT]` / `[AUTH]` / `[ERROR]`), not bare
  `print`.
- **Cubit per feature** (`flutter_bloc`); keep UI widgets stateless where
  practical and read state via `BlocBuilder` / `context.watch`. Firestore access
  goes through a repository class; cubits subscribe to the repo's stream.
- Use **`AppColors` / `AppTheme`** (`lib/theme/app_theme.dart`) for brand colours,
  **`material_table_view`** for data tables, and **`flutter_tabler_icons`** for
  icons.
- Keep `flutter analyze` clean.
