# Admin: Regions & Instructors — Feature Documentation

This document describes the admin-facing screens under
[lib/admin/](../../lib/admin/) and walks the full path **from login to creating
a region and adding an instructor**. It covers four screens specifically:

- [admin_dashboard_page.dart](../../lib/admin/ui/admin_dashboard_page.dart) — the admin landing screen
- [regions_page.dart](../../lib/admin/ui/regions_page.dart) — region CRUD
- [instructors_page.dart](../../lib/admin/ui/instructors_page.dart) — instructor CRUD + region assignment
- [instructor_edit_dialog.dart](../../lib/admin/ui/instructor_edit_dialog.dart) — the add/edit instructor form

---

## 1. Roles at a glance

Authority is decided by the `role` field on the user's document in the Firestore
`admins` collection. The role is resolved once, right after sign-in.

| `admins.role` | `AppRole` | What they see |
|---------------|-----------|---------------|
| `admin01` | `manager` | Dashboard, Regions, Instructors, Courses |
| `admin02` | `instructor` | Courses only |
| *(no admin doc)* | `trainee` | The user home screen (`UserHome`) — never reaches the admin shell |

Defined in [auth_state.dart](../../lib/auth/cubit/auth_state.dart):
`AppRole.fromAdminRole()` maps the string; `isAdmin` is `manager || instructor`.

> **Key point:** The Regions, Instructors and Dashboard screens are **manager-only**
> (`admin01`). An `instructor` signs in successfully but only gets the Courses tab.

---

## 2. From login to the admin shell

```
LoginPage ──► AuthCubit.signInWithEmail ──► _resolveRole(email) ──► AuthGate ──► AppShell(role)
   (UI)            (Firebase Auth)           (admins lookup)        (routes)     (manager tabs)
```

### 2.1 Login screen
[login_page.dart](../../lib/auth/ui/login_page.dart)

- Email + password form (validated: email must contain `@`, password non-empty).
- On submit → `context.read<AuthCubit>().signInWithEmail(email, password)`.
- The button shows a spinner / "Signing in…" while `state.isBusy`.
- Errors render in a red `_Notice` box (friendly text mapped from
  `FirebaseAuthException`).
- "Continue without signing in" calls `continueAsGuest()` → enters as a
  `trainee` (dev convenience).
- The Microsoft/Entra path exists in `AuthCubit.signInWithMicrosoft` but is
  **dormant**.

### 2.2 Sign-in + role resolution
[auth_cubit.dart](../../lib/auth/cubit/auth_cubit.dart)

1. `status` → `signingIn`; errors cleared.
2. `FirebaseAuth.signInWithEmailAndPassword` authenticates.
3. An `AuthUser` is built (name falls back to displayName → email).
4. **`_resolveRole(email)`** queries
   `admins` where `email == <lower-cased sign-in email>` (limit 1):
   - Match found → `AppRole.fromAdminRole(doc.role)` (`admin01`/`admin02`).
   - No match → `trainee`.
   - A thrown error (commonly a Firestore **permission-denied** from security
     rules) is logged and also falls back to `trainee`.
5. `status` → `signedIn` with `user` + `role`.

> The `admins` docs are created **by hand in the Firebase console**, and the
> stored `email` must match the sign-in email exactly (case-insensitive compare).

### 2.3 Routing by role
[auth_gate.dart](../../lib/auth/ui/auth_gate.dart)

- Not signed in → `LoginPage`.
- Signed in + `trainee` → `UserHome`.
- Signed in + `manager`/`instructor` → `AppShell(role, accessToken)`.

### 2.4 The shell
[app_shell.dart](../../lib/shell/app_shell.dart)

- Responsive: `NavigationRail` (width ≥ 900) or a `Drawer` (narrow).
- Tab set is role-driven (see `_tabs`): a **manager** gets
  Dashboard / Regions / Instructors / Courses; an **instructor** gets only Courses.
- **The shared admin data lives here:** when the user is a manager, the shell
  wraps everything in a `MultiBlocProvider` that creates one `RegionsCubit` and
  one `InstructorsCubit`. Both the Regions and Instructors tabs read these same
  instances, so counts and lists stay consistent across tabs.
- Footer shows the user's initials, role label, and a **Sign out** button
  (`AuthCubit.signOut`).

> **Dev preview:** `kSkipAuthForPreview` in [main.dart](../../lib/main.dart),
> when `true`, skips login and opens `AppShell(role: AppRole.manager)` directly.

