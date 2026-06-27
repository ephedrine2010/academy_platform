import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../models/appointment.dart';
import '../models/course.dart';
import '../models/session_detail.dart';

/// Firestore access for the `courses` collection. Each document is one course
/// (its id is the course title key). For now this only streams the list of
/// course documents — sessions / appointments / assigned trainers are loaded in
/// a later milestone.
///
/// Note: a course document that holds *only* sub-collections (no top-level
/// fields) is a "phantom" parent and will not appear in this listing. Give each
/// course document at least a `title` field so it surfaces here.
class CourseRepository {
  CourseRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('courses');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<Course>> watch() => _col.snapshots().map((snap) {
        logCourse('courses collection → ${snap.docs.length} document(s)');
        final courses = <Course>[];
        for (final doc in snap.docs) {
          logCourse('  course "${doc.id}" fields: ${doc.data()}');
          final course = Course.fromDoc(doc);
          logCourse(
            '    parsed → title="${course.title}", '
            'sessions(${course.sessions.length})=${course.sessions}',
          );
          courses.add(course);
        }
        return courses;
      });

  /// Loads one session sub-collection (e.g. `/courses/care360/Health360`):
  /// every appointment document plus the trainer ids from the
  /// `assigned_trainers` doc. The `assigned_trainers` doc lives alongside the
  /// appointment docs in the same sub-collection, so it is filtered out of the
  /// appointment list.
  Future<SessionDetail> loadSession(String courseId, String sessionName) async {
    logCourse('loadSession → /courses/$courseId/$sessionName');
    final snap = await _col.doc(courseId).collection(sessionName).get();
    logCourse('  ${snap.docs.length} document(s) in session "$sessionName"');

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
      '  session "$sessionName" summary → '
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
  Future<void> addCourse(String name) {
    final id = name.trim();
    logCourse('addCourse → "$id"');
    return _col.doc(id).set({'title': id}, SetOptions(merge: true));
  }

  /// Adds a session to a course by writing a `session{order}-{name}` field
  /// (value = [description]) on the course doc. [order] is the 1-based position
  /// (used only for the ordering prefix).
  Future<void> addSession(
    String courseId, {
    required String name,
    required String description,
    required int order,
  }) {
    final key = 'session$order-${name.trim()}';
    logCourse('addSession → /courses/$courseId field "$key"');
    return _col.doc(courseId).set({key: description}, SetOptions(merge: true));
  }

  /// Creates an `appointment{N}` doc in a session sub-collection and unions the
  /// assigned [trainerIds] into both the appointment's `enrolled_trainer` and
  /// the session-level `assigned_trainer` roster.
  Future<void> addAppointment(
    String courseId,
    String sessionName, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) async {
    final col = _col.doc(courseId).collection(sessionName);
    final existing = await col.get();
    final count =
        existing.docs.where((d) => d.id.startsWith('appointment')).length;
    final apptId = 'appointment${count + 1}';

    logCourse('addAppointment → /courses/$courseId/$sessionName/$apptId');
    await col.doc(apptId).set({
      'date': Timestamp.fromDate(date),
      'location': location.trim(),
      'enrolled_trainer': trainerIds,
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

  /// Deletes a course: clears every session sub-collection's documents, then
  /// deletes the course doc. [sessionNames] are the sub-collection names
  /// (derived from the course's session fields).
  Future<void> deleteCourse(String courseId, List<String> sessionNames) async {
    logCourse('deleteCourse → /courses/$courseId (sessions: $sessionNames)');
    for (final name in sessionNames) {
      await _deleteSubcollection(_col.doc(courseId).collection(name));
    }
    await _col.doc(courseId).delete();
  }

  /// Updates a session's description. The session [key] (field name) is fixed —
  /// only the value changes.
  Future<void> editSession(
    String courseId, {
    required String key,
    required String description,
  }) {
    logCourse('editSession → /courses/$courseId field "$key"');
    return _col.doc(courseId).update({key: description});
  }

  /// Deletes a session: clears its appointment sub-collection, then removes the
  /// session field ([key]) from the course doc. [sessionName] is the
  /// sub-collection name (the key minus its `sessionN-` prefix).
  Future<void> deleteSession(
    String courseId, {
    required String key,
    required String sessionName,
  }) async {
    logCourse('deleteSession → /courses/$courseId "$sessionName" (field "$key")');
    await _deleteSubcollection(_col.doc(courseId).collection(sessionName));
    await _col.doc(courseId).update({key: FieldValue.delete()});
  }

  /// Updates an appointment's `date` / `location` / `enrolled_trainer`, and
  /// unions the trainer ids into the session-level roster.
  Future<void> editAppointment(
    String courseId,
    String sessionName,
    String appointmentId, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) async {
    final col = _col.doc(courseId).collection(sessionName);
    logCourse('editAppointment → /courses/$courseId/$sessionName/$appointmentId');
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
    String sessionName,
    String appointmentId,
  ) {
    logCourse('deleteAppointment → /courses/$courseId/$sessionName/$appointmentId');
    return _col.doc(courseId).collection(sessionName).doc(appointmentId).delete();
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
