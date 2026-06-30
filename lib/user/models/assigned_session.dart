import '../../courses/models/course.dart';

/// One session a trainee is assigned to, paired with its parent course's display
/// title (resolved for the home card). Built by `UserRepository` from the
/// trainee's `users/{id}.assigned_sessions` array.
class AssignedSession {
  const AssignedSession({required this.session, required this.courseTitle});

  /// The session the trainee is enrolled in.
  final CourseSession session;

  /// The parent course's display title (e.g. `Care 360`), resolved from the
  /// session's `course_id`. Falls back to the course doc id, or `'—'` when the
  /// course can't be resolved.
  final String courseTitle;
}
