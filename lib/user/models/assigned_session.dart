import '../../courses/models/course.dart';

/// Where a trainee stands on one assigned session, driving the Home progress.
///
/// - [notEnrolled] — assigned, but hasn't picked an appointment yet.
/// - [enrolled] — booked into an appointment, attendance not yet confirmed.
/// - [attended] — confirmed present (an attendance record exists) → **fulfilled**.
enum SessionStatus { notEnrolled, enrolled, attended }

/// One session a trainee is assigned to, paired with its parent course's display
/// title (resolved for the home card) and the trainee's [status] on it. Built by
/// `UserRepository` from the trainee's `users/{id}.assigned_sessions` array.
class AssignedSession {
  const AssignedSession({
    required this.session,
    required this.courseTitle,
    this.status = SessionStatus.notEnrolled,
  });

  /// The session the trainee is enrolled in.
  final CourseSession session;

  /// The parent course's display title (e.g. `Care 360`), resolved from the
  /// session's `course_id`. Falls back to the course doc id, or `'—'` when the
  /// course can't be resolved.
  final String courseTitle;

  /// The trainee's standing on this session — see [SessionStatus]. Resolved by
  /// looking at which appointment they enrolled in and whether an attendance
  /// record exists for them.
  final SessionStatus status;

  /// Whether the trainee has **fulfilled** this session (confirmed present).
  bool get fulfilled => status == SessionStatus.attended;

  AssignedSession copyWith({SessionStatus? status}) => AssignedSession(
        session: session,
        courseTitle: courseTitle,
        status: status ?? this.status,
      );
}

/// The result of resolving a trainee's home data: their own int id (the `users`
/// doc id, needed to self-enroll into appointments) plus the sessions they're
/// assigned to. [traineeId] is null when no `users` doc matched the email.
class MySessions {
  const MySessions({required this.traineeId, required this.sessions});

  /// The signed-in trainee's int id (== their `users` doc id). Null when the
  /// login email matched no `users` doc.
  final int? traineeId;

  final List<AssignedSession> sessions;
}
