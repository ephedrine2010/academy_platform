part of 'contractors_cubit.dart';

class ContractorsState extends Equatable {
  const ContractorsState({
    this.contractors = const [],
    this.loading = true,
    this.error,
  });

  final List<Contractor> contractors;
  final bool loading;
  final String? error;

  ContractorsState copyWith({
    List<Contractor>? contractors,
    bool? loading,
    String? error,
  }) {
    return ContractorsState(
      contractors: contractors ?? this.contractors,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [contractors, loading, error];
}
