# Trainee Home — Assigned Sessions

**Last updated:** 2026-06-30

How a trainee's **Home screen shows the sessions they're assigned to**, and how
they **self-enroll into an appointment** under each session: the `users`
collection, where assignment happens (session authoring), the read-path that
powers the home list, and the enrollment write-path.

> Scope: a trainee signs in and sees, on **Home**, the **sessions** an instructor
> assigned them to (grouped visually by their parent course). Each session card
> expands to its **appointments**, where the trainee can **enroll** (one
> appointment per session — picking another moves them) or **leave**. The
> **Courses** and **Schedule** trainee tabs still show every course for now — see
> [Limitations](#7-limitations--next-steps).

---

## 1. The idea in one line

A trainee is assigned to a **session**. The session's int trainee ids are the
source of truth; each trainee's `users` doc keeps a **reverse link**
(`assigned_sessions`) so the Home screen is a single cheap lookup — no scanning
of every session.

```
admin02 creates/edits a session ──► session.trainees = [1111, 222]
                                └──► users/1111.assigned_sessions += <sessionId>
                                └──► users/222 .assigned_sessions += <sessionId>

trainee opens app ──► users where email == me ──► assigned_sessions
                  └──► fetch those session docs ──► show them on Home
```

---

## 2. Firestore data model

```
users/1111                          (doc id == the trainee's int id, as a string)
  id:    1111                       (int)
  email: "ali@nahdi.sa"             (matches the sign-in email — Home looks up by this)
  name:  "ali"
  assigned_sessions: ["98765…", …]  (array of SESSION doc ids — the reverse link)

sessions/98765…                     (top-level collection; doc id == session_id)
  course_id:   "care360"            (parent course DOC id)
  name, description, session_id, order
  created_by:  "<admin uid>"        (inherited from the course)
  created_by_email: "<admin email>"
  trainees:    [1111, 222]          (int trainee ids — source of truth for "who's in")

sessions/98765…/appointments/appointment1
  date:     <Timestamp>             (logistics — set by the admin)
  location: "Riyadh HQ"
  appointment_id: 1234567890
  enrolled_trainees: [1111]         (int trainee ids who self-enrolled — see §4.1)
  enrolled_instructor: [...]        (the instructor counterpart, unchanged)
```

A trainee holds **at most one appointment per session**, so their int id appears
in **exactly one** appointment's `enrolled_trainees` within a given session (or
none). Enrollment is the trainee's own write; `trainees` (assignment) stays the
admin's.

### Why store **session ids** (not course ids) in `assigned_sessions`

Each entry is exactly **one session** = exactly one thing on the Home screen, so
the reverse link stays correct with no guesswork:

- **Assign** → `arrayUnion(sessionId)`.
- **Unassign / delete** → `arrayRemove(sessionId)`.

If we had stored **course** ids instead, removal would be ambiguous — a course
has many sessions, so leaving one session wouldn't tell us whether to drop the
course (the trainee might still be in another session of it). Storing session
ids sidesteps that whole class of bug. (Displaying sessions rather than courses
also means the Home needs no extra course-resolution hop.)

---

## 3. Write path — assignment happens on the **session**

Assignment was moved **out of the appointment dialog and onto the session**
(create *and* edit). Appointments are now pure logistics (date + location).

- **Dialog** [course_admin_dialogs.dart](../../lib/courses/ui/course_admin_dialogs.dart):
  `showSessionDialog` collects name + description + **assigned trainee ids**
  (comma-separated ints), reused for add and edit (pre-filled). The appointment
  dialog no longer has an "assign" field.
- **Repository** [course_repository.dart](../../lib/courses/data/course_repository.dart):
  - `addSession(...)` writes `trainees`, inherits `created_by` /
    `created_by_email` from the repo's creator scope, then calls
    `_addSessionToTrainees`.
  - `editSession(...)` diffs old vs new trainees and applies the delta:
    `_addSessionToTrainees(added)` + `_removeSessionFromTrainees(removed)`.
  - `deleteSession` / `deleteCourse` unlink the session from its trainees before
    deleting.
  - `_addSessionToTrainees` / `_removeSessionFromTrainees` maintain
    `users/{id}.assigned_sessions` via `arrayUnion` / `arrayRemove`. **They skip
    ids with no matching `users` doc**, so a typo'd id can't create a phantom
    user.
