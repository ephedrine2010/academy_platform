import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/material_repository.dart';
import '../models/training_material.dart';

part 'materials_state.dart';

/// Live list of the shared material library. Subscribes to the repository
/// stream and re-emits whenever the `materials` collection changes. Shared by
/// the admin Materials tab and (read-only) by the session dialog's material
/// picker.
class MaterialsCubit extends Cubit<MaterialsState> {
  MaterialsCubit({MaterialRepository? repository, String? creatorId, String? creatorEmail})
      : _repo = repository ??
            MaterialRepository(creatorId: creatorId, creatorEmail: creatorEmail),
        super(const MaterialsState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(materials: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('MaterialsCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final MaterialRepository _repo;
  late final StreamSubscription<List<TrainingMaterial>> _sub;

  /// Uploads a material zip. [onProgress] streams a 0..1 fraction. The list
  /// updates itself via the stream once the doc is written.
  Future<void> upload({
    required String title,
    required MaterialType type,
    required Uint8List bytes,
    required String fileName,
    bool hasExam = false,
    int? passThreshold,
    int? durationMinutes,
    void Function(double fraction)? onProgress,
  }) =>
      _repo.uploadMaterial(
        title: title,
        type: type,
        bytes: bytes,
        fileName: fileName,
        hasExam: hasExam,
        passThreshold: passThreshold,
        durationMinutes: durationMinutes,
        onProgress: onProgress,
      );

  Future<void> editMaterial(
    String id, {
    required String title,
    required MaterialType type,
    required bool hasExam,
    int? passThreshold,
    int? durationMinutes,
  }) =>
      _repo.editMaterial(
        id,
        title: title,
        type: type,
        hasExam: hasExam,
        passThreshold: passThreshold,
        durationMinutes: durationMinutes,
      );

  Future<void> deleteMaterial(TrainingMaterial material) =>
      _repo.deleteMaterial(material);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
