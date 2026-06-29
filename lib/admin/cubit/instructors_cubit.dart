import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/instructor_repository.dart';
import '../models/instructor.dart';

part 'instructors_state.dart';

/// Live list of instructors plus create/update/delete. Region assignment is
/// carried on each [Instructor.regionNames].
class InstructorsCubit extends Cubit<InstructorsState> {
  InstructorsCubit({InstructorRepository? repository})
      : _repo = repository ?? InstructorRepository(),
        super(const InstructorsState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(instructors: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('InstructorsCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final InstructorRepository _repo;
  late final StreamSubscription<List<Instructor>> _sub;

  Future<void> add(Instructor t) => _repo.add(t);

  Future<void> update(Instructor t) => _repo.update(t);

  Future<void> delete(String id) => _repo.delete(id);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
