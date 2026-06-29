part of 'instructors_cubit.dart';

class InstructorsState extends Equatable {
  const InstructorsState({
    this.instructors = const [],
    this.loading = true,
    this.error,
  });

  final List<Instructor> instructors;
  final bool loading;
  final String? error;

  InstructorsState copyWith({
    List<Instructor>? instructors,
    bool? loading,
    String? error,
  }) {
    return InstructorsState(
      instructors: instructors ?? this.instructors,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [instructors, loading, error];
}
