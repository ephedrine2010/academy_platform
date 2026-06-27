import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/course_repository.dart';
import '../data/onedrive_config.dart';
import '../data/onedrive_course_repository.dart';
import '../data/scorm_file_source.dart';
import '../models/course.dart';
import '../../../academy/utils/log.dart';

part 'courses_state.dart';

class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit({CourseRepository? repository, String? accessToken})
      : _repo = repository ?? _defaultRepo(accessToken),
        super(const CoursesState(courses: [], isLoading: true));

  final CourseRepository _repo;

  /// Reads courses from the shared OneDrive folder when one is configured and
  /// we have an access token to authorize Graph; otherwise falls back to the
  /// local `assets/courses/` folder.
  static CourseRepository _defaultRepo(String? accessToken) {
    if (OneDriveConfig.isConfigured &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      logCubit('Using OneDrive course repository');
      return OneDriveCourseRepository(
        accessToken: accessToken,
        shareUrl: OneDriveConfig.shareUrl,
      );
    }
    logCubit('Using local disk course repository');
    return DiskCourseRepository();
  }

  /// The file source a [ScormPlayer] uses to play [course] — disk or OneDrive,
  /// matching whichever repository discovered the course.
  ScormFileSource sourceFor(Course course) => _repo.sourceFor(course);

  /// Scans the courses folder on disk and rebuilds the course list. Safe to
  /// call again to pick up newly dropped-in course folders.
  Future<void> loadCourses() async {
    logCubit('loadCourses()');
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final courses = await _repo.loadCourses();
      logCubit('loaded ${courses.length} course(s)');
      emit(
        state.copyWith(
          courses: courses,
          isLoading: false,
          // Drop a selection that no longer exists after a rescan.
          clearSelection:
              !courses.any((c) => c.id == state.selectedCourseId),
        ),
      );
    } catch (e, s) {
      logError('CoursesCubit.loadCourses', e, s);
      emit(state.copyWith(isLoading: false, loadError: e.toString()));
    }
  }

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
