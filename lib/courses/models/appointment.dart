import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One appointment within a session sub-collection, e.g.
/// `/courses/care360/beauty360/appointment1`. Fields: `date` (Timestamp),
/// `enrolled_trainer` (int array of trainer ids), `location` (string).
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.date,
    required this.dateTime,
    required this.enrolledTrainerIds,
    required this.location,
  });

  final String id;

  /// Display string for the `date` field — formatted when it's a Firestore
  /// [Timestamp], otherwise the raw value.
  final String date;

  /// Raw `date` as a [DateTime] when it was a [Timestamp] (used to pre-fill the
  /// edit dialog); null otherwise.
  final DateTime? dateTime;

  /// Trainer ids enrolled for this appointment (the `enrolled_trainer` array).
  final List<int> enrolledTrainerIds;
  final String location;

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    return Appointment(
      id: doc.id,
      date: _formatDate(rawDate),
      dateTime: rawDate is Timestamp ? rawDate.toDate() : null,
      enrolledTrainerIds: _intList(data['enrolled_trainer']),
      location: (data['location'] ?? '').toString(),
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
  List<Object?> get props => [id, date, dateTime, enrolledTrainerIds, location];
}
