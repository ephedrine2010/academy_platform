import 'appointment.dart';

/// The loaded contents of a single course session sub-collection: its
/// appointment documents plus the instructor ids from the `assigned_instructors`
/// doc's `assign_to` int array.
class SessionDetail {
  const SessionDetail({
    required this.appointments,
    required this.assignedInstructorIds,
  });

  final List<Appointment> appointments;
  final List<int> assignedInstructorIds;
}
