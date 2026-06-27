part of 'courses_cubit.dart';

class CoursesState extends Equatable {
  const CoursesState({
    this.courses = const [],
    this.loading = true,
    this.error,
  });

  final List<Course> courses;
  final bool loading;
  final String? error;

  CoursesState copyWith({
    List<Course>? courses,
    bool? loading,
    String? error,
  }) {
    return CoursesState(
      courses: courses ?? this.courses,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [courses, loading, error];
}
