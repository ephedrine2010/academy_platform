part of 'courses_cubit.dart';

class CoursesState extends Equatable {
  const CoursesState({
    required this.courses,
    this.selectedCourseId,
    this.lastStatusMessage,
  });

  final List<Course> courses;
  final String? selectedCourseId;

  /// Human-readable line shown in the player's status label, driven by the
  /// SCORM events coming from the package.
  final String? lastStatusMessage;

  Course? get selectedCourse {
    if (selectedCourseId == null) return null;
    for (final c in courses) {
      if (c.id == selectedCourseId) return c;
    }
    return null;
  }

  CoursesState copyWith({
    List<Course>? courses,
    String? selectedCourseId,
    bool clearSelection = false,
    String? lastStatusMessage,
  }) {
    return CoursesState(
      courses: courses ?? this.courses,
      selectedCourseId:
          clearSelection ? null : (selectedCourseId ?? this.selectedCourseId),
      lastStatusMessage: lastStatusMessage ?? this.lastStatusMessage,
    );
  }

  @override
  List<Object?> get props => [courses, selectedCourseId, lastStatusMessage];
}
