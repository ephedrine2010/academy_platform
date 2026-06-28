import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One session of a course. Sessions are stored as **documents** in the course's
/// `sessions` sub-collection (`courses/{courseId}/sessions/{id}`). The document
/// id is the session [name]; that session's appointments + `assigned_trainer`
/// doc live in a nested `appointments` sub-collection (see
/// [CourseRepository.loadSession]).
class CourseSession extends Equatable {
  const CourseSession({
    required this.id,
    required this.name,
    required this.description,
    this.sessionId,
    this.order = 0,
  });

  /// Firestore document id within the `sessions` sub-collection (== [name]).
  final String id;

  /// Display name, e.g. `Health360`.
  final String name;
  final String description;

  /// Stable 10-digit numeric id (the `session_id` field). Null for legacy docs.
  final int? sessionId;

  /// 1-based ordering position (the `order` field) used to sort the list.
  final int order;

  factory CourseSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CourseSession(
      id: doc.id,
      name: (data['name'] ?? doc.id).toString(),
      description: (data['description'] ?? '').toString(),
      sessionId: (data['session_id'] as num?)?.toInt(),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, description, sessionId, order];
}

/// A course loaded from the Firestore `courses` collection.
///
/// Each document is one course; its **document id is the course title key**
/// (e.g. `care360`). A `title` field is used as the display name when present,
/// otherwise the document id is shown. This course's sessions live in a
/// `sessions` sub-collection that is loaded on demand — see
/// [CourseRepository.loadSessions] — so they are **not** part of this model.
class Course extends Equatable {
  const Course({required this.id, required this.title, this.courseId});

  /// Firestore document id (the course title key, e.g. `care360`).
  final String id;

  /// Stable 10-digit numeric id (the `course_id` field). Null for legacy
  /// courses created before ids existed.
  final int? courseId;

  /// Display title — the `title` field, falling back to [id].
  final String title;

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final title = (data['title'] ?? '') as String;
    return Course(
      id: doc.id,
      courseId: (data['course_id'] as num?)?.toInt(),
      title: title.trim().isNotEmpty ? title : doc.id,
    );
  }

  @override
  List<Object?> get props => [id, courseId, title];
}
