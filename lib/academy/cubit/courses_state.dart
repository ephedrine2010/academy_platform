part of 'courses_cubit.dart';

class CoursesState extends Equatable {
  const CoursesState({
    required this.courses,
    this.selectedCourseId,
    this.lastStatusMessage,
    this.isLoading = false,
    this.loadError,
  });

  final List<Course> courses;
  final String? selectedCourseId;

  /// Human-readable line shown in the player's status label, driven by the
  /// SCORM events coming from the package.
  final String? lastStatusMessage;

  /// True while the courses folder is being scanned.
  final bool isLoading;

  /// Set when scanning the courses folder failed.
  final String? loadError;

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
    bool? isLoading,
    String? loadError,
    bool clearError = false,
  }) {
    return CoursesState(
      courses: courses ?? this.courses,
      selectedCourseId:
          clearSelection ? null : (selectedCourseId ?? this.selectedCourseId),
      lastStatusMessage: lastStatusMessage ?? this.lastStatusMessage,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearError ? null : (loadError ?? this.loadError),
    );
  }

  @override
  List<Object?> get props => [
        courses,
        selectedCourseId,
        lastStatusMessage,
        isLoading,
        loadError,
      ];
}
