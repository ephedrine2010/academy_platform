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
