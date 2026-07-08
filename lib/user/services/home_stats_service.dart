import '../../enrollments/cubit/my_enrollments_cubit.dart';
import '../cubit/my_sessions_cubit.dart';
import '../models/assigned_session.dart';

/// The trainee's Home tally — **one** set of numbers shared by the stats row and
/// the progress card so they can never disagree.
///
/// The key idea (see [HomeStatsService]): everything the trainee is assigned is
/// a **session**; a session is either finished or not. *How* "finished" is
/// measured just depends on the delivery type — attendance for physical/webinar,
/// SCORM completion (the enrollment's `done` state) for self-paced — but it's the
/// same session either way, counted once.
class HomeStats {
  const HomeStats({
    required this.assigned,
    required this.enrolled,
    required this.completed,
    required this.pending,
    required this.ready,
  });

  /// Total sessions assigned to the trainee (every delivery type).
  final int assigned;

  /// Of those, how many are self-paced (material-backed) — the "My learning"
  /// subset.
  final int enrolled;

  /// How many assigned sessions the trainee has **finished** (attended, or the
  /// self-paced material completed).
  final int completed;

  /// Booked into an appointment but not yet finished.
  final int pending;

  /// False until both data sources have resolved their first value, so callers
  /// can hold off rendering until the numbers are final rather than mid-load.
  final bool ready;

  /// Finished fraction in `0.0..1.0` (0 when nothing is assigned).
  double get progress => assigned == 0 ? 0 : completed / assigned;
}

/// Derives [HomeStats] from the trainee's sessions + enrollments. Pure and
/// stateless — widgets call it on every rebuild.
///
/// A self-paced session appears in *both* sources (it's in `assigned_sessions`
/// and has an `enrollments` doc), but its completion only lives in the
/// enrollment. So we index the done enrollments by session id and treat a
/// session as finished when it's either **attended** or has a **done**
/// enrollment — counting each session once, however it was delivered.
class HomeStatsService {
  const HomeStatsService();

  HomeStats compute(MySessionsState sessions, MyEnrollmentsState enrollments) {
    final doneSessionIds = <String>{
      for (final e in enrollments.enrollments)
        if (e.isDone) e.sessionId,
    };

    var completed = 0;
    var pending = 0;
    for (final s in sessions.sessions) {
      if (s.fulfilled || doneSessionIds.contains(s.session.id)) {
        completed++;
      } else if (s.status == SessionStatus.enrolled) {
        pending++;
      }
    }

    return HomeStats(
      assigned: sessions.total,
      enrolled: enrollments.learning.length,
      completed: completed,
      pending: pending,
      ready: !sessions.loading && !enrollments.loading,
    );
  }
}