- **Cubit** [courses_cubit.dart](../../lib/courses/cubit/courses_cubit.dart):
  `addSession` / `editSession` gained a `trainees` param; the appointment
  delegates dropped `instructorIds`.
- **UI** [course_expansion_tile.dart](../../lib/courses/ui/course_expansion_tile.dart):
  the session body shows an **"Assigned trainees"** chip roster (from
  `session.trainees`); the "Add appointment & assign" button is now just "Add
  appointment".

> An admin's int id when typed in the dialog is the trainee's `users` doc id —
> so the write is a direct `users.doc('1111')`, no lookup needed.

---

## 4. Read path — the trainee Home (`lib/user/`)

```
lib/user/
  models/assigned_session.dart   # AssignedSession { session, courseTitle } + MySessions { traineeId, sessions }
  data/user_repository.dart      # sessions read · appointments read · enroll / unenroll writes
  cubit/my_sessions_cubit.dart   # one-shot load by email; { sessions, traineeId, loading, error }
  ui/my_sessions_body.dart       # the Home cards: expand → appointments → Enroll / Enrolled
```

- [user_repository.dart](../../lib/user/data/user_repository.dart)
  `loadAssignedSessions(email)`:
  1. `users where email == <email>` (limit 1) → read `assigned_sessions`. The
     email is **lower-cased + trimmed** first (matching `AuthCubit._resolveRole`),
     because the Firebase login email can come back in a different case than the
     hand-typed `users.email` and Firestore equality is case-sensitive.
  2. Capture the matched **`users` doc id as the trainee's int id** (the
     `traineeId`) — needed for the enroll write. Falls back to the doc's `id`
     field if the id isn't numeric.
  3. Parse `assigned_sessions` **defensively** — each element is coerced with
     `toString()`, so an id stored as a number still resolves (a session doc id
     is always a string like `"9876543210"`).
  4. Fetch each session doc (skipping ids that no longer exist).
  5. Fetch each **distinct** parent course once for its display `title`.
  6. Returns `MySessions { traineeId, sessions }` — the sessions sorted by course
     title then session `order`.
- [my_sessions_cubit.dart](../../lib/user/cubit/my_sessions_cubit.dart) is a
  **one-shot load** (not a live stream); call `refresh()` to reload. It also
  holds the resolved `traineeId` in state and exposes `loadAppointments`,
  `enroll`, and `unenroll` (the last two no-op when `traineeId` is null).
- [my_sessions_body.dart](../../lib/user/ui/my_sessions_body.dart) renders one
  **expandable card** per session (course label · session name · description).
  Expanding lazily loads that session's appointments and shows each with an
  **Enroll** pill that flips to **Enrolled** (tap to leave) — see §4.1.

### 4.1 Enrollment write-path

Appointment enrollment mirrors the existing instructor pattern: each appointment
doc carries an `enrolled_trainees` int array. Reached only **through** an
assigned session, so there is **no reverse link** on the `users` doc (nothing to
scan — unlike `assigned_sessions`).

- [appointment.dart](../../lib/courses/models/appointment.dart) parses
  `enrolledTraineeIds` from `enrolled_trainees` (additive; the admin side is
  untouched).
- `UserRepository.loadAppointments(sessionId)` reads the session's
  `appointments` sub-collection (skipping the singular `assigned_instructor`
  doc), sorted by date then id.