---

## 3. Admin Dashboard
[admin_dashboard_page.dart](../../lib/admin/ui/admin_dashboard_page.dart)

The manager's landing tab. Purely a read-only summary:

- Greeting: `"Welcome, <name>"` from `AuthCubit.state.user?.name`.
- Two live stat cards built from the shared cubits:
  - **Regions** — `context.watch<RegionsCubit>().state.regions.length`
  - **Instructors** — `context.watch<InstructorsCubit>().state.instructors.length`
- Because both cubits stream live from Firestore, the counts update
  automatically as regions/instructors are added or removed elsewhere.

More tiles (courses, trainees) are planned for later milestones.

---

## 4. Regions screen
[regions_page.dart](../../lib/admin/ui/regions_page.dart)

A list of company regions (East, West, Central, …) with add / rename / delete.

### Data layer
- **Model** [region.dart](../../lib/admin/models/region.dart): a region holds
  only `id` + `name`. The region↔instructor link is stored on the **instructor** side,
  not here.
- **Repository** [region_repository.dart](../../lib/admin/data/region_repository.dart):
  Firestore `regions` collection.
  - `watch()` streams docs ordered by `name`.
  - `add(name)` — **uses the region name itself as the document id**
    (`_col.doc(name).set({'name': name})`).
  - `rename(id, name)` updates the `name` field.
  - `delete(id)` removes the doc.
- **Cubit** [regions_cubit.dart](../../lib/admin/cubit/regions_cubit.dart):
  subscribes to `watch()`, emits `RegionsState(regions, loading, error)`. It
  also holds an `InstructorRepository` to keep the instructor side in sync (see below).

### UI behaviour
- `AdminToolbar` header: map-pin icon, "Regions", an `N region(s)` subtitle, and
  an **Add region** button.
- Body states: spinner while `loading`; an error message if the stream errors;
  an empty-state prompt if there are no regions; otherwise a
  `material_table_view` table with columns **● / Name / Actions**.
- The colour dot uses `AppColors.accentFor(region.name)` (deterministic per
  name) — the same accent is reused as the region chip colour on the Instructors
  screen.
- Row actions: **Rename** (pencil) and **Delete** (red trash).

### Add / rename a region
`RegionsPage._edit` opens `promptForText` (a single-field dialog from
[admin_widgets.dart](../../lib/admin/ui/admin_widgets.dart)):
- New region → `cubit.add(name)`.
- Existing → `cubit.rename(region.id, name)`.
- Empty/cancelled input is ignored.

### Delete a region (with cascade)
`confirmDelete` warns: *"It will also be removed from any assigned instructors."*
On confirm, `RegionsCubit.delete(id)`:
1. Looks up the region's name.
2. `InstructorRepository.removeRegionFromAll(name)` — batch-removes that name from
   every instructor's `regionNames` array (`FieldValue.arrayRemove`).
3. Deletes the region doc.

Similarly, **rename** cascades: `RegionsCubit.rename` calls
`InstructorRepository.renameRegionInAll(old, new)`, which batch-swaps the old name
for the new one on every affected instructor (arrayRemove + arrayUnion). This keeps
the name-based assignment consistent because instructors store region **names**,
not ids.

---

## 5. Instructors screen
[instructors_page.dart](../../lib/admin/ui/instructors_page.dart)

List / add / edit / delete instructors and assign them to regions (many-to-many,
freely re-assignable).

### Data layer
- **Model** [instructor.dart](../../lib/admin/models/instructor.dart): fields
  `id` (Firestore doc id), `instructorId` (company/staff id, free text),
  `name`, `email`, `phone`, `address`, and `regionNames` (list of region
  **names** — the single source of truth for the assignment). `role` is fixed at
  `admin02`.
- **Repository** [instructor_repository.dart](../../lib/admin/data/instructor_repository.dart):
  Instructors live in the **shared `admins` collection** (not a separate
  `instructors` collection) and are identified by `role == 'admin02'`.
  - `watch()` queries `admins where role == admin02`, then **sorts by name
    client-side** (deliberate — avoids needing a composite Firestore index).
  - `add(t)` — **uses the instructor's `instructorId` as the document id**
    (`_col.doc(t.instructorId).set(t.toMap())`).
  - `update(t)` updates by `t.id`; `delete(id)` removes the doc.
  - `removeRegionFromAll` / `renameRegionInAll` — the cascade helpers called by
    `RegionsCubit` (see §4).
