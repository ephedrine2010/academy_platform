import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/course_repository.dart';
import '../models/course.dart';
import '../models/session_detail.dart';

part 'courses_state.dart';

/// Live list of courses from the Firestore `courses` collection. Subscribes to
/// the repository stream and re-emits whenever the collection changes. Shared by
/// the admin Courses tab and the trainee Home / Courses / Schedule screens.
class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit({CourseRepository? repository})
      : _repo = repository ?? CourseRepository(),
        super(const CoursesState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(courses: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('CoursesCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  final CourseRepository _repo;
  late final StreamSubscription<List<Course>> _sub;

  /// Loads a session's appointments + assigned trainer ids on demand (when a
  /// session row is expanded). Read-only, so it returns a future rather than
  /// emitting state.
  Future<SessionDetail> loadSession(String courseId, String sessionName) =>
      _repo.loadSession(courseId, sessionName);

  // --- Admin writes (gated in the UI by isAdmin) -------------------------

  Future<void> addCourse(String name) => _repo.addCourse(name);

  Future<void> addSession(
    String courseId, {
    required String name,
    required String description,
    required int order,
  }) =>
      _repo.addSession(courseId,
          name: name, description: description, order: order);

  Future<void> addAppointment(
    String courseId,
    String sessionName, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) =>
      _repo.addAppointment(courseId, sessionName,
          date: date, location: location, trainerIds: trainerIds);

  Future<void> editCourse(String courseId, {required String title}) =>
      _repo.editCourse(courseId, title: title);

  Future<void> deleteCourse(String courseId, List<String> sessionNames) =>
      _repo.deleteCourse(courseId, sessionNames);

  Future<void> editSession(
    String courseId, {
    required String key,
    required String description,
  }) =>
      _repo.editSession(courseId, key: key, description: description);

  Future<void> deleteSession(
    String courseId, {
    required String key,
    required String sessionName,
  }) =>
      _repo.deleteSession(courseId, key: key, sessionName: sessionName);

  Future<void> editAppointment(
    String courseId,
    String sessionName,
    String appointmentId, {
    required DateTime date,
    required String location,
    required List<int> trainerIds,
  }) =>
      _repo.editAppointment(courseId, sessionName, appointmentId,
          date: date, location: location, trainerIds: trainerIds);

  Future<void> deleteAppointment(
    String courseId,
    String sessionName,
    String appointmentId,
  ) =>
      _repo.deleteAppointment(courseId, sessionName, appointmentId);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
