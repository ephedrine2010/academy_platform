import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
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
      final sessions = await _repo.loadAssignedSessions(_email);
      emit(MySessionsState(sessions: sessions, loading: false));
    } catch (e, s) {
      logError('MySessionsCubit.refresh', e, s);
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }
}
