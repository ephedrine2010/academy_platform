import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One appointment within a session's nested sub-collection, e.g.
/// `/sessions/{sessionId}/appointments/appointment1`. Fields: `date` (Timestamp),
/// `enrolled_instructor` (int array of instructor ids), `enrolled_trainees`
/// (int array of trainee ids — who the trainee self-enrolls into), `location`
/// (string).
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.date,
    required this.dateTime,
    required this.enrolledInstructorIds,
    required this.enrolledTraineeIds,
    required this.location,
    this.appointmentId,
    this.geoLat,
    this.geoLng,
    this.geoRadiusM,
    this.windowHours,
    this.attendanceOpenedAt,
  });

  final String id;

  /// Stable 10-digit numeric id (the `appointment_id` field). Null for legacy
  /// appointments created before ids existed.
  final int? appointmentId;

  /// Display string for the `date` field — formatted when it's a Firestore
  /// [Timestamp], otherwise the raw value.
  final String date;

  /// Raw `date` as a [DateTime] when it was a [Timestamp] (used to pre-fill the
  /// edit dialog); null otherwise.
  final DateTime? dateTime;

  /// Instructor ids enrolled for this appointment (the `enrolled_instructor` array).
  final List<int> enrolledInstructorIds;

  /// Trainee ids enrolled for this appointment (the `enrolled_trainees` array).
  /// A trainee self-enrolls into exactly one appointment per session.
  final List<int> enrolledTraineeIds;
  final String location;

  /// Geofence centre for self check-in (the `geo_lat` / `geo_lng` fields), set
  /// by the instructor when they "arm" attendance for the day. Null until armed.
  final double? geoLat;
  final double? geoLng;

  /// Geofence radius in metres (`geo_radius_m`). Null until armed.
  final int? geoRadiusM;

  /// How many hours after [dateTime] a trainee may still self check-in
  /// (`window_hours`). Null until armed.
  final int? windowHours;

  /// When the instructor armed attendance (`attendance_opened_at`). Non-null
  /// here is the signal that self check-in is open for this appointment.
  final DateTime? attendanceOpenedAt;

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    final openedAt = data['attendance_opened_at'];
    return Appointment(
      id: doc.id,
      date: _formatDate(rawDate),
      dateTime: rawDate is Timestamp ? rawDate.toDate() : null,
      enrolledInstructorIds: _intList(data['enrolled_instructor']),
      enrolledTraineeIds: _intList(data['enrolled_trainees']),
      location: (data['location'] ?? '').toString(),
      appointmentId: (data['appointment_id'] as num?)?.toInt(),
      geoLat: (data['geo_lat'] as num?)?.toDouble(),
      geoLng: (data['geo_lng'] as num?)?.toDouble(),
      geoRadiusM: (data['geo_radius_m'] as num?)?.toInt(),
      windowHours: (data['window_hours'] as num?)?.toInt(),
      attendanceOpenedAt: openedAt is Timestamp ? openedAt.toDate() : null,
    );
  }

  static List<int> _intList(dynamic value) {
    if (value is List) {
      return value.whereType<num>().map((n) => n.toInt()).toList();
    }
    return const [];
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}-${_two(d.month)}-${_two(d.day)} '
          '${_two(d.hour)}:${_two(d.minute)}';
    }
    return value?.toString() ?? '';
  }

  /// Whether the instructor has armed self check-in for this appointment.
  bool get attendanceOpen => attendanceOpenedAt != null;

  Appointment copyWith({
    double? geoLat,
    double? geoLng,
    int? geoRadiusM,
    int? windowHours,
    DateTime? attendanceOpenedAt,
  }) {
    return Appointment(
      id: id,
      date: date,
      dateTime: dateTime,
      enrolledInstructorIds: enrolledInstructorIds,
      enrolledTraineeIds: enrolledTraineeIds,
      location: location,
      appointmentId: appointmentId,
      geoLat: geoLat ?? this.geoLat,
      geoLng: geoLng ?? this.geoLng,
      geoRadiusM: geoRadiusM ?? this.geoRadiusM,
      windowHours: windowHours ?? this.windowHours,
      attendanceOpenedAt: attendanceOpenedAt ?? this.attendanceOpenedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        date,
        dateTime,
        enrolledInstructorIds,
        enrolledTraineeIds,
        location,
        appointmentId,
        geoLat,
        geoLng,
        geoRadiusM,
        windowHours,
        attendanceOpenedAt,
      ];
}
