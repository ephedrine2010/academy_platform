import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../../courses/data/trainee_directory.dart';
import '../../courses/models/appointment.dart';
import '../data/instructor_repository.dart';
import '../models/attendance_record.dart';

part 'attendance_state.dart';

/// Drives one appointment's attendance screen: resolves the enrolled trainees
/// into profiles, loads their attendance records, and exposes the instructor
/// actions — arm the geofence, mark a trainee present, or revoke.
///
/// One-shot loads (reloads after each write), matching the rest of the
/// courses/instructor read paths.
class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit({
    required InstructorRepository repository,
    required String sessionId,
    required Appointment appointment,
    TraineeDirectory directory = const TraineeDirectory(),
  })  : _repo = repository,
        _sessionId = sessionId,
        super(AttendanceState(
          appointment: appointment,
          profiles: directory.profilesFor(appointment.enrolledTraineeIds),
        )) {
    load();
  }

  final InstructorRepository _repo;
  final String _sessionId;

  String get _appointmentId => state.appointment.id;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final records = await _repo.loadAttendance(_sessionId, _appointmentId);
      emit(state.copyWith(loading: false, records: records));
    } catch (e, s) {
      logError('AttendanceCubit.load', e, s);
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> arm({
    required double lat,
    required double lng,
    required int radiusM,
    required int windowHours,
  }) async {
    await _repo.armAttendance(
      _sessionId,
      _appointmentId,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      windowHours: windowHours,
    );
    // Reflect the armed config locally (server timestamp resolves to ~now).
    emit(state.copyWith(
      appointment: state.appointment.copyWith(
        geoLat: lat,
        geoLng: lng,
        geoRadiusM: radiusM,
        windowHours: windowHours,
        attendanceOpenedAt: DateTime.now(),
      ),
    ));
  }

  Future<void> mark(int traineeId) async {
    await _repo.markAttended(_sessionId, _appointmentId, traineeId);
    await load();
  }

  Future<void> revoke(int traineeId) async {
    await _repo.revokeAttendance(_sessionId, _appointmentId, traineeId);
    await load();
  }
}
