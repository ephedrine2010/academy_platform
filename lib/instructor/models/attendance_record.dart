import 'package:cloud_firestore/cloud_firestore.dart';

/// How a trainee's attendance was confirmed.
enum AttendanceMethod { location, instructor }

/// One attendance record, stored at
/// `sessions/{id}/appointments/{appt}/attendance/{traineeId}`. Its existence
/// means the trainee is confirmed present; the [method] says how.
///
/// - `location`   → the trainee self-confirmed from inside the geofence.
/// - `instructor` → the instructor marked them present (the fallback/override).
class AttendanceRecord {
  const AttendanceRecord({
    required this.traineeId,
    required this.method,
    this.at,
    this.markedBy,
  });

  final int traineeId;
  final AttendanceMethod method;

  /// When the record was written.
  final DateTime? at;

  /// Instructor uid that confirmed — only set for [AttendanceMethod.instructor].
  final String? markedBy;

  bool get bySelf => method == AttendanceMethod.location;

  factory AttendanceRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    final at = data['at'];
    return AttendanceRecord(
      traineeId: int.tryParse(doc.id) ?? (data['trainee_id'] as num?)?.toInt() ?? 0,
      method: (data['method'] == 'location')
          ? AttendanceMethod.location
          : AttendanceMethod.instructor,
      at: at is Timestamp ? at.toDate() : null,
      markedBy: data['marked_by'] as String?,
    );
  }
}
