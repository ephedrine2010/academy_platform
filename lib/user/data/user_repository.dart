import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../../courses/models/course.dart';
import '../models/assigned_session.dart';

/// Firestore access for the signed-in **trainee** (the `users` collection).
///
/// A trainee doc is keyed by their int id as a string (`users/1111`) and holds
/// `id`, `email`, `name`, and an `assigned_sessions` array of **session doc
/// ids**. That reverse link is maintained by `CourseRepository` whenever an
/// admin assigns/unassigns a trainee on a session.
///
/// The home screen shows the trainee's **sessions** (not courses), so this
/// resolves each assigned session id to its `sessions` doc, then fetches each
/// distinct parent course once for its display title.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection('courses');

  /// Loads the sessions the trainee with [email] is assigned to.
  ///
  /// 1. `users where email == <email>` (limit 1) → read `assigned_sessions`.
  /// 2. Fetch each session doc (skipping ids that no longer exist).
  /// 3. Fetch each distinct parent course once for its title.
  /// Sorted by course title, then the session's `order`.
  Future<List<AssignedSession>> loadAssignedSessions(String email) async {
    // Match the role lookup's normalization (auth_cubit lower-cases too): the
    // Firebase login email can come back in a different case than the hand-typed
    // `users.email`, and Firestore equality is case-sensitive.
    final needle = email.trim().toLowerCase();
    logCourse('loadAssignedSessions → users where email == "$needle"');
    final userSnap =
        await _users.where('email', isEqualTo: needle).limit(1).get();
    if (userSnap.docs.isEmpty) {
      logCourse('  ✗ no users doc matched email "$needle"');
      return const [];
    }

    final userDoc = userSnap.docs.first;
    final userData = userDoc.data();
    logCourse('  ✓ matched users/${userDoc.id} → fields: $userData');

    // Read `assigned_sessions` defensively: accept elements whether Firestore
    // stored them as strings or numbers, since a session DOC id is always a
    // string ("9876543210") but the value could have been written either way.
    final raw = userData['assigned_sessions'];
    logCourse('  assigned_sessions raw = $raw (runtimeType: ${raw.runtimeType})');
    final sessionIds = (raw is List)
        ? raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    logCourse('  assigned_sessions parsed ids = $sessionIds');

    // Resolve each assigned session id to its doc.
    final sessions = <CourseSession>[];
    for (final id in sessionIds) {
      final doc = await _sessions.doc(id).get();
      logCourse('  fetch /sessions/$id → exists=${doc.exists}');
      if (!doc.exists) {
        logCourse('  ⚠ session "$id" not found — skipping');
        continue;
      }
      logCourse('    session "$id" fields: ${doc.data()}');
      sessions.add(CourseSession.fromDoc(doc));
    }

    // Resolve each distinct parent course once for its title.
    final titles = <String, String>{};
    for (final courseId in sessions.map((s) => s.courseDocId).whereType<String>().toSet()) {
      final doc = await _courses.doc(courseId).get();
      final title = (doc.data()?['title'] as String?)?.trim();
      titles[courseId] = (title != null && title.isNotEmpty) ? title : courseId;
    }

    final result = [
      for (final s in sessions)
        AssignedSession(
          session: s,
          courseTitle: titles[s.courseDocId] ?? '—',
        ),
    ]..sort((a, b) {
        final byCourse = a.courseTitle.compareTo(b.courseTitle);
        return byCourse != 0 ? byCourse : a.session.order.compareTo(b.session.order);
      });

    logCourse('  resolved ${result.length} assigned session(s) for "$email"');
    return result;
  }
}
