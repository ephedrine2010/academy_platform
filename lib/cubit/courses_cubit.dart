import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/course.dart';
import '../utils/log.dart';

part 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit()
      : super(
          const CoursesState(
            courses: [
              Course(
                id: 'golf',
                title: 'Golf Explained',
                assetRoot: 'assets/golf',
                launchFile: 'shared/launchpage.html',
              ),
            ],
          ),
        );

  /// User picked a course from the side list -> open it and mark in progress.
  void selectCourse(String id) {
    logCubit('selectCourse($id)');
    emit(
      state.copyWith(
        selectedCourseId: id,
        courses: _withStatus(id, CourseStatus.inProgress, onlyIfNotFinished: true),
        lastStatusMessage: 'Course opened — playing…',
      ),
    );
  }

  void closeCourse() {
    emit(state.copyWith(clearSelection: true));
  }

  /// Raw SCORM 1.2 `LMSSetValue` event coming from the package, bridged from the
  /// WebView. We only care about `cmi.core.lesson_status` for the POC.
  void onScormSetValue(String key, String value) {
    if (key != 'cmi.core.lesson_status') return;
    logCubit('lesson_status = "$value"');

    final selectedId = state.selectedCourseId;
    if (selectedId == null) return;

    switch (value) {
      case 'completed':
      case 'passed':
        emit(
          state.copyWith(
            courses: _withStatus(selectedId, CourseStatus.completed),
            lastStatusMessage: 'The user has finished this course ✓',
          ),
        );
        break;
      case 'failed':
        emit(
          state.copyWith(
            courses: _withStatus(selectedId, CourseStatus.failed),
            lastStatusMessage: 'The user finished the course but did not pass.',
          ),
        );
        break;
      case 'incomplete':
      case 'browsed':
        emit(
          state.copyWith(
            courses: _withStatus(selectedId, CourseStatus.inProgress,
                onlyIfNotFinished: true),
            lastStatusMessage: 'In progress…',
          ),
        );
        break;
    }
  }

  List<Course> _withStatus(
    String id,
    CourseStatus status, {
    bool onlyIfNotFinished = false,
  }) {
    return [
      for (final c in state.courses)
        if (c.id == id && !(onlyIfNotFinished && c.isFinished))
          c.copyWith(status: status)
        else
          c,
    ];
  }
}
