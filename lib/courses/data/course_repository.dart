import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../models/appointment.dart';
import '../models/course.dart';
import '../models/session_detail.dart';

/// Firestore access for the `courses` feature.
///
/// Model: `courses/{courseId}` (fields `title`, `course_id`) holds only the
/// course itself. **Sessions live in a top-level `sessions` collection** linked
/// back to a course by a `course_id` field (= the course document id). Each
/// session doc id is its generated 10-digit `session_id`; fields are `course_id`,
/// `name`, `description`, `session_id`, `order`. A session's `appointments`
/// sub-collection nests under it (`sessions/{sessionId}/appointments/{id}`),
/// alongside a singular `assigned_instructor` doc holding the `assign_to` roster.
///
/// Flattening sessions keeps paths short and lets the web client query a
/// course's sessions directly (`where('course_id', …)`) instead of walking a
/// nested sub-collection. Cascade deletes query the `sessions` collection by
/// `course_id` rather than enumerating a sub-collection.
///
/// Note: a course document that holds *only* sub-collections (no top-level
/// fields) is a "phantom" parent and will not appear in this listing. Give each
/// course document at least a `title` field so it surfaces here.
class CourseRepository {
  CourseRepository({
    FirebaseFirestore? firestore,
    this.creatorId,
    this.creatorEmail,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// When set, the repository is scoped to one author: [watch] returns only
  /// courses whose `created_by` matches, and [addCourse] stamps `created_by` /
  /// `created_by_email`. Null means unscoped (the trainee view sees every
  /// course).
  final String? creatorId;
  final String? creatorEmail;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('courses');

  /// Top-level `sessions` collection (linked to a course by `course_id`).
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  /// Trainee directory. A trainee doc id is the trainee's int id (as a string);
  /// fields include `email`, `name`, `id`, and the `assigned_sessions` array
  /// (the reverse link maintained from session assignments — see
  /// [_addSessionToTrainees] / [_removeSessionFromTrainees]).
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static final _rng = Random();

  /// A random 10-digit positive integer (1_000_000_000 .. 9_999_999_999), used
  /// as the stable `course_id` / `session_id` / `appointment_id`. Built digit
  /// by digit because the range exceeds `Random.nextInt`'s 2^32 limit.
  static int _newId() {
    final buf = StringBuffer(1 + _rng.nextInt(9)); // first digit 1-9
    for (var i = 0; i < 9; i++) {
      buf.write(_rng.nextInt(10));
    }
    return int.parse(buf.toString());
  }

  /// A session's nested `appointments` sub-collection. A session is reachable by
  /// its own id alone now, so no `courseId` is needed.
  CollectionReference<Map<String, dynamic>> _appointments(String sessionId) =>
      _sessions.doc(sessionId).collection('appointments');

  /// Live list of course documents (title + `course_id` only — sessions are
  /// loaded on demand via [loadSessions]). When [creatorId] is set, only courses
  /// created by that admin are returned (`where created_by == creatorId`).
  Stream<List<Course>> watch() {
    Query<Map<String, dynamic>> query = _col;
    if (creatorId != null) {
      logCourse('watch scoped to created_by == "$creatorId"');
      query = query.where('created_by', isEqualTo: creatorId);
    }
    return query.snapshots().map((snap) {
        logCourse('courses collection → ${snap.docs.length} document(s)');
        return snap.docs.map((doc) {
          logCourse('  course "${doc.id}" fields: ${doc.data()}');
          final course = Course.fromDoc(doc);
          logCourse(
            '    parsed → title="${course.title}", course_id=${course.courseId}',
          );
          return course;
        }).toList();
      });
  }

  /// Loads a course's sessions from the top-level `sessions` collection
  /// (`where course_id == courseId`), sorted by `order` then name. Sorting is
  /// done client-side so no composite index is needed.
  Future<List<CourseSession>> loadSessions(String courseId) async {
    logCourse('loadSessions → /sessions where course_id == "$courseId"');
    final snap =
        await _sessions.where('course_id', isEqualTo: courseId).get();
    logCourse('  ${snap.docs.length} session(s) in "$courseId"');
    final sessions = <CourseSession>[];
    for (final doc in snap.docs) {
      logCourse('  session "${doc.id}" fields: ${doc.data()}');
      sessions.add(CourseSession.fromDoc(doc));
    }
    sessions.sort((a, b) =>
        a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
    return sessions;
  }

  /// Loads one session's `appointments` sub-collection
  /// (`/sessions/{sessionId}/appointments`): every appointment document plus the
  /// instructor ids from the singular `assigned_instructor` doc (filtered out of the
  /// appointment list).
  Future<SessionDetail> loadSession(String sessionId) async {
    logCourse('loadSession → /sessions/$sessionId/appointments');
    final snap = await _appointments(sessionId).get();
    logCourse('  ${snap.docs.length} document(s) in session "$sessionId"');

    final appointments = <Appointment>[];
    var assignedInstructorIds = const <int>[];

    for (final doc in snap.docs) {
      logCourse('  doc "${doc.id}" fields: ${doc.data()}');
      // The instructors doc is named `assigned_instructor` (accept the plural too).
      if (doc.id == 'assigned_instructor' || doc.id == 'assigned_instructors') {
        final raw = (doc.data()['assign_to'] ?? const []) as List;
        assignedInstructorIds =
            raw.whereType<num>().map((n) => n.toInt()).toList();
        logCourse('    → assigned instructor ids: $assignedInstructorIds');
      } else {
        final appointment = Appointment.fromDoc(doc);
        logCourse(
          '    → appointment "${appointment.id}": date="${appointment.date}", '
          'enrolled_instructor=${appointment.enrolledInstructorIds}, '
          'location="${appointment.location}"',
        );
        appointments.add(appointment);
      }
    }

    appointments.sort((a, b) => a.id.compareTo(b.id));
    logCourse(
      '  session "$sessionId" summary → '
      '${appointments.length} appointment(s), '
      '${assignedInstructorIds.length} instructor(s)',
    );
    return SessionDetail(
      appointments: appointments,
      assignedInstructorIds: assignedInstructorIds,
    );
  }

  // --- Admin writes ------------------------------------------------------

  /// Creates a course document. The id (and `title`) is [name]; the `title`
  /// field guarantees the doc surfaces in collection queries. Merges so an
  /// existing course isn't wiped.
  Future<void> addCourse(String name) async {
    final id = name.trim();
    final courseId = _newId();
    logCourse('addCourse → "$id" (course_id=$courseId, created_by=$creatorId)');
    await _col.doc(id).set({
      'title': id,
      'course_id': courseId,
      if (creatorId != null) 'created_by': creatorId,
      if (creatorEmail != null) 'created_by_email': creatorEmail,
    }, SetOptions(merge: true));
  }

  /// Adds a session document to the top-level `sessions` collection, linked to
  /// [courseId] via the `course_id` field. The doc id is the generated 10-digit
  /// `session_id` (names can repeat across courses, so the name is a field, not
  /// the id); [order] is the 1-based position used to sort the list.
  ///
  /// The session inherits `created_by` / `created_by_email` from the repository's
  /// creator scope (the admin authoring it). The assigned [trainees] are stored
  /// on the session **and** mirrored into each trainee's `users` doc
  /// (`assigned_sessions`) so the trainee home can read its sessions cheaply.
  Future<void> addSession(
    String courseId, {
    required String name,
    required String description,
    required int order,
    List<int> trainees = const [],
  }) async {
    final cleanName = name.trim();
    final sessionId = _newId();
    logCourse(
        'addSession → /sessions/$sessionId (course_id="$courseId", name="$cleanName", trainees=$trainees)');
    await _sessions.doc(sessionId.toString()).set({
      'course_id': courseId,
      'name': cleanName,
      'description': description,
      'session_id': sessionId,
      'order': order,
      'trainees': trainees,
      if (creatorId != null) 'created_by': creatorId,
      if (creatorEmail != null) 'created_by_email': creatorEmail,
    }, SetOptions(merge: true));
    await _addSessionToTrainees(sessionId.toString(), trainees);
  }

  /// Creates an `appointment{N}` doc in a session's `appointments`
  /// sub-collection. Appointments are pure logistics (date + location) — trainee
  /// assignment lives on the session, not here.
  Future<void> addAppointment(
    String sessionId, {
    required DateTime date,
    required String location,
  }) async {
    final col = _appointments(sessionId);
    final existing = await col.get();
    final count =
        existing.docs.where((d) => d.id.startsWith('appointment')).length;
    final apptId = 'appointment${count + 1}';
    final appointmentId = _newId();

    logCourse(
        'addAppointment → /sessions/$sessionId/appointments/$apptId (appointment_id=$appointmentId)');
    await col.doc(apptId).set({
      'date': Timestamp.fromDate(date),
      'location': location.trim(),
      'appointment_id': appointmentId,
    });
  }

  // --- Admin edits / deletes ---------------------------------------------

  /// Updates a course's display `title` (the doc id is fixed).
  Future<void> editCourse(String courseId, {required String title}) {
    logCourse('editCourse → /courses/$courseId title="$title"');
    return _col.doc(courseId).set({'title': title.trim()}, SetOptions(merge: true));
  }

  /// Deletes a course: finds its sessions in the top-level `sessions` collection
  /// (`where course_id == courseId`), clears each session's appointments, unlinks
  /// it from its trainees, deletes the session doc, then deletes the course doc.
  Future<void> deleteCourse(String courseId) async {
    logCourse('deleteCourse → /courses/$courseId (+ its sessions)');
    final sessions =
        await _sessions.where('course_id', isEqualTo: courseId).get();
    for (final session in sessions.docs) {
      final trainees = CourseSession.fromDoc(session).trainees;
      await _removeSessionFromTrainees(session.id, trainees);
      await _deleteSubcollection(session.reference.collection('appointments'));
      await session.reference.delete();
    }
    await _col.doc(courseId).delete();
  }

  /// Updates a session's editable fields (`name`, `description`, `trainees`). The
  /// session doc id ([sessionId]) is fixed — only the values change. Trainee
  /// changes are reconciled against the trainees' `users` docs: newly-added
  /// trainees get the session id, removed ones lose it (a clean 1-to-1 sync
  /// because the reverse link stores session ids, not course ids).
  Future<void> editSession(
    String sessionId, {
    required String name,
    required String description,
    required List<int> trainees,
  }) async {
    logCourse('editSession → /sessions/$sessionId (trainees=$trainees)');
    final before = await _sessions.doc(sessionId).get();
    final oldTrainees =
        before.exists ? CourseSession.fromDoc(before).trainees : const <int>[];

    await _sessions.doc(sessionId).update({
      'name': name.trim(),
      'description': description,
      'trainees': trainees,
    });

    final added = trainees.where((t) => !oldTrainees.contains(t)).toList();
    final removed = oldTrainees.where((t) => !trainees.contains(t)).toList();
    await _addSessionToTrainees(sessionId, added);
    await _removeSessionFromTrainees(sessionId, removed);
  }

  /// Deletes a session: unlinks it from its trainees, clears its `appointments`
  /// sub-collection, then deletes the session doc.
  Future<void> deleteSession(String sessionId) async {
    logCourse('deleteSession → /sessions/$sessionId');
    final snap = await _sessions.doc(sessionId).get();
    final trainees =
        snap.exists ? CourseSession.fromDoc(snap).trainees : const <int>[];
    await _removeSessionFromTrainees(sessionId, trainees);
    await _deleteSubcollection(_appointments(sessionId));
    await _sessions.doc(sessionId).delete();
  }

  /// Updates an appointment's `date` / `location` (logistics only).
  Future<void> editAppointment(
    String sessionId,
    String appointmentId, {
    required DateTime date,
    required String location,
  }) async {
    final col = _appointments(sessionId);
    logCourse(
        'editAppointment → /sessions/$sessionId/appointments/$appointmentId');
    await col.doc(appointmentId).set({
      'date': Timestamp.fromDate(date),
      'location': location.trim(),
    }, SetOptions(merge: true));
  }

  /// Deletes a single appointment document.
  Future<void> deleteAppointment(String sessionId, String appointmentId) {
    logCourse(
        'deleteAppointment → /sessions/$sessionId/appointments/$appointmentId');
    return _appointments(sessionId).doc(appointmentId).delete();
  }

  // --- Trainee reverse-link sync (`users.assigned_sessions`) --------------

  /// Adds [sessionId] to each trainee's `assigned_sessions` array. Skips ids
  /// with no matching `users` doc (so a typo'd id can't create a phantom user).
  Future<void> _addSessionToTrainees(
    String sessionId,
    List<int> traineeIds,
  ) async {
    for (final id in traineeIds) {
      final ref = _users.doc(id.toString());
      final snap = await ref.get();
      if (!snap.exists) {
        logCourse('  ⚠ users/$id not found — skipping assign of $sessionId');
        continue;
      }
      logCourse('  link users/$id += session $sessionId');
      await ref.update({
        'assigned_sessions': FieldValue.arrayUnion([sessionId]),
      });
    }
  }

  /// Removes [sessionId] from each trainee's `assigned_sessions` array. Because
  /// the array stores session ids (not course ids), removal is unambiguous — no
  /// "are they still in another session of this course?" recompute is needed.
  Future<void> _removeSessionFromTrainees(
    String sessionId,
    List<int> traineeIds,
  ) async {
    for (final id in traineeIds) {
      final ref = _users.doc(id.toString());
      final snap = await ref.get();
      if (!snap.exists) continue;
      logCourse('  unlink users/$id -= session $sessionId');
      await ref.update({
        'assigned_sessions': FieldValue.arrayRemove([sessionId]),
      });
    }
  }

  /// Deletes every document in a sub-collection (batched).
  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snap = await col.get();
    if (snap.docs.isEmpty) return;
    final batch = col.firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
