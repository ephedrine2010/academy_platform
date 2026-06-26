import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/contractor_repository.dart';
import '../data/region_repository.dart';
import '../models/region.dart';

part 'regions_state.dart';

/// Live list of regions plus create/rename/delete. Deleting a region also
/// scrubs it from every contractor's assignment list.
class RegionsCubit extends Cubit<RegionsState> {
  RegionsCubit({
    RegionRepository? regions,
    ContractorRepository? contractors,
  })  : _regions = regions ?? RegionRepository(),
        _contractors = contractors ?? ContractorRepository(),
        super(const RegionsState()) {
    _sub = _regions.watch().listen(
      (list) => emit(state.copyWith(regions: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('RegionsCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final RegionRepository _regions;
  final ContractorRepository _contractors;
  late final StreamSubscription<List<Region>> _sub;

  Future<void> add(String name) => _regions.add(name.trim());

  Future<void> rename(String id, String name) =>
      _regions.rename(id, name.trim());

  Future<void> delete(String id) async {
    await _contractors.removeRegionFromAll(id);
    await _regions.delete(id);
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
