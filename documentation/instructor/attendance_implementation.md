# Instructor: Today's Appointments & Attendance

**Last updated:** 2026-06-30

How an instructor (`admin02`) records trainee attendance for an appointment.
Covers the new **instructor Home ("Today") tab**, the **geofence arming** flow,
and the **attendance roster** with manual mark / revoke. Lives under
[lib/instructor/](../../lib/instructor/).

> Scope of this slice: the **instructor side** is built — find today's
> appointments, arm a geofence + check-in window, and mark trainees present (or
> revoke). The **trainee self check-in** (reading device GPS, comparing to the
> geofence within the window, writing a `location` record) is **not built yet** —
> see [Next steps](#next-steps).

---

## 1. The two-tier attendance model

A trainee's attendance for an appointment is confirmed one of two ways:

1. **Self check-in (location)** — the trainee taps "I'm here"; if they are inside
   the geofence **and** within the check-in window, a record is written with
   `method: location`. *(Trainee side — not built yet.)*
2. **Instructor confirm (fallback / override)** — the instructor marks anyone
   present from the roster (`method: instructor`). This catches everyone location
   couldn't auto-confirm (denied GPS, indoors, desktop web where geolocation is
   unreliable) and lets the instructor **revoke** a spoofed self check-in.

The instructor is always the authority; location just auto-handles the easy
majority. **Attendance is closed until the instructor arms it** (sets the
geofence) — that write is what opens self check-in.

---

## 2. Firestore data model (additive)

Geofence config is stored **on the appointment doc**; attendance records live in
a nested `attendance` sub-collection keyed by trainee id.

```
sessions/{id}/appointments/{appt}
  ... existing: date, location, appointment_id, enrolled_trainees ...
  geo_lat, geo_lng           # geofence centre (pasted from Google Maps)
  geo_radius_m               # geofence radius in metres (default 200)
  window_hours               # self check-in allowed: date → date + window_hours
  attendance_opened_at       # set when armed → the "open" signal

sessions/{id}/appointments/{appt}/attendance/{traineeId}
  trainee_id: 1111
  method:     "location" | "instructor"
  marked_by:  "<instructor uid>"   # only for method == instructor
  at:         <serverTimestamp>
```

A record's **existence** = the trainee is confirmed present; `method` says how.
Absent id = not yet confirmed. No-show (future) = appointment time passed with no
record.

Parsed by [appointment.dart](../../lib/courses/models/appointment.dart) (new
fields + `attendanceOpen` getter + `copyWith`) and
[attendance_record.dart](../../lib/instructor/models/attendance_record.dart).

---

## 3. Finding "today's appointments" — the walk

Appointments are nested under sessions and carry **no owner field**, so they
can't be scoped in a single query. [instructor_repository.dart](../../lib/instructor/data/instructor_repository.dart)
`loadTodayAppointments` **walks** the ownership chain instead:

```
courses where created_by == <instructor uid>
  → sessions where course_id == course.id
    → appointments where date in [todayStart, todayEnd)
```

The date filter is a **range on a single field** (no composite index; docs with
no `date`, like the legacy `assigned_instructor` doc, are naturally excluded).
Each result is wrapped in a `TodayAppointment` (appointment + sessionId +
sessionName + courseTitle) for display. Chosen over a `collectionGroup` query to
avoid an index + having to backfill `created_by` onto every appointment.

---

## 4. UI

```
lib/instructor/
  models/today_appointment.dart   # appointment + session/course labels
  models/attendance_record.dart   # AttendanceRecord + AttendanceMethod
  data/instructor_repository.dart  # walk · arm · loadAttendance · mark · revoke
  data/latlng_parser.dart          # "lat, lng" / @lat,lng-from-URL → LatLng
  cubit/instructor_home_cubit.dart # one-shot load of today's appointments
  cubit/attendance_cubit.dart      # per-appointment: profiles + records + writes
  ui/instructor_home_page.dart     # "Today" tab: carousel of appointment cards
  ui/attendance_page.dart          # arm geofence + roster
  ui/attendance_table.dart         # material_table_view roster + mark/revoke
```

- **Today tab** ([app_shell.dart](../../lib/shell/app_shell.dart)): added for
  `AppRole.instructor` only (managers keep Dashboard/Regions/Instructors). A
  horizontal carousel of cards — course · session · time · location · enrolled
  count, with a **"Check-in open" / "Not armed"** pill. Tapping opens attendance.
- **Attendance page**: a header card, the **geofence panel** (paste
  `lat, lng` + radius + window hours; "Arm" → writes config & opens self
  check-in; re-arming shows "Update" + an "Open" badge), then the roster.
- **Roster** ([attendance_table.dart](../../lib/instructor/ui/attendance_table.dart)):
  `material_table_view` of enrolled trainees (profiles still mocked via
  `TraineeDirectory`) with a **Status** column — `Self-confirmed` / `Confirmed by
  you` / `Not yet` — and a per-row **Mark** / **Revoke** action.

---

## 5. Coordinate input

[latlng_parser.dart](../../lib/instructor/data/latlng_parser.dart) accepts a bare
`lat, lng` pair (right-click the venue in Google Maps → click the coordinates to
copy) **or** an `@lat,lng` segment from a desktop Maps URL. Short share links
(`maps.app.goo.gl/…`) are **not** supported — they carry no coordinates in the
text and would need a network redirect.

---

## Next steps

- **Trainee self check-in** (the `location` path) — needs a geolocation package
  (`geolocator`) + platform permissions, then a trainee-side write that validates
  device position against `geo_lat/lng/geo_radius_m` and `dateTime → +window_hours`
  before writing a `method: location` record. On web (primary target) GPS is
  unreliable, so in practice many trainees will fall to the instructor fallback —
  which is by design.
- **No-show derivation** — appointment time passed with no record.
- **Trainee profiles are mocked** (`TraineeDirectory`) — swap for the staff API.
- **Client-side only / no security rules** — same caveat as the rest of the app;
  "enrolled ⟹ attended", capacity, and "only the owning instructor can arm" should
  be enforced by Firestore rules / a Cloud Function later.
