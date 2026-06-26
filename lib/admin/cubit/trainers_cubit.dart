import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/trainer_repository.dart';
import '../models/trainer.dart';

part 'trainers_state.dart';

/// Live list of trainers plus create/update/delete. Region assignment is
/// carried on each [Trainer.regionNames].
class TrainersCubit extends Cubit<TrainersState> {
  TrainersCubit({TrainerRepository? repository})
      : _repo = repository ?? TrainerRepository(),
        super(const TrainersState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(trainers: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('TrainersCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final TrainerRepository _repo;
  late final StreamSubscription<List<Trainer>> _sub;

  Future<void> add(Trainer t) => _repo.add(t);

  Future<void> update(Trainer t) => _repo.update(t);

  Future<void> delete(String id) => _repo.delete(id);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