- `UserRepository.enroll(sessionId, appointmentId, traineeId)` is **exclusive**:
  a single **batched** write that `arrayRemove`s the trainee from every *other*
  appointment of the session and `arrayUnion`s them into the chosen one — so the
  "one appointment per session" rule is enforced atomically (no transient state
  where they're in two, or in none).
- `UserRepository.unenroll(...)` is a plain `arrayRemove` on that one
  appointment.
- After either write the UI **reloads that session's appointments**, so the
  Enroll/Enrolled pills reflect the new state (one-shot, like the Home list —
  not a live stream).

### Wiring

- [user_home.dart](../../lib/user/user_home.dart) provides
  `MySessionsCubit(email: user.email)` alongside the existing cubits.
- [home_screen.dart](../../lib/ui/screens/home_screen.dart) renders
  `MySessionsBody` under a **"My sessions"** header (was "My courses" /
  `CoursesListBody`).

---

## 5. End-to-end

1. Admin02 signs in → **Courses** tab (scoped to courses they created).
2. Expand a course → **Add session** → type name, description, and trainee ids
   `1111, 222` → Save.
   - `sessions/{id}` is written with `trainees: [1111, 222]` + inherited
     `created_by(_email)`.
   - `users/1111` and `users/222` each get the new session id appended to
     `assigned_sessions`.
3. Trainee `ali@nahdi.sa` (doc `users/1111`) opens the app → Home →
   `users where email == ali@nahdi.sa` → `assigned_sessions` → that session is
   fetched and shown under its course's name (and `traineeId = 1111` is captured).
4. Ali **expands** the session card → its appointments load → he taps **Enroll**
   on `appointment2`. The batched write removes `1111` from every other
   appointment's `enrolled_trainees` and adds it to `appointment2` → the pill
   becomes **Enrolled**. Tapping it again (or Enroll on a different appointment)
   moves/clears him.
5. Later, removing `1111` from the session (edit) or deleting the session pulls
   that session id back out of `users/1111.assigned_sessions`, so it disappears
   from Ali's Home.

---

## 6. Logging

All paths log via `logCourse` (`[COURSE]` tag, debug builds only). The session
write logs the trainees and each `users/{id} +=/-= session` link. The Home read
(`loadAssignedSessions`) logs a full trace, the first stop when "the Home is
empty":

```
loadAssignedSessions → users where email == "ali@nahdi.sa"
  ✓ matched users/1111 → fields: { email, id, assigned_sessions, … }
  assigned_sessions raw = [ … ] (runtimeType: …)
  assigned_sessions parsed ids = [ "9876543210", … ]
  fetch /sessions/9876543210 → exists=true
    session "9876543210" fields: { … }
  resolved N assigned session(s) for "…"
```

Reading the trace:

- **`✗ no users doc matched email "…"`** → email lookup failed; the login email
  doesn't match any `users.email` (check case / duplicates — see Limitations).
- **`✓ matched users/…`** but no/empty `assigned_sessions` → nothing was assigned
  (or it was written to a different doc).
- **`fetch /sessions/… → exists=false`** → the user + array are fine but the id
  doesn't resolve to a real session doc (id mismatch).
- **A `[ERROR] MySessionsCubit.refresh` line** → a Firestore exception (e.g. a
  security rule blocking the read), not an empty result.

---

## 7. Limitations & next steps

- **A login email must be unique across `admins` and `users`.** Role resolution
  (`AuthCubit._resolveRole`) checks `admins` **first**, so an email present in
  *both* collections signs the person in as an admin (admin01/admin02) and routes
  them to the **admin shell** — the trainee `UserHome` (and this whole feature)
  never renders. Symptom: assignment is written correctly to
  `users/{id}.assigned_sessions` but the trainee Home is empty. There's no guard
  preventing the duplicate yet; first thing to check when "the Home shows
  nothing" is whether the email is also in `admins`.
- **Home reload is manual.** `MySessionsCubit` loads once on entry (not a live
  stream). New assignments appear after a reopen / `refresh()`. A snapshot
  listener on the `users` doc would make it live. (Appointment lists reload
  per-card after each enroll/leave, but likewise aren't live.)
- **Enrollment has no capacity cap and isn't validated server-side.** Any number
  of trainees can sit in one appointment; the "one appointment per session" rule
  is enforced **client-side** by the exclusive batched write, so a hand-edited or
  concurrent write could leave a trainee in two. A seats limit or a Cloud
  Function / security rule would harden this.
- **Enrolling doesn't require being assigned.** The Enroll button only renders
  for sessions on Home (which already come from `assigned_sessions`), but the
  `enroll` write itself doesn't re-check `session.trainees`, so it relies on the
  read-path gating. Security rules should enforce "enrolled ⟹ assigned" later.
- **Courses & Schedule tabs are still unfiltered** — they use the unscoped
  `CoursesCubit` and show every course. Only **Home** is per-trainee so far.
- **No `users` provisioning here.** Trainee docs are assumed to exist (created in
  the Firebase console). Assignment **skips** unknown ids rather than creating
  stubs.
- **Client-side only / no security rules.** Anyone could read other `users` docs
  or sessions until Firestore rules lock this down. The trainee int id ↔ login
  link relies on the `email` field matching the sign-in email.
- **Cascade writes run client-side** (per-trainee `get` + `update` loops). For
  large rosters or interrupted writes, a Cloud Function is the eventual robust
  home.
- **Legacy `assigned_instructor` docs** under old sessions are no longer written
  or displayed; `CourseRepository.loadSession` still defensively filters them out
  of the appointment list.
