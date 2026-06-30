part of 'instructor_home_cubit.dart';

class InstructorHomeState extends Equatable {
  const InstructorHomeState({
    this.appointments = const [],
    this.loading = true,
    this.error,
  });

  final List<TodayAppointment> appointments;
  final bool loading;
  final String? error;

  InstructorHomeState copyWith({
    List<TodayAppointment>? appointments,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return InstructorHomeState(
      appointments: appointments ?? this.appointments,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [appointments, loading, error];
}
