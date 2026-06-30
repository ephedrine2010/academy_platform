import '../../courses/models/appointment.dart';

/// One of today's appointments for the signed-in instructor, carrying enough
/// context (its session and parent course) to render a card on the instructor
/// Home and to open its attendance screen.
///
/// Built by walking the instructor's courses → sessions → today's appointments
/// (see `InstructorRepository.loadTodayAppointments`).
class TodayAppointment {
  const TodayAppointment({
    required this.appointment,
    required this.sessionId,
    required this.sessionName,
    required this.courseTitle,
  });

  final Appointment appointment;

  /// The `sessions` doc id this appointment lives under (needed for writes).
  final String sessionId;
  final String sessionName;
  final String courseTitle;
}
