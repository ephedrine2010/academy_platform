part of 'regions_cubit.dart';

class RegionsState extends Equatable {
  const RegionsState({
    this.regions = const [],
    this.loading = true,
    this.error,
  });

  final List<Region> regions;
  final bool loading;
  final String? error;

  RegionsState copyWith({
    List<Region>? regions,
    bool? loading,
    String? error,
  }) {
    return RegionsState(
      regions: regions ?? this.regions,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [regions, loading, error];
}
