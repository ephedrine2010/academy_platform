import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/contractor_repository.dart';
import '../models/contractor.dart';

part 'contractors_state.dart';

/// Live list of contractors plus create/update/delete. Region assignment is
/// carried on each [Contractor.regionIds].
class ContractorsCubit extends Cubit<ContractorsState> {
  ContractorsCubit({ContractorRepository? repository})
      : _repo = repository ?? ContractorRepository(),
        super(const ContractorsState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(contractors: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('ContractorsCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final ContractorRepository _repo;
  late final StreamSubscription<List<Contractor>> _sub;

  Future<void> add(Contractor c) => _repo.add(c);

  Future<void> update(Contractor c) => _repo.update(c);

  Future<void> delete(String id) => _repo.delete(id);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
