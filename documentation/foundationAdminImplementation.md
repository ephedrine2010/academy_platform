# Milestone 1 — Foundation + Admin Setup

> Status: **built, web build verified** (`flutter analyze` clean, `flutter build web` ✓).
> This is the first layer of the full platform described in
> [academy_firstmeet.md](academy_firstmeet.md) and [academyBrainstorm.md](academyBrainstorm.md),
> built on top of the proven SCORM player ([scormPocImplementation.md](scormPocImplementation.md)).

## 1. What this milestone delivers

The transition from a single-screen SCORM POC to a multi-role application skeleton:

1. **Firebase email/password sign-in** (Microsoft/Entra kept dormant for later).
2. **Role gating** — admin vs. trainee, resolved from an `admins` collection.
3. **A responsive, role-aware main screen** — left sidebar (NavigationRail) on
   wide layouts, a Drawer on narrow ones.
4. **Admin · Regions** — create / rename / delete company regions.
5. **Admin · Contractors** — create / edit / delete contractors and assign them
   to regions (many-to-many, freely re-assignable).
6. **Nahdi brand theme** — deep-teal identity + mosaic accent palette.

The existing SCORM player is preserved as the **Courses** tab (unchanged).

## 2. Decisions locked in the kickoff discussion

| Question | Decision |
| --- | --- |
| Terminology | **Admin** (super user) · **Contractor** (regional manager/instructor) · **Trainee** (the trained employee — what early notes called "trainer/user"). |
| First admin | Hardcoded by hand in an `admins` Firestore collection. |
| Region ↔ Contractor | **Many-to-many**, re-assignable. Stored on the contractor side (`regionIds`). |
| First milestone scope | **Foundation + Admin setup** (this document). |
| State management | Cubit (`flutter_bloc`). |
| Tables | `material_table_view`. |
| Icons | `flutter_tabler_icons`. |

## 3. Firestore data model (this milestone)

```
admins/{uid}        → { email }                  # created by hand in the console
regions/{regionId}  → { name }
contractors/{id}    → { name, email, phone, address, regionIds: [ regionId, ... ] }
```

- The region↔contractor link is the **single source of truth on the contractor**
  (`regionIds`). A region document holds only its name. This avoids keeping two
  mirrored lists in sync.
- A region's contractors are found with
  `contractors.where('regionIds', arrayContains: regionId)`.
- **Deleting a region** scrubs its id from every contractor in one batch
  (`ContractorRepository.removeRegionFromAll`), so no assignment ever dangles.

## 4. Auth & role flow

```
LoginPage (email + password)
  -> AuthCubit.signInWithEmail()
       -> FirebaseAuth.signInWithEmailAndPassword()
       -> _resolveRole(email): admins.where('email' == email) ? admin : trainee
       -> emit(signedIn, user, role)
            |
AuthGate (rebuilds on isSignedIn / role)
  -> AppShell(isAdmin: state.isAdmin)
```

- **Microsoft/Entra** sign-in (`signInWithMicrosoft`) is retained but dormant —
  the company tenant isn't wired up yet. See [auth_config.dart](../lib/auth/auth_config.dart).
- **Guest dev-bypass** ("Continue without signing in") still exists, entering as a trainee.
- The stored admin `email` must match the sign-in email exactly (Firestore can't
  do case-insensitive queries).

## 5. The main screen (shell)

[lib/shell/app_shell.dart](../lib/shell/app_shell.dart)

- **Wide (≥ 900px):** `NavigationRail` (extended) + content, user/sign-out pinned bottom.
- **Narrow (< 900px):** `AppBar` + `Drawer` with the same tabs.
- **Tabs are role-driven:**
  - Admin → Dashboard · Regions · Contractors · Courses
  - Trainee → Courses (the SCORM `HomePage`)
- Admin tabs share a `RegionsCubit` + `ContractorsCubit` (provided once at the
  shell root). The Courses tab lazily provides its own `CoursesCubit`.

## 6. Code layout added

```
lib/
  theme/app_theme.dart            # AppColors (Nahdi palette) + AppTheme.light()
  shell/app_shell.dart            # responsive role-aware NavigationRail/Drawer
  auth/                           # (refactored) Firebase email/password + role
    cubit/auth_cubit.dart         #   signInWithEmail / signInWithMicrosoft / role
    cubit/auth_state.dart         #   AuthStatus + AppRole + isAdmin
    models/auth_user.dart         #   + AuthUser.fromFirebase()
    ui/login_page.dart            #   branded email/password form
    ui/auth_gate.dart             #   -> AppShell
  admin/
    models/region.dart
    models/contractor.dart
    data/region_repository.dart
    data/contractor_repository.dart
    cubit/regions_cubit.dart      (+ regions_state.dart)
    cubit/contractors_cubit.dart  (+ contractors_state.dart)
    ui/regions_page.dart          # material_table_view list
    ui/contractors_page.dart      # material_table_view list + region chips
    ui/contractor_edit_dialog.dart# add/edit form + region FilterChips
    ui/admin_dashboard_page.dart  # greeting + live counts
    ui/admin_widgets.dart         # AdminToolbar, AdminMessage, prompt/confirm dialogs
```

The previous SCORM POC code lives under `lib/academy/` and is unchanged.

## 7. Brand theme

[lib/theme/app_theme.dart](../lib/theme/app_theme.dart) — derived from the Nahdi
logo (`assets/img/TlzUZtPlHwHbR8XLaNi3.jpg`):

- **Core:** deep teal `#0E5257` (primary), darker teal for the rail.
- **Mosaic accents:** blue / green / orange / purple / red / yellow.
- `AppColors.accentFor(name)` returns a deterministic accent per string, so each
  region/contractor chip gets a stable colour.

## 8. Running it

```bash
flutter pub get
flutter analyze            # expected: No issues found
flutter run -d chrome      # primary target (web)
```

### Dev preview switch
[lib/main.dart](../lib/main.dart) has `const bool kSkipAuthForPreview`:

- `true`  → skip login, open `AppShell(isAdmin: true)` directly (eyeball the layout).
- `false` → normal login → role-gated flow.

### To exercise the real admin flow (Firebase console)
1. Authentication → Sign-in method → **enable Email/Password**.
2. Authentication → Users → **add a user** (your login).
3. Firestore → create collection **`admins`**, add a doc with field
   `email` = that user's email. (Skip to come in as a trainee.)
4. For now Firestore needs **rules that allow your reads/writes** (test mode, or a
   proper ruleset). Production rules are a later task.

## 9. Known limits / not yet done

- **No Firestore security rules** authored yet — anyone authenticated can read/write.
- **No in-app account provisioning** — login accounts are created in the Firebase
  console; the admin screens manage Firestore records, not auth users.
- **Courses tab is Windows-only** — the SCORM player uses `webview_windows`; it
  throws on web. Admin screens are platform-agnostic.
- **Windows desktop debug build** pulls Firestore's native gRPC/C++ SDK (~8 GB of
  build output) and needs several GB free on the build drive to link.
- **Microsoft/Entra** sign-in is wired but disabled.

## 10. Next milestones (per the kickoff notes)

- **Trainees** collection + profiles.
- **Courses / Sessions / Appointments** model and the four course types
  (physical, webinar, online/SCORM, onboarding).
- **Enrollment + attendance** (enrolled / attended / absent, with dates).
- **Trainee view** — assigned courses, enrollment status, completed materials.
- **Firestore security rules** and account provisioning.
- **Microsoft/Entra** activation when the company tenant is available.
