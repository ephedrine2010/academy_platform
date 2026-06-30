part of 'my_sessions_cubit.dart';

class MySessionsState extends Equatable {
  const MySessionsState({
    this.sessions = const [],
    this.loading = true,
    this.error,
  });

  final List<AssignedSession> sessions;
  final bool loading;
  final String? error;

  MySessionsState copyWith({
    List<AssignedSession>? sessions,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return MySessionsState(
      sessions: sessions ?? this.sessions,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [sessions, loading, error];
}
