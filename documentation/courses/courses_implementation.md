# Courses — Implementation

**Last updated:** 2026-06-27 · see [Changelog](#10-changelog) for history.

How the **Courses** feature works: the Firestore-backed course list, the
course → session → appointment drill-down, the admin authoring actions, and how
the old SCORM/demo course code was parked.

> Scope today: list courses, drill into sessions and appointments, and let
> admins author courses/sessions/appointments. Per-trainee enrollment filtering
> and resolving trainer ids to names are **not** built yet (see
> [Limitations & next steps](#limitations--next-steps)).

---

## 1. Where it lives

```
lib/courses/
  models/
    course.dart          # Course + CourseSession (sessions are doc FIELDS)
    appointment.dart     # Appointment (date, enrolled_trainer ids, location)
    session_detail.dart  # SessionDetail (appointments + assigned trainer ids)
  data/
    course_repository.dart   # Firestore reads (stream + loadSession) and writes
  cubit/
    courses_cubit.dart       # live stream + loadSession + admin write delegates
    courses_state.dart       # { courses, loading, error }
  ui/
    courses_list_body.dart   # trainee list (Home / Courses / Schedule)
    admin_courses_page.dart  # admin Courses tab + "Add course"
    course_expansion_tile.dart  # course → session → appointment drill-down
    course_admin_dialogs.dart   # "Add session" / "Add appointment" dialogs
```

Shared logging lives in `lib/academy/utils/log.dart` (`logCourse` → `[COURSE]`
tag).

---

## 2. Firestore data model

The `courses` collection. **This shape was reverse-engineered from the real
data — mind the gotchas below.**

```
courses/care360                         (document)
  title: "Care 360"                     (optional display name; falls back to doc id)
  session1-Health360: "about medicine"  (a SESSION — field name + description)
  session2-beauty360: "about beauty"    (a SESSION)

  └─ Health360/                         (sub-collection; name = field key minus "sessionN-")
       appointment1                     (document)
         date: <Timestamp>
         enrolled_trainer: [222, 444, 555]   (int ARRAY of trainer ids)
         location: "voco hotel"
       assigned_trainer                 (document — SINGULAR)
         assign_to: [222, 111, 333, …]  (int ARRAY of trainer ids)

  └─ beauty360/
       appointment1, appointment2, …
       assigned_trainer
```

### Key rules / gotchas

1. **A course's sessions are stored as FIELDS on the course document**, not as a
   `sessions` array and not as something the app can enumerate. Each non-`title`
   field is one session: the field *name* is the session key, the field *value*
   is its description.
2. **The session field key carries an ordering prefix** `sessionN-`. The actual
   **sub-collection name is the key with that prefix stripped**:
   `session2-beauty360` → sub-collection `beauty360`. Parsing lives in
   `CourseSession.fromField` (regex `^session\d+-`).
3. **The trainers doc is `assigned_trainer` (singular)** with an `assign_to`
   int array. (The code also accepts the plural `assigned_trainers` defensively.)
4. **`enrolled_trainer` on an appointment is an int array** of trainer ids, not
   a single name.
5. **Why fields, not sub-collection listing?** The Flutter / web `cloud_firestore`
   client **cannot list a document's sub-collections** (`listCollections` is
   Admin-SDK / server-side only). So the session names *must* live in readable
   fields on the course doc — that is the whole reason for the field-based model.
6. **Phantom documents:** a course document holding *only* sub-collections (no
   top-level fields) will **not** appear in a collection query. Every course
   doc needs at least a `title` field (the "Add course" action writes one).

---

## 3. Data flow

### Listing courses (live)

`CourseRepository.watch()` streams `courses.snapshots()` → maps each doc through
`Course.fromDoc` (which derives the `CourseSession` list from the doc fields) →
`CoursesCubit` emits `CoursesState`. Because sessions are fields on the course
doc, **they load with the list — no extra fetch to show a course's sessions.**

`CoursesCubit` is provided:

- **Admin/trainer:** per Courses tab in `lib/shell/app_shell.dart`
  (`BlocProvider(create: CoursesCubit())` → `AdminCoursesPage`).
- **Trainee:** once in `lib/user/user_home.dart`, shared by the Home, Courses
  and Schedule screens (`CoursesListBody`).

### Loading a session's appointments (on demand)

When a session row is **expanded**, `_SessionTile` calls
`CoursesCubit.loadSession(courseId, sessionName)` →
`CourseRepository.loadSession`, which `get()`s the session sub-collection and:

- splits the `assigned_trainer` doc out of the appointment docs,
- parses appointment docs via `Appointment.fromDoc`,
- returns a `SessionDetail { appointments, assignedTrainerIds }`.

The result is held in a `FutureBuilder` so it only fetches once per expand
(re-fetched after an admin write — see below).

---

## 4. Screens

### Trainee (`CoursesListBody`)

Used by **Home**, **Courses** and **Schedule** (`lib/ui/screens/…`). For now all
three show **every** course (no per-trainee filtering yet). Renders
`CourseExpansionTile(isAdmin: false)` — so trainees can drill into sessions and
appointments but see **no** assigned-trainer roster and **no** admin buttons.

### Admin (`AdminCoursesPage`)

The **Courses** tab in the admin shell. Header shows the course count plus the
**Add course** button. Body is a list of `CourseExpansionTile(isAdmin: true)`.

---

## 5. Admin authoring (add / edit / delete)

All actions are gated by the `isAdmin` flag, which is `true` **only** in
`AdminCoursesPage`. Trainees render with `isAdmin: false`, so they never get the
buttons. (See [Roles](#6-roles--gating).)

Each level has its actions grouped together: course actions sit in the course's
expanded body, session actions in the session's expanded body, and appointment
actions are pencil/trash icons on each appointment row.

### Add

| Action | Where | Dialog | Firestore write |
|---|---|---|---|
| **Add course** | Courses tab header | `promptForText` (name) | `courses/{name}` set `{title: name}` (merge) |
| **Add session** | under each course | name + description | course doc field `session{N}-{name}: description` (merge); `N = sessions.length + 1` |
| **Add appointment & assign** | under each session | date+time, location, trainer ids (comma-separated ints) | `…/{session}/appointment{N}` with `date`/`location`/`enrolled_trainer`; **plus** `assign_to` union into `…/assigned_trainer` |

### Edit (safe fields only — ids / keys never change)

| Action | Editable | Firestore write |
|---|---|---|
| **Edit course** | `title` | `courses/{id}` set `{title}` (merge). Doc id is fixed. |
| **Edit session** | description | update the `session{N}-{name}` field **value**. The field key (→ sub-collection name) is fixed, so links don't break. |
| **Edit appointment** | date / location / trainer ids | re-uses the appointment dialog **pre-filled** (via `Appointment.dateTime`); merge-writes the appointment + unions trainer ids into `assigned_trainer`. |

### Delete (cascades)

| Action | Firestore write |
|---|---|
| **Delete course** | batch-delete every session sub-collection's docs (names come from the course's session fields), then delete the course doc. |
| **Delete session** | batch-delete the session's appointment sub-collection, then `FieldValue.delete()` the session field on the course doc. |
| **Delete appointment** | delete the single `appointment{N}` doc. |

> The client can't enumerate sub-collections, so cascade deletes iterate the
> **known** session names (from the course fields) and use a batched
> `_deleteSubcollection` helper. `assigned_trainer` rosters are **not** pruned on
> appointment delete (recomputing them is out of scope for now).

Write methods live on `CourseRepository` (`addCourse`/`addSession`/
`addAppointment` + `editCourse`/`editSession`/`editAppointment` +
`deleteCourse`/`deleteSession`/`deleteAppointment`) and are delegated through
`CoursesCubit`. Dialogs/confirmations are in `course_admin_dialogs.dart` plus the
shared `promptForText` / `confirmDelete` from `admin/ui/admin_widgets.dart`.

**Refresh behaviour:**

- Add/edit/delete that mutate the **course document** (course title, session
  field) → the `courses` stream re-emits → the list updates automatically.
- Add/edit/delete that mutate a **sub-collection** (appointments) aren't watched,
  so `_SessionTile` re-runs `loadSession` via its `onChanged` callback to refresh
  the session immediately.

---

## 6. Roles & gating

Role resolution (`lib/auth/cubit/auth_state.dart`): the `admins` doc's `role`
maps `admin01` → **manager**, `admin02` → **trainer**; anyone else is a
**trainee**. Both manager and trainer are `isAdmin`.

- **Trainees** → `UserHome` → `CoursesListBody(isAdmin: false)`. Read-only, no
  trainer roster, no buttons.
- **admin01 + admin02** → `AppShell` → `AdminCoursesPage` →
  `CourseExpansionTile(isAdmin: true)`. Full roster + all add/edit/delete
  buttons.

> The gating is **client-side only**. Firestore security rules to restrict
> `courses` writes to admin01/admin02 are not written yet.

---

## 7. Logging

Every level logs via `logCourse` (`[COURSE]` tag, `debugPrint` — debug builds
only):

- `watch()` logs the collection size, each course's raw `doc.data()`, and the
  parsed title + session names.
- `loadSession()` logs the path queried, each doc's raw fields, the parsed
  appointment fields, the assigned trainer ids, and a per-session summary.
- The UI logs `course selected → …` and `session selected → …` on expand.

This is the first thing to check when "nothing shows": the raw `doc.data()` log
tells you whether it's a field-name mismatch or a wrong sub-collection path.

---

## 8. The migration (old course code → `lib/courses_old/`)

The Courses screens used to be a SCORM-player POC (`lib/academy/`) plus a set of
demo-data trainee screens. Those were **moved, not deleted**, to
`lib/courses_old/` (so they can be revived later):

- `lib/courses_old/academy/…` — the whole SCORM player POC.
- `lib/courses_old/trainee_courses_screen.dart`,
  `lib/courses_old/course_detail_screen.dart` — the demo catalogue + detail.

`lib/academy/utils/log.dart` was **kept in place** — it is the project-wide
logging convention used by auth/admin, not course-display code. The design-system
widgets and `lib/ui/models/learning.dart` (demo `Course`/`DemoData`) also stayed,
since the Profile screen and the parked screens still use them.

---

## 9. Limitations & next steps

- **Trainer ids are shown raw** (`Trainer 222`). Resolving them to names needs a
  confirmed mapping between the int ids and the `trainers` collection
  (`Trainer.trainerId` is free-text String). The "assign" input also takes raw
  ids rather than a trainer picker.
- **No per-trainee filtering.** Trainee Home/Courses/Schedule show every course;
  the plan is to narrow to the trainee's assignments via `assign_to`.
- **No security rules.** Course writes/deletes are open; lock them to
  admin01/admin02.
- **Edit is safe-fields-only.** Renaming a course (doc id) or session
  (sub-collection key) is not supported — it would require migrating the
  underlying docs/sub-collections.
- **Cascade deletes run client-side** via batched writes. If a delete is
  interrupted, sub-collection docs can be orphaned; a Cloud Function `onDelete`
  trigger is the eventual robust home for this. `assigned_trainer` rosters
  aren't pruned when appointments are deleted.
- **Appointment ids** are `appointment{N}` by count — concurrent adds could
  collide; fine for single-admin authoring.
- **Data hygiene:** the sample data had a typo field `enrroled_trainer`
  alongside `enrolled_trainer`; the app reads only the correctly-spelled one.

---

## 10. Changelog

### 2026-06-27 — Admin edit & delete

Added **Edit** and **Delete** actions beside the existing Add buttons, gated to
admin01/admin02 (`isAdmin`):

- **Edit** (safe-fields-only): course `title`, session description, appointment
  date/location/trainer ids (dialog pre-filled via the new `Appointment.dateTime`).
  Course ids and session keys never change, so the
  course→session→appointment links can't break.
- **Delete** (cascades): delete course (clears all session sub-collections then
  the course doc), delete session (clears its appointment sub-collection then
  removes the session field), delete appointment (single doc). Cascades use a
  batched `_deleteSubcollection` over the **known** session names.
- New repo/cubit methods: `editCourse`/`editSession`/`editAppointment` and
  `deleteCourse`/`deleteSession`/`deleteAppointment`. Appointment dialog
  generalised to add **and** edit. See [§5](#5-admin-authoring-add--edit--delete).

### 2026-06-27 — Admin authoring (add) + real data model

- **Add** course / session / appointment, with trainer assignment unioned into
  the session-level `assigned_trainer` roster.
- Reworked the data model to the **real** Firestore shape: sessions as course-doc
  fields with a `sessionN-` ordering prefix → sub-collection name; singular
  `assigned_trainer`; `enrolled_trainer` as an int array. Added `[COURSE]`
  logging at every level. See [§2](#2-firestore-data-model), [§7](#7-logging).

### 2026-06-27 — Initial Courses feature

- Firestore-backed live course list, course → session → appointment drill-down,
  separate trainee (read-only) and admin views.
- Parked the old SCORM player POC + demo course screens under
  `lib/courses_old/`. See [§8](#8-the-migration-old-course-code--libcourses_old).

> Dates reflect when each piece was documented in this milestone; consult
> `git log` for exact commit timestamps.
