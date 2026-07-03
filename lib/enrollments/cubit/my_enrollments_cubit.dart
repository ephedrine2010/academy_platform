import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/enrollment_repository.dart';
import '../models/enrollment.dart';
import '../scorm/scorm_session.dart';

part 'my_enrollments_state.dart';

/// Loads the signed-in trainee's enrollments (their "My learning" list) by
/// sign-in [email]: resolves the trainee's int id, then subscribes to a live
/// stream of their `enrollments`.
class MyEnrollmentsCubit extends Cubit<MyEnrollmentsState> {
  MyEnrollmentsCubit({required String email, EnrollmentRepository? repository})
      : _repo = repository ?? EnrollmentRepository(),
        _email = email,
        super(const MyEnrollmentsState()) {
    _init();
  }

  final EnrollmentRepository _repo;
  final String _email;
  StreamSubscription<List<Enrollment>>? _sub;

  Future<void> _init() async {
    try {
      final id = await _repo.resolveTraineeId(_email);
      if (id == null) {
        logCourse('MyEnrollmentsCubit: no users doc for "$_email"');
        emit(state.copyWith(loading: false, enrollments: const []));
        return;
      }
      _sub = _repo.watchForTrainee(id).listen(
        (list) =>
            emit(state.copyWith(enrollments: list, loading: false, traineeId: id)),
        onError: (Object e, StackTrace s) {
          logError('MyEnrollmentsCubit.watch', e, s);
          emit(state.copyWith(loading: false, error: '$e'));
        },
      );
    } catch (e, s) {
      logError('MyEnrollmentsCubit._init', e, s);
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  /// Marks an enrollment started when the trainee opens it (notStarted →
  /// inProgress). The stream reflects the change.
  Future<void> markStarted(Enrollment e) => _repo.markStarted(e.id);

  /// Persists a SCORM progress snapshot from the player (called on the SCO's
  /// commit/finish and on meaningful changes — see [ScormSession]).
  Future<void> saveProgress(Enrollment e, ScormProgress p) => _repo.updateProgress(
        e.id,
        progress: p.progress,
        lifecycleState: p.lifecycleState,
        outcome: p.outcome,
        score: p.score,
        lessonLocation: p.lessonLocation,
        suspendData: p.suspendData,
      );

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
