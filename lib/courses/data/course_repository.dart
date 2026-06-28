import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../models/appointment.dart';
import '../models/course.dart';
import '../models/session_detail.dart';

/// Firestore access for the `courses` collection.
///
/// Model: `courses/{courseId}` (fields `title`, `course_id`) →
/// `sessions/{sessionId}` sub-collection (fields `name`, `description`,
/// `session_id`, `order`) → `appointments/{id}` sub-collection (appointment docs
/// plus a singular `assigned_trainer` doc holding the `assign_to` roster).
///
/// Note: a course document that holds *only* sub-collections (no top-level
/// fields) is a "phantom" parent and will not appear in this listing. Give each
/// course document at least a `title` field so it surfaces here.
class CourseRepository {
  CourseRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('courses');

  final CollectionReference<Map<String, dynamic>> _col;

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

  

  CollectionReference<Map<String, dynamic>> _sessions(String courseId) =>
      _col.doc(courseId).collection('sessions');

  CollectionReference<Map<String, dynamic>> _appointments(
    String courseId,
    String sessionId,
  ) =>
      _sessions(courseId).doc(sessionId).collection('appointments');

  /// Live list of course documents (title + `course_id` only — sessions are
  /// loaded on demand via [loadSessions]).
  Stream<List<Course>> watch() => _col.snapshots().map((snap) {
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

  /// Loads a course's `sessions` sub-collection, sorted by `order` then name.
  Future<List<CourseSession>> loadSessions(String courseId) async {
    logCourse('loadSessions → /courses/$courseId/sessions');
    final snap = await _sessions(courseId).get();
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
  /// (`/courses/{courseId}/sessions/{sessionId}/appointments`): every
  /// appointment document plus the trainer ids from the singular
  /// `assigned_trainer` doc (filtered out of the appointment list).
  Future<SessionDetail> loadSession(String courseId, String sessionId) async {
    logCourse('loadSession → /courses/$courseId/sessions/$sessionId/appointments');
    final snap = await _appointments(courseId, sessionId).get();
    logCourse('  ${snap.docs.length} document(s) in session "$sessionId"');

    final appointments = <Appointment>[];
    var assignedTrainerIds = const <int>[];

    for (final doc in snap.docs) {
      logCourse('  doc "${doc.id}" fields: ${doc.data()}');
      // The trainers doc is named `assigned_trainer` (accept the plural too).
      if (doc.id == 'assigned_trainer' || doc.id == 'assigned_trainers') {
        final raw = (doc.data()['assign_to'] ?? const []) as List;
        assignedTrainerIds =
            raw.whereType<num>().map((n) => n.toInt()).toList();
        logCourse('    → assigned trainer ids: $assignedTrainerIds');
      } else {
        final appointment = Appointment.fromDoc(doc);
        logCourse(
          '    → appointment "${appointment.id}": date="${appointment.date}", '
          'enrolled_trainer=${appointment.enrolledTrainerIds}, '
          'location="${appointment.location}"',
        );
        appointments.add(appointment);
      }
    }

    appointments.sort((a, b) => a.id.compareTo(b.id));
    logCourse(
      '  session "$sessionId" summary → '
      '${appointments.length} appointment(s), '
      '${assignedTrainerIds.length} trainer(s)',
    );
    return SessionDetail(
      appointments: appointments,
      assignedTrainerIds: assignedTrainerIds,
    );
  }

  // --- Admin writes ------------------------------------------------------

  /// Creates a course document. The id (and `title`) is [name]; the `title`
  /// field guarantees the doc surfaces in collection queries. Merges so an
  /// existing course isn't wiped.
  Future<void> addCourse(String name) async {
    final id = name.trim();
    final courseId = _newId();
    logCourse('addCourse → "$id" (course_id=$courseId)');
    await _col
        .doc(id)
        .set({'title': id, 'course_id': courseId}, SetOptions(merge: true));
  }

  /// Adds a session document to a course's `sessions` sub-collection. The doc id
  /// is [name]; [order] is the 1-based position used to sort the list.
  Future<void> addSession(
    String courseId, {
    required String name,
    required String description,
    required int order,
  }) async {
    final cleanName = name.trim();
    final sessionId = _newId();
    logCourse(
        'addSession → /courses/$courseId/sessions/$cleanName (session_id=$sessionId)');
    await _sessions(courseId).doc(cleanName).set({
      'name': cleanName,
      'description': description,
      'session_id': sessionId,
      'order': order,
    }, SetOptions(merge: true));
  }

  /// Creates an `appointment{N}` doc in a session's `appointments`
  /// sub-collection and unions the assigned [trainerIds] into both the
  /// appointment's `enrolled_trainer` and the session-level `assigned_trainer`
  /// roster.
  Future<void> addAppointment(
    String courseId,
    String sessionId, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) async {
    final col = _appointments(courseId, sessionId);
    final existing = await col.get();
    final count =
        existing.docs.where((d) => d.id.startsWith('appointment')).length;
    final apptId = 'appointment${count + 1}';
    final appointmentId = _newId();

    logCourse(
        'addAppointment → /courses/$courseId/sessions/$sessionId/appointments/$apptId (appointment_id=$appointmentId)');
    await col.doc(apptId).set({
      'date': Timestamp.fromDate(date),
      'location': location.trim(),
      'enrolled_trainer': trainerIds,
      'appointment_id': appointmentId,
    });

    if (trainerIds.isNotEmpty) {
      await col.doc('assigned_trainer').set(
        {'assign_to': FieldValue.arrayUnion(trainerIds)},
        SetOptions(merge: true),
      );
    }
  }

  // --- Admin edits / deletes ---------------------------------------------

  /// Updates a course's display `title` (the doc id is fixed).
  Future<void> editCourse(String courseId, {required String title}) {
    logCourse('editCourse → /courses/$courseId title="$title"');
    return _col.doc(courseId).set({'title': title.trim()}, SetOptions(merge: true));
  }

  /// Deletes a course: clears every session (and its appointments), then deletes
  /// the course doc. The `sessions` sub-collection name is fixed, so it can be
  /// enumerated directly.
  Future<void> deleteCourse(String courseId) async {
    logCourse('deleteCourse → /courses/$courseId');
    final sessions = await _sessions(courseId).get();
    for (final session in sessions.docs) {
      await _deleteSubcollection(session.reference.collection('appointments'));
      await session.reference.delete();
    }
    await _col.doc(courseId).delete();
  }

  /// Updates a session's `description`. The session doc id ([sessionId]) is
  /// fixed — only the value changes.
  Future<void> editSession(
    String courseId, {
    required String sessionId,
    required String description,
  }) {
    logCourse('editSession → /courses/$courseId/sessions/$sessionId');
    return _sessions(courseId).doc(sessionId).update({'description': description});
  }

  /// Deletes a session: clears its `appointments` sub-collection, then the
  /// session doc.
  Future<void> deleteSession(String courseId, String sessionId) async {
    logCourse('deleteSession → /courses/$courseId/sessions/$sessionId');
    await _deleteSubcollection(_appointments(courseId, sessionId));
    await _sessions(courseId).doc(sessionId).delete();
  }

  /// Updates an appointment's `date` / `location` / `enrolled_trainer`, and
  /// unions the trainer ids into the session-level roster.
  Future<void> editAppointment(
    String courseId,
    String sessionId,
    String appointmentId, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) async {
    final col = _appointments(courseId, sessionId);
    logCourse(
        'editAppointment → /courses/$courseId/sessions/$sessionId/appointments/$appointmentId');
    await col.doc(appointmentId).set({
      'date': Timestamp.fromDate(date),
      'location': location.trim(),
      'enrolled_trainer': trainerIds,
    }, SetOptions(merge: true));

    if (trainerIds.isNotEmpty) {
      await col.doc('assigned_trainer').set(
        {'assign_to': FieldValue.arrayUnion(trainerIds)},
        SetOptions(merge: true),
      );
    }
  }

  /// Deletes a single appointment document.
  Future<void> deleteAppointment(
    String courseId,
    String sessionId,
    String appointmentId,
  ) {
    logCourse(
        'deleteAppointment → /courses/$courseId/sessions/$sessionId/appointments/$appointmentId');
    return _appointments(courseId, sessionId).doc(appointmentId).delete();
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