- **Cubit** [instructors_cubit.dart](../../lib/admin/cubit/instructors_cubit.dart):
  subscribes to `watch()`, exposes `add` / `update` / `delete`.

### UI behaviour
- `AdminToolbar`: users icon, "Instructors", `N instructor(s)` subtitle, **Add
  instructor** button.
- Same loading / error / empty / table state pattern as Regions.
- Table columns: **Instructor ID / Name / Email / Phone / Regions / Actions**.
  - The **Regions** cell renders each assigned region as a coloured
    `_RegionChip` (horizontally scrollable; `—` when none).
- Row actions: **Edit** (pencil) and **Delete** (red trash). Delete confirms via
  `confirmDelete` then `cubit.delete(t.id)`.

### Add / edit an instructor
`InstructorsPage._edit`:
1. Reads the current region list from the **shared** `RegionsCubit`
   (`context.read<RegionsCubit>().state.regions`) so the dialog can offer region
   chips.
2. Opens `InstructorEditDialog.show(...)`.
3. New instructor → `cubit.add(result)`; existing → `cubit.update(result)`.

---

## 6. Instructor edit dialog
[instructor_edit_dialog.dart](../../lib/admin/ui/instructor_edit_dialog.dart)

The add/edit form. Returns an edited `Instructor` (with empty `id` for a new one)
or `null` if cancelled.

- Text fields (each with a Tabler icon prefix):
  - **Instructor ID** — required.
  - **Name** — required.
  - **Email** — optional, but must contain `@` if filled.
  - **Phone** — optional (phone keyboard).
  - **Address** — optional (2 lines).
- **Assigned regions** — a `Wrap` of `FilterChip`s, one per region from the
  passed-in list. Selecting toggles the region **name** in a local `Set`. Chip
  colours come from `AppColors.accentFor(name)`. If no regions exist yet, it
  shows *"No regions defined yet — add regions first."*
- **Save** validates the form, then builds the `Instructor` from the controllers +
  selected region names and `Navigator.pop`s it back to `InstructorsPage._edit`.

> Because assignment is captured as a free `Set` of names re-derived from the
> live region list each time the dialog opens, instructors are **freely
> re-assignable** and the data always references currently-existing regions.

---

## 7. End-to-end: "create a region, then add an instructor"

1. **Sign in** as a manager (`admins` doc with `role: admin01`, matching email).
2. `AuthGate` routes to `AppShell(role: manager)`; the shell provisions the
   shared `RegionsCubit` + `InstructorsCubit`.
3. Open the **Regions** tab → **Add region** → type e.g. `Central` → Save.
   - `RegionsCubit.add` → `RegionRepository.add` writes `regions/Central`.
   - The live stream pushes it back; the table and the Dashboard "Regions" count
     update.
4. Open the **Instructors** tab → **Add instructor**.
   - The dialog reads regions from the shared `RegionsCubit`, so `Central`
     appears as a selectable chip.
   - Fill Instructor ID + Name (required), optionally email/phone/address, tick the
     `Central` chip → Save.
   - `InstructorsCubit.add` → `InstructorRepository.add` writes
     `admins/<instructorId>` with `role: admin02` and `regionNames: ['Central']`.
   - The live stream pushes it back; the instructor row shows a `Central` chip and
     the Dashboard "Instructors" count updates.
5. Later, **renaming** or **deleting** `Central` from the Regions tab cascades to
   this instructor's `regionNames` automatically (§4).

---

## 8. Firestore data model (recap)

```
admins/{instructorId}        # also holds managers; instructors are role == admin02
  role:        "admin02"
  instructorId:   "<company staff id>"   (== document id for instructors)
  name, email, phone, address
  regionNames: ["Central", ...]       # region NAMES, many-to-many source of truth

admins/{uid-or-id}        # managers
  role:  "admin01"
  email: "<matches sign-in email>"

regions/{name}            # document id == region name
  name: "Central"
```

### Conventions worth remembering
- **Region docs are keyed by name; instructor docs are keyed by `instructorId`.**
- **Instructors store region names, not ids** — hence the rename/delete cascades.
- **Managers and instructors share the `admins` collection**, told apart by `role`.
- The instructor query filters by role and **sorts client-side** to avoid a
  composite index.
- Shared `RegionsCubit`/`InstructorsCubit` are created once in the shell so all
  manager tabs (Dashboard, Regions, Instructors) see the same live data.
