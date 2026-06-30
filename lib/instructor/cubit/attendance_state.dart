part of 'attendance_cubit.dart';

class AttendanceState extends Equatable {
  const AttendanceState({
    required this.appointment,
    this.profiles = const [],
    this.records = const {},
    this.loading = true,
    this.error,
  });

  /// The appointment being managed (with its current geofence/window config).
  final Appointment appointment;

  /// Enrolled trainees resolved to profiles (mocked today via [TraineeDirectory]).
  final List<TraineeProfile> profiles;

  /// Attendance records keyed by trainee id; absent = not yet confirmed.
  final Map<int, AttendanceRecord> records;

  final bool loading;
  final String? error;

  AttendanceState copyWith({
    Appointment? appointment,
    List<TraineeProfile>? profiles,
    Map<int, AttendanceRecord>? records,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceState(
      appointment: appointment ?? this.appointment,
      profiles: profiles ?? this.profiles,
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [appointment, profiles, records, loading, error];
}
