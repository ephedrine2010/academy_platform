import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// How a session is delivered. Drives whether it needs a material and how
/// completion is measured (see the training-materials brainstorm). Onboarding
/// paths are deferred, so they are not a value here yet.
///
/// - [physical] — in-person, appointments + attendance; **no material**.
/// - [selfPaced] — online, watch anytime; **requires a material**.
/// - [webinar] — attend at a time (usually optional); material optional.
enum SessionType {
  physical,
  selfPaced,
  webinar;

  static SessionType fromKey(String? key) {
    switch (key) {
      case 'selfPaced':
        return SessionType.selfPaced;
      case 'webinar':
        return SessionType.webinar;
      case 'physical':
      default:
        return SessionType.physical;
    }
  }

  String get key => name;

  String get label {
    switch (this) {
      case SessionType.physical:
        return 'Physical (in-person)';
      case SessionType.selfPaced:
        return 'Self-paced';
      case SessionType.webinar:
        return 'Webinar';
    }
  }

  /// Whether a material may be attached. Physical sessions carry none.
  bool get usesMaterial => this != SessionType.physical;

  /// Whether a material is mandatory (self-paced can't be delivered without one).
  bool get requiresMaterial => this == SessionType.selfPaced;
}

/// One session of a course. Sessions are stored as **documents in a top-level
/// `sessions` collection** (`sessions/{id}`), linked to their course by a
/// `course_id` field (= the course document id). The document id is the
/// generated 10-digit [sessionId] (not the name — names can repeat across
/// courses). That session's appointments + `assigned_instructor` doc live in a
/// nested `appointments` sub-collection (see [CourseRepository.loadSession]).
class CourseSession extends Equatable {
  const CourseSession({
    required this.id,
    required this.name,
    required this.description,
    this.courseDocId,
    this.sessionId,
    this.order = 0,
    this.trainees = const [],
    this.deliveryType = SessionType.physical,
    this.materialId,
  });

  /// Firestore document id within the `sessions` collection (== the generated
  /// `session_id`).
  final String id;

  /// Display name, e.g. `Health360`.
  final String name;
  final String description;

  /// The parent course's document id (the `course_id` field, e.g. `care360`).
  /// Used to resolve a session back to its course. Null for malformed docs.
  final String? courseDocId;

  /// Stable 10-digit numeric id (the `session_id` field). Null for legacy docs.
  final int? sessionId;

  /// 1-based ordering position (the `order` field) used to sort the list.
  final int order;

  /// Int ids of the trainees assigned to this session (the `trainees` array).
  /// This is the source of truth for "who is in this session"; each trainee's
  /// `users` doc mirrors the reverse link in its `assigned_sessions` array.
  final List<int> trainees;

  /// How this session is delivered (the `delivery_type` field). Legacy sessions
  /// with no field default to [SessionType.physical] (they're in-person).
  final SessionType deliveryType;

  /// The attached material's document id (the `material_id` field), or null for
  /// physical sessions / sessions with no material yet.
  final String? materialId;

  factory CourseSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CourseSession(
      id: doc.id,
      name: (data['name'] ?? doc.id).toString(),
      description: (data['description'] ?? '').toString(),
      courseDocId: (data['course_id'] as String?),
      sessionId: (data['session_id'] as num?)?.toInt(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      trainees: _intList(data['trainees']),
      deliveryType: SessionType.fromKey(data['delivery_type'] as String?),
      materialId: (data['material_id'] as String?),
    );
  }

  static List<int> _intList(dynamic value) {
    if (value is List) {
      return value.whereType<num>().map((n) => n.toInt()).toList();
    }
    return const [];
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        courseDocId,
        sessionId,
        order,
        trainees,
        deliveryType,
        materialId,
      ];
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
