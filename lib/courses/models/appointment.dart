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

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    return Appointment(
      id: doc.id,
      date: _formatDate(rawDate),
      dateTime: rawDate is Timestamp ? rawDate.toDate() : null,
      enrolledInstructorIds: _intList(data['enrolled_instructor']),
      enrolledTraineeIds: _intList(data['enrolled_trainees']),
      location: (data['location'] ?? '').toString(),
      appointmentId: (data['appointment_id'] as num?)?.toInt(),
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

  @override
  List<Object?> get props => [
        id,
        date,
        dateTime,
        enrolledInstructorIds,
        enrolledTraineeIds,
        location,
        appointmentId,
      ];
}
