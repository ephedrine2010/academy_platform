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
  CoursesCubit({CourseRepository? repository, String? creatorId, String? creatorEmail})
    : _repo = repository ??
          CourseRepository(creatorId: creatorId, creatorEmail: creatorEmail),
      super(const CoursesState()) {
    _sub = _repo.watch().listen(
      (list) => emit(state.copyWith(courses: list, loading: false)),
      onError: (Object e, StackTrace s) {
        logError('CoursesCubit.watch', e, s);
        emit(state.copyWith(loading: false, error: '$e'));
      },
    );
  }

  Future<void> addCourse(String name) => _repo.addCourse(name);

  final CourseRepository _repo;
  late final StreamSubscription<List<Course>> _sub;

  /// Loads a course's sessions on demand (when a course row is expanded).
  /// Read-only, so it returns a future rather than emitting state.
  Future<List<CourseSession>> loadSessions(String courseId) =>
      _repo.loadSessions(courseId);

  /// Loads a session's appointments + assigned instructor ids on demand (when a
  /// session row is expanded). Read-only, so it returns a future rather than
  /// emitting state.
  Future<SessionDetail> loadSession(String sessionId) =>
      _repo.loadSession(sessionId);

  // --- Admin writes (gated in the UI by isAdmin) -------------------------

  Future<void> addSession(
    String courseId, {
    required String name,
    required String description,
    required int order,
    List<int> trainees = const [],
  }) => _repo.addSession(
    courseId,
    name: name,
    description: description,
    order: order,
    trainees: trainees,
  );

  Future<void> addAppointment(
    String sessionId, {
    required DateTime date,
    required String location,
  }) => _repo.addAppointment(
    sessionId,
    date: date,
    location: location,
  );

  Future<void> editCourse(String courseId, {required String title}) =>
      _repo.editCourse(courseId, title: title);

  Future<void> deleteCourse(String courseId) => _repo.deleteCourse(courseId);

  Future<void> editSession(
    String sessionId, {
    required String name,
    required String description,
    required List<int> trainees,
  }) => _repo.editSession(
    sessionId,
    name: name,
    description: description,
    trainees: trainees,
  );

  Future<void> deleteSession(String sessionId) =>
      _repo.deleteSession(sessionId);

  Future<void> editAppointment(
    String sessionId,
    String appointmentId, {
    required DateTime date,
    required String location,
  }) => _repo.editAppointment(
    sessionId,
    appointmentId,
    date: date,
    location: location,
  );

  Future<void> deleteAppointment(String sessionId, String appointmentId) =>
      _repo.deleteAppointment(sessionId, appointmentId);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
