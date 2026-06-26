import 'package:equatable/equatable.dart';

/// Where the learner stands on a course, derived from the SCORM
/// `cmi.core.lesson_status` reported by the package.
enum CourseStatus {
  notStarted,
  inProgress,
  completed, // completed / passed
  failed;

  String get label {
    switch (this) {
      case CourseStatus.notStarted:
        return 'Not started';
      case CourseStatus.inProgress:
        return 'In progress';
      case CourseStatus.completed:
        return 'Completed';
      case CourseStatus.failed:
        return 'Failed';
    }
  }
}

class Course extends Equatable {
  const Course({
    required this.id,
    required this.title,
    required this.basePath,
    required this.launchFile,
    this.status = CourseStatus.notStarted,
  });

  final String id;
  final String title;

  /// The course folder's base location, interpreted by the [CourseRepository]
  /// that produced it: an absolute filesystem path for a local course (e.g.
  /// `D:/.../assets/courses/golf`), or the folder's path within the shared
  /// OneDrive folder for a remote course (e.g. `golf`).
  final String basePath;

  /// Launch document relative to [basePath], e.g. `shared/launchpage.html`.
  final String launchFile;

  final CourseStatus status;

  bool get isFinished =>
      status == CourseStatus.completed || status == CourseStatus.failed;

  Course copyWith({CourseStatus? status}) {
    return Course(
      id: id,
      title: title,
      basePath: basePath,
      launchFile: launchFile,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, title, basePath, launchFile, status];
}
