part of 'my_sessions_cubit.dart';

class MySessionsState extends Equatable {
  const MySessionsState({
    this.sessions = const [],
    this.traineeId,
    this.loading = true,
    this.error,
  });

  final List<AssignedSession> sessions;

  /// The signed-in trainee's int id (== their `users` doc id), needed to
  /// self-enroll into appointments. Null until resolved / when no `users` doc
  /// matched the email.
  final int? traineeId;

  final bool loading;
  final String? error;

  /// Total sessions assigned to the trainee.
  int get total => sessions.length;

  /// How many assigned sessions the trainee has **fulfilled** (confirmed present).
  int get fulfilled => sessions.where((s) => s.fulfilled).length;

  /// How many assigned sessions the trainee is booked into but hasn't attended.
  int get pending =>
      sessions.where((s) => s.status == SessionStatus.enrolled).length;

  /// Fulfilled fraction in `0.0..1.0` (0 when nothing is assigned).
  double get progress => total == 0 ? 0 : fulfilled / total;

  MySessionsState copyWith({
    List<AssignedSession>? sessions,
    int? traineeId,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return MySessionsState(
      sessions: sessions ?? this.sessions,
      traineeId: traineeId ?? this.traineeId,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [sessions, traineeId, loading, error];
}
