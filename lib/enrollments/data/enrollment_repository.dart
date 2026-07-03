import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academy/utils/log.dart';
import '../../courses/models/course.dart';
import '../models/enrollment.dart';

/// Firestore access for the top-level **`enrollments`** collection
/// (`enrollments/{sessionId}_{userId}`). One record per (trainee × session);
/// see the training-materials brainstorm §9.
///
/// Two sides:
/// - **Assignment** ([syncSessionEnrollments] / [removeSessionEnrollments]) —
///   called from the admin flow to pre-create / prune records as trainees are
///   assigned. Never overwrites a trainee's progress.
/// - **Trainee** ([watchForTrainee] / [markStarted] / [updateProgress]) — the
///   trainee's own list and progress writes.
class EnrollmentRepository {
  EnrollmentRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('enrollments');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _materials =>
      _db.collection('materials');

  static String docId(String sessionId, int userId) => '${sessionId}_$userId';

  // --- Assignment side (called from CourseRepository) --------------------

  /// Reconciles this session's enrollments against its current trainee roster.
  ///
  /// - If the session doesn't carry a material (physical, or no material yet),
  ///   removes any enrollments for it — attendance-only sessions keep using the
  ///   existing appointment flow, not enrollments (for now).
  /// - Otherwise: pre-creates a `notStarted` record for each assigned trainee
  ///   (idempotent — existing records keep their progress), refreshes the
  ///   denormalized display fields, and prunes records for trainees no longer
  ///   assigned.
  Future<void> syncSessionEnrollments({
    required String sessionId,
    required String? courseId,
    required SessionType deliveryType,
    required String? materialId,
    required String sessionName,
    required List<int> traineeIds,
  }) async {
    final existing = await _col.where('session_id', isEqualTo: sessionId).get();

    final usesMaterial = deliveryType.usesMaterial && materialId != null;
    if (!usesMaterial) {
      if (existing.docs.isNotEmpty) {
        logCourse('enrollments: session $sessionId has no material → pruning '
            '${existing.docs.length} record(s)');
        await _deleteAll(existing.docs);
      }
      return;
    }

    // One read for the denormalized display / exam fields (same for everyone).
    final matSnap = await _materials.doc(materialId).get();
    final mat = matSnap.data() ?? const {};
    final title = (mat['title'] as String?)?.trim();
    final displayTitle =
        (title != null && title.isNotEmpty) ? title : sessionName;
    final hasExam = mat['has_exam'] == true;
    final passThreshold = (mat['pass_threshold'] as num?)?.toInt();

    final existingIds = {
      for (final d in existing.docs) (d.data()['user_id'] as num?)?.toInt(),
    };

    for (final traineeId in traineeIds) {
      final ref = _col.doc(docId(sessionId, traineeId));
      if (existingIds.contains(traineeId)) {
        // Keep progress; just refresh denormalized fields.
        await ref.set({
          'material_id': materialId,
          'title': displayTitle,
          'has_exam': hasExam,
          'pass_threshold': passThreshold,
          'delivery_type': deliveryType.key,
          'course_id': courseId,
        }, SetOptions(merge: true));
      } else {
        logCourse('enrollments: pre-create ${ref.id} (notStarted)');
        await ref.set({
          'user_id': traineeId,
          'session_id': sessionId,
          'course_id': courseId,
          'delivery_type': deliveryType.key,
          'material_id': materialId,
          'title': displayTitle,
          'lifecycle_state': LifecycleState.notStarted.key,
          'outcome': null,
          'progress': 0,
          'has_exam': hasExam,
          'pass_threshold': passThreshold,
          'mandatory': true,
          'attempts': 0,
          'assigned_at': FieldValue.serverTimestamp(),
        });
      }
    }

    // Prune records for trainees no longer assigned.
    final assigned = traineeIds.toSet();
    final stale = existing.docs.where(
      (d) => !assigned.contains((d.data()['user_id'] as num?)?.toInt()),
    );
    for (final d in stale) {
      logCourse('enrollments: prune ${d.id} (unassigned)');
      await d.reference.delete();
    }
  }

  /// Deletes every enrollment for a session (called when the session is deleted).
  Future<void> removeSessionEnrollments(String sessionId) async {
    final snap = await _col.where('session_id', isEqualTo: sessionId).get();
    if (snap.docs.isEmpty) return;
    logCourse('enrollments: remove ${snap.docs.length} for session $sessionId');
    await _deleteAll(snap.docs);
  }

  Future<void> _deleteAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = _db.batch();
    for (final d in docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // --- Trainee side ------------------------------------------------------

  /// Resolves a trainee's int id from their sign-in [email] (their `users` doc
  /// id), or null when no doc matches. Mirrors `UserRepository`'s lookup.
  Future<int?> resolveTraineeId(String email) async {
    final needle = email.trim().toLowerCase();
    final snap = await _users.where('email', isEqualTo: needle).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return int.tryParse(doc.id) ?? (doc.data()['id'] as num?)?.toInt();
  }

  /// Live list of a trainee's enrollments (`where user_id == traineeId`), sorted
  /// client-side (title) so no composite index is needed.
  Stream<List<Enrollment>> watchForTrainee(int traineeId) {
    return _col.where('user_id', isEqualTo: traineeId).snapshots().map((snap) {
      final list = snap.docs.map(Enrollment.fromDoc).toList();
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return list;
    });
  }

  /// Marks an enrollment started (notStarted → inProgress) when the trainee
  /// opens it, stamping timestamps. Safe to call repeatedly.
  Future<void> markStarted(String enrollmentId) {
    return _col.doc(enrollmentId).set({
      // Only bump to inProgress from notStarted; a done record stays done.
      'lifecycle_state': LifecycleState.inProgress.key,
      'started_at': FieldValue.serverTimestamp(),
      'last_accessed_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists SCORM progress (used by the web player in a later slice). Writes
  /// the bookmark + suspend data so Resume works, and the derived state/outcome.
  Future<void> updateProgress(
    String enrollmentId, {
    required int progress,
    required LifecycleState lifecycleState,
    EnrollmentOutcome outcome = EnrollmentOutcome.none,
    int? score,
    String? lessonLocation,
    String? suspendData,
  }) {
    return _col.doc(enrollmentId).set({
      'progress': progress.clamp(0, 100),
      'lifecycle_state': lifecycleState.key,
      'outcome': outcome.key,
      if (score != null) 'score': score,
      if (lessonLocation != null) 'lesson_location': lessonLocation,
      if (suspendData != null) 'suspend_data': suspendData,
      'last_accessed_at': FieldValue.serverTimestamp(),
      if (lifecycleState == LifecycleState.done)
        'completed_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
