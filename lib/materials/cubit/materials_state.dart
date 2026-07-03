part of 'materials_cubit.dart';

/// State for the shared material library list.
class MaterialsState extends Equatable {
  const MaterialsState({
    this.materials = const [],
    this.loading = true,
    this.error,
  });

  final List<TrainingMaterial> materials;
  final bool loading;
  final String? error;

  MaterialsState copyWith({
    List<TrainingMaterial>? materials,
    bool? loading,
    String? error,
  }) {
    return MaterialsState(
      materials: materials ?? this.materials,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [materials, loading, error];
}
