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
    required this.assetRoot,
    required this.launchFile,
    this.status = CourseStatus.notStarted,
  });

  final String id;
  final String title;

  /// Folder in the asset bundle, e.g. `assets/golf`.
  final String assetRoot;

  /// Launch document relative to [assetRoot], e.g. `shared/launchpage.html`.
  final String launchFile;

  final CourseStatus status;

  bool get isFinished =>
      status == CourseStatus.completed || status == CourseStatus.failed;

  Course copyWith({CourseStatus? status}) {
    return Course(
      id: id,
      title: title,
      assetRoot: assetRoot,
      launchFile: launchFile,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, title, assetRoot, launchFile, status];
}
