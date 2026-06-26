import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/region_repository.dart';
import '../data/trainer_repository.dart';
import '../models/region.dart';

part 'regions_state.dart';

/// Live list of regions plus create/rename/delete. Deleting a region also
/// scrubs it from every trainer's assignment list.
class RegionsCubit extends Cubit<RegionsState> {
  RegionsCubit({
    RegionRepository? regions,
    TrainerRepository? trainers,
  })  : _regions = regions ?? RegionRepository(),
        _trainers = trainers ?? TrainerRepository(),
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
  final TrainerRepository _trainers;
  late final StreamSubscription<List<Region>> _sub;

  Future<void> add(String name) => _regions.add(name.trim());

  Future<void> rename(String id, String name) async {
    final newName = name.trim();
    final oldName = _nameOf(id);
    await _regions.rename(id, newName);
    if (oldName != null) {
      await _trainers.renameRegionInAll(oldName, newName);
    }
  }

  Future<void> delete(String id) async {
    final name = _nameOf(id);
    if (name != null) await _trainers.removeRegionFromAll(name);
    await _regions.delete(id);
  }

  String? _nameOf(String id) {
    for (final r in state.regions) {
      if (r.id == id) return r.name;
    }
    return null;
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
