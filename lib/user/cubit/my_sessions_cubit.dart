import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../../courses/models/appointment.dart';
import '../data/user_repository.dart';
import '../models/assigned_session.dart';

part 'my_sessions_state.dart';

/// Loads the signed-in trainee's assigned sessions (for the Home screen) by
/// their sign-in [email]. Unlike `CoursesCubit` this is a one-shot load rather
/// than a live stream — re-call [refresh] to reload after assignments change.
class MySessionsCubit extends Cubit<MySessionsState> {
  MySessionsCubit({required String email, UserRepository? repository})
      : _repo = repository ?? UserRepository(),
        _email = email,
        super(const MySessionsState()) {
    refresh();
  }

  final UserRepository _repo;
  final String _email;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await _repo.loadAssignedSessions(_email);
      emit(MySessionsState(
        sessions: result.sessions,
        traineeId: result.traineeId,
        loading: false,
      ));
    } catch (e, s) {
      logError('MySessionsCubit.refresh', e, s);
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  /// Loads one assigned session's appointments on demand (when its card is
  /// expanded). Read-only, so it returns a future rather than emitting state.
  Future<List<Appointment>> loadAppointments(String sessionId) =>
      _repo.loadAppointments(sessionId);

  /// Enrolls the signed-in trainee into [appointmentId] of [sessionId]
  /// (exclusive: leaves any other appointment of the same session). No-op when
  /// the trainee id is unknown.
  Future<void> enroll(String sessionId, String appointmentId) async {
    final id = state.traineeId;
    if (id == null) return;
    await _repo.enroll(sessionId, appointmentId, id);
  }

  /// Un-enrolls the signed-in trainee from [appointmentId] of [sessionId].
  Future<void> unenroll(String sessionId, String appointmentId) async {
    final id = state.traineeId;
    if (id == null) return;
    await _repo.unenroll(sessionId, appointmentId, id);
  }
}
