part of 'my_enrollments_cubit.dart';

/// State for the trainee's enrollment list.
class MyEnrollmentsState extends Equatable {
  const MyEnrollmentsState({
    this.enrollments = const [],
    this.loading = true,
    this.error,
    this.traineeId,
  });

  final List<Enrollment> enrollments;
  final bool loading;
  final String? error;
  final int? traineeId;

  /// Content-type enrollments (self-paced / material-backed) — the "My learning"
  /// list. Attendance-only sessions still live on Home/Schedule.
  List<Enrollment> get learning =>
      enrollments.where((e) => e.deliveryType.usesMaterial).toList();

  MyEnrollmentsState copyWith({
    List<Enrollment>? enrollments,
    bool? loading,
    String? error,
    int? traineeId,
  }) {
    return MyEnrollmentsState(
      enrollments: enrollments ?? this.enrollments,
      loading: loading ?? this.loading,
      error: error,
      traineeId: traineeId ?? this.traineeId,
    );
  }

  @override
  List<Object?> get props => [enrollments, loading, error, traineeId];
}
