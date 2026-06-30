import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../../courses/models/appointment.dart';
import '../models/attendance_record.dart';
import '../models/today_appointment.dart';

/// Firestore access for the instructor Home / attendance feature.
///
/// Scoped to one instructor by [instructorId] (the admin uid stored as
/// `created_by` on the courses/sessions they authored). Today's appointments are
/// found by **walking** that ownership chain — courses → sessions → appointments
/// dated today — rather than a `collectionGroup` query, because appointment docs
/// carry no owner field to scope on (and so no composite index / backfill is
/// needed). See `documentation/instructor/` for the design.
class InstructorRepository {
  InstructorRepository({
    FirebaseFirestore? firestore,
    required this.instructorId,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// The signed-in instructor's uid (== `created_by` on their courses/sessions).
  final String instructorId;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection('courses');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  CollectionReference<Map<String, dynamic>> _appointments(String sessionId) =>
      _sessions.doc(sessionId).collection('appointments');

  CollectionReference<Map<String, dynamic>> _attendance(
    String sessionId,
    String appointmentId,
  ) =>
      _appointments(sessionId).doc(appointmentId).collection('attendance');

  /// Loads every appointment dated **today** across the instructor's own
  /// courses, each tagged with its session name + course title for display.
  Future<List<TodayAppointment>> loadTodayAppointments({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    logInstructor(
      'loadTodayAppointments → courses where created_by == "$instructorId", '
      'date in [$start, $end)',
    );

    final courses =
        await _courses.where('created_by', isEqualTo: instructorId).get();
    logInstructor('  ${courses.docs.length} course(s) owned');

    final result = <TodayAppointment>[];
    for (final course in courses.docs) {
      final courseTitle =
          (course.data()['title'] ?? course.id).toString();
      final sessions =
          await _sessions.where('course_id', isEqualTo: course.id).get();
      for (final session in sessions.docs) {
        final sessionName =
            (session.data()['name'] ?? session.id).toString();
        // Range filter on a single field needs no composite index; docs without
        // a `date` (e.g. the legacy `assigned_instructor` doc) are excluded.
        final appts = await _appointments(session.id)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end))
            .get();
        for (final doc in appts.docs) {
          result.add(TodayAppointment(
            appointment: Appointment.fromDoc(doc),
            sessionId: session.id,
            sessionName: sessionName,
            courseTitle: courseTitle,
          ));
        }
      }
    }

    result.sort((a, b) {
      final da = a.appointment.dateTime;
      final db = b.appointment.dateTime;
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    logInstructor('  → ${result.length} appointment(s) today');
    return result;
  }

  /// "Arms" attendance for an appointment: writes the geofence centre + radius +
  /// self-check-in window, and stamps `attendance_opened_at` (the signal that
  /// trainee self check-in is now open).
  Future<void> armAttendance(
    String sessionId,
    String appointmentId, {
    required double lat,
    required double lng,
    required int radiusM,
    required int windowHours,
  }) {
    logInstructor(
      'armAttendance → /sessions/$sessionId/appointments/$appointmentId '
      '(lat=$lat, lng=$lng, r=${radiusM}m, window=${windowHours}h)',
    );
    return _appointments(sessionId).doc(appointmentId).set({
      'geo_lat': lat,
      'geo_lng': lng,
      'geo_radius_m': radiusM,
      'window_hours': windowHours,
      'attendance_opened_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Reads the attendance records for an appointment, keyed by trainee id.
  Future<Map<int, AttendanceRecord>> loadAttendance(
    String sessionId,
    String appointmentId,
  ) async {
    final snap = await _attendance(sessionId, appointmentId).get();
    logInstructor(
      'loadAttendance → /sessions/$sessionId/appointments/$appointmentId'
      '/attendance → ${snap.docs.length} record(s)',
    );
    return {
      for (final doc in snap.docs)
        AttendanceRecord.fromDoc(doc).traineeId: AttendanceRecord.fromDoc(doc),
    };
  }

  /// Instructor confirms a trainee present (the fallback / override path).
  Future<void> markAttended(
    String sessionId,
    String appointmentId,
    int traineeId,
  ) {
    logInstructor(
      'markAttended → trainee $traineeId @ '
      '/sessions/$sessionId/appointments/$appointmentId',
    );
    return _attendance(sessionId, appointmentId).doc('$traineeId').set({
      'trainee_id': traineeId,
      'method': 'instructor',
      'marked_by': instructorId,
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a trainee's attendance record (revoke a confirm / self check-in).
  Future<void> revokeAttendance(
    String sessionId,
    String appointmentId,
    int traineeId,
  ) {
    logInstructor(
      'revokeAttendance → trainee $traineeId @ '
      '/sessions/$sessionId/appointments/$appointmentId',
    );
    return _attendance(sessionId, appointmentId).doc('$traineeId').delete();
  }
}
