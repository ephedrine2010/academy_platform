import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One session of a course. Sessions are stored as **fields** on the course
/// document — the field *name* (the [key], e.g. `session1-Health360`) carries
/// an ordering prefix, and the field *value* is its [description] (e.g.
/// `about medicine`).
///
/// The sub-collection that holds the session's appointments + `assigned_trainer`
/// doc is named after the key **with the `sessionN-` prefix stripped** ([name],
/// e.g. `Health360`) — see [CourseRepository.loadSession].
class CourseSession extends Equatable {
  const CourseSession({
    required this.key,
    required this.name,
    required this.description,
  });

  /// Raw field name on the course doc, e.g. `session1-Health360`. Used for
  /// ordering.
  final String key;

  /// Sub-collection / display name, e.g. `Health360` (the [key] with any
  /// leading `sessionN-` prefix removed).
  final String name;
  final String description;

  static final _orderPrefix = RegExp(r'^session\d+-', caseSensitive: false);

  factory CourseSession.fromField(String key, Object? value) {
    return CourseSession(
      key: key,
      name: key.replaceFirst(_orderPrefix, ''),
      description: '${value ?? ''}',
    );
  }

  @override
  List<Object?> get props => [key, name, description];
}

/// A course loaded from the Firestore `courses` collection.
///
/// Each document is one course; its **document id is the course title key**
/// (e.g. `care360`). A `title` field is used as the display name when present,
/// otherwise the document id is shown. Every *other* top-level field is treated
/// as a [CourseSession] (field name → session, field value → description).
class Course extends Equatable {
  const Course({required this.id, required this.title, this.sessions = const []});

  /// Reserved field names that are course metadata, not sessions.
  static const _reservedKeys = {'title'};

  /// Firestore document id (the course title key, e.g. `care360`).
  final String id;

  /// Display title — the `title` field, falling back to [id].
  final String title;

  /// This course's sessions, derived from the document's non-reserved fields.
  final List<CourseSession> sessions;

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final title = (data['title'] ?? '') as String;

    final sessions = <CourseSession>[];
    for (final entry in data.entries) {
      if (_reservedKeys.contains(entry.key)) continue;
      sessions.add(CourseSession.fromField(entry.key, entry.value));
    }
    // Field order isn't guaranteed; sort by the raw key so `session1…`
    // precedes `session2…`.
    sessions.sort((a, b) => a.key.compareTo(b.key));

    return Course(
      id: doc.id,
      title: title.trim().isNotEmpty ? title : doc.id,
      sessions: sessions,
    );
  }

  @override
  List<Object?> get props => [id, title, sessions];
}
