import 'appointment.dart';

/// The loaded contents of a single course session sub-collection: its
/// appointment documents plus the trainer ids from the `assigned_trainers`
/// doc's `assign_to` int array.
class SessionDetail {
  const SessionDetail({
    required this.appointments,
    required this.assignedTrainerIds,
  });

  final List<Appointment> appointments;
  final List<int> assignedTrainerIds;
}
