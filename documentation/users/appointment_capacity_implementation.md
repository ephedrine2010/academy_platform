# Appointment Capacity — Implementation

**Last updated:** 2026-07-08

How an **appointment can cap how many trainees self-enroll**: the optional
`capacity` field, the single service that owns the rule, where the UI gates the
**Enroll** button, and the backstop check on the write path. Builds directly on
the enrollment flow in
[trainee_home_implementation.md](trainee_home_implementation.md).

> Scope: an admin sets a **max capacity** when adding/editing an appointment
> (blank = unlimited). Trainees see **"N seats left" / "Full"** and can't enroll
> into a full appointment; an already-enrolled trainee can still **leave** (which
> frees a seat). Enforcement is a plain read-then-compare, **not** a transaction
> — see [Trade-off](#5-the-race-trade-off).

---

## 1. The idea in one line

An appointment stores an optional `capacity`; the number **already** enrolled is
just `enrolled_trainees.length`. "Full" = `capacity != null && length >= capacity`.
There is **no separate counter** — the enrolled-trainees array *is* the count.

```
sessions/{id}/appointments/appointment1
  date:     <Timestamp>
  location: "voco hotel"
  capacity: 10                       ← optional; absent/blank = unlimited
  enrolled_trainees: [1111, 2222]    ← who is in; .length (= 2) is HOW MANY
```

---

## 2. Firestore data model (additive)

One optional field on the existing appointment doc — nothing else changes.

| Field | Type | Meaning |
|---|---|---|
| `capacity` | `int?` | Max trainees allowed to self-enroll. **Absent = unlimited.** |

- Parsed by [appointment.dart](../../lib/courses/models/appointment.dart) into
  `Appointment.capacity` (`(data['capacity'] as num?)?.toInt()`).
- **Legacy appointments have no `capacity`** → they read as unlimited, so nothing
  needs backfilling.
- On **edit**, clearing the field writes `FieldValue.delete()` (back to
  unlimited) rather than `0`.

---

## 3. One place owns the rule — `EnrollmentCapacityService`

All capacity logic lives in
[lib/user/services/enrollment_capacity_service.dart](../../lib/user/services/enrollment_capacity_service.dart)
so the rule is maintained in a single file:

| Member | Kind | Used by |
|---|---|---|
| `isFull(Appointment a)` | pure | UI — gate the button, colour the label |
| `remainingSeats(Appointment a)` | pure | UI — "N seats left" |
| `ensureHasSeat(sessionId, appointmentId)` | **reads Firestore** | repo — live check before the enroll write |
| `AppointmentFullException` | — | thrown by `ensureHasSeat`; the UI shows its message |

```dart
bool isFull(Appointment a) {
  final cap = a.capacity;
  return cap != null && a.enrolledTraineeIds.length >= cap;
  //                    └─ the number already enrolled
}

Future<void> ensureHasSeat(String sessionId, String appointmentId) async {
  final doc = await _db
      .collection('sessions').doc(sessionId)
      .collection('appointments').doc(appointmentId)
      .get();                                    // ← the only Firebase read
  if (doc.exists && isFull(Appointment.fromDoc(doc))) {
    throw const AppointmentFullException();
  }
}
```

**Why the pure helpers *and* a reading method:** the UI already holds a loaded
`Appointment`, so it does the math locally (no query) to draw the button. The
repo needs the **fresh** count at the instant of writing, so it re-reads. Both
paths share the same `isFull` definition.

> The constructor is `const EnrollmentCapacityService({FirebaseFirestore? db})`
> — `db` defaults to `FirebaseFirestore.instance`, resolved **lazily** inside
> `ensureHasSeat`. So the UI's `const EnrollmentCapacityService()` uses the pure
> helpers **without** touching Firebase, and tests can inject a fake `db`.

---

## 4. Data flow

### Admin authoring (set the cap)

`_AppointmentDialog`
([course_admin_dialogs.dart](../../lib/courses/ui/course_admin_dialogs.dart)) has
a **"Max capacity"** field ("leave blank for unlimited"). Blank / `0` / negative
/ non-numeric → `null`. The value threads through
`NewAppointment.capacity` → `CoursesCubit` →
`CourseRepository.addAppointment` / `editAppointment`, which writes
`if (capacity != null) 'capacity': capacity` (add) or
`'capacity': capacity ?? FieldValue.delete()` (edit).

The admin appointment row shows **"3 / 10 enrolled"** when capped (read straight
off already-loaded data — no extra query).

### Trainee enroll (respect the cap)

[my_sessions_body.dart](../../lib/user/ui/my_sessions_body.dart) `_AppointmentRow`:

```
loaded Appointment ──► EnrollmentCapacityService (pure)
                       ├─ remainingSeats → "3 seats left" / "Full" (red)
                       └─ isFull         → button state
```

- **Not full** → normal **Enroll** button.
- **Full and not enrolled** → disabled **"Full"** pill (button `onPressed: null`).
- **Already enrolled** → **"Enrolled"** button stays active → tapping **leaves**
  (only the *enroll* action is blocked, never *unenroll*), which frees a seat.

Tapping Enroll → `MySessionsCubit.enroll` → `UserRepository.enroll`, which calls
`ensureHasSeat` **before** the batch write:

```dart
await const EnrollmentCapacityService().ensureHasSeat(sessionId, appointmentId);
// ...then the existing exclusive-per-session batch (arrayUnion target,
//    arrayRemove every other appointment of the session).
```

If it throws, the error surfaces as a snackbar in `_AppointmentRow._toggle`.

---

## 5. The race trade-off

The guard is **read-then-write, not a transaction**. Two trainees looking at the
same "9 / 10" screen can both pass `ensureHasSeat` and both commit → the
appointment lands at 11. This is **accepted** (real rooms have slack), matching
the "client-side only, no security rules yet" posture of the rest of the app.

Two independent softeners already reduce it:
1. The **UI** disables the button the moment a loaded appointment reads full.
2. `ensureHasSeat` re-reads the **live** count right before writing, so a
   trainee acting on a stale screen is still usually caught.

**If it ever needs to be strict:** wrap `ensureHasSeat` + the enroll write in a
single `runTransaction` (re-read the appointment inside the transaction, check
`isFull`, then commit). That is the *only* change — the rule itself already lives
in one place.

---

## 6. Files touched

| File | Change |
|---|---|
| [lib/user/services/enrollment_capacity_service.dart](../../lib/user/services/enrollment_capacity_service.dart) | **New** — owns `isFull` / `remainingSeats` / `ensureHasSeat` + `AppointmentFullException` |
| [lib/courses/models/appointment.dart](../../lib/courses/models/appointment.dart) | `int? capacity` field (parse / `copyWith` / `props`) |
| [lib/courses/ui/course_admin_dialogs.dart](../../lib/courses/ui/course_admin_dialogs.dart) | "Max capacity" field; `NewAppointment.capacity` |
| [lib/courses/data/course_repository.dart](../../lib/courses/data/course_repository.dart) | write `capacity` in `addAppointment` / `editAppointment` |
| [lib/courses/cubit/courses_cubit.dart](../../lib/courses/cubit/courses_cubit.dart) | thread `capacity` through the delegates |
| [lib/courses/ui/course_expansion_tile.dart](../../lib/courses/ui/course_expansion_tile.dart) | pass `capacity`; admin "3 / 10 enrolled" subtitle |
| [lib/user/data/user_repository.dart](../../lib/user/data/user_repository.dart) | `enroll` calls `ensureHasSeat` before the batch |
| [lib/user/ui/my_sessions_body.dart](../../lib/user/ui/my_sessions_body.dart) | "seats left" / "Full" pill; button gating |

---

## 7. Limitations & next steps

- **Not transactional** — can overshoot by one or two (see
  [§5](#5-the-race-trade-off)).
- **No security rules** — a client could still write `enrolled_trainees` past the
  cap directly; enforce with Firestore rules / a Cloud Function later.
- **Waitlist** — none. A full appointment just blocks; the trainee picks another.
- **Extra read** — `ensureHasSeat` reads the target appointment separately from
  the batch's `get()` of all appointments (one small doc read per enroll). Folded
  into one read only if it ever matters.
