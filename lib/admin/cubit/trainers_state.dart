part of 'trainers_cubit.dart';

class TrainersState extends Equatable {
  const TrainersState({
    this.trainers = const [],
    this.loading = true,
    this.error,
  });

  final List<Trainer> trainers;
  final bool loading;
  final String? error;

  TrainersState copyWith({
    List<Trainer>? trainers,
    bool? loading,
    String? error,
  }) {
    return TrainersState(
      trainers: trainers ?? this.trainers,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [trainers, loading, error];
}
