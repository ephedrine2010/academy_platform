import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../courses/models/course.dart';

/// Where a trainee is in a piece of work — the same three states for every
/// delivery type (content or attendance).
enum LifecycleState {
  notStarted,
  inProgress,
  done;

  static LifecycleState fromKey(String? key) {
    switch (key) {
      case 'inProgress':
        return LifecycleState.inProgress;
      case 'done':
        return LifecycleState.done;
      case 'notStarted':
      default:
        return LifecycleState.notStarted;
    }
  }

  String get key => name;
}

/// The engine-specific result. `none` while not yet resolved. Content types end
/// on passed/failed; attendance types on attended/absent.
enum EnrollmentOutcome {
  none,
  passed,
  failed,
  attended,
  absent;

  static EnrollmentOutcome fromKey(String? key) {
    switch (key) {
      case 'passed':
        return EnrollmentOutcome.passed;
      case 'failed':
        return EnrollmentOutcome.failed;
      case 'attended':
        return EnrollmentOutcome.attended;
      case 'absent':
        return EnrollmentOutcome.absent;
      default:
        return EnrollmentOutcome.none;
    }
  }

  String? get key => this == EnrollmentOutcome.none ? null : name;
}

/// One record per **(trainee × session)** in the top-level `enrollments`
/// collection. The document id is `"{sessionId}_{userId}"` so assignment is
/// idempotent (a trainee can't be enrolled twice) and existence is a direct
/// `get`, not a query.
///
/// It is both the assignment fact and the progress ledger, and spans both
/// completion engines (content + attendance). See the training-materials
/// brainstorm §9. For this slice only content types (self-paced) are created
/// and surfaced; SCORM resume fields are written once the web player lands.
class Enrollment extends Equatable {
  const Enrollment({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.deliveryType,
    this.materialId,
    this.title = '',
    this.courseId,
    this.lifecycleState = LifecycleState.notStarted,
    this.outcome = EnrollmentOutcome.none,
    this.progress = 0,
    this.score,
    this.hasExam = false,
    this.passThreshold,
    this.mandatory = true,
    this.lessonLocation,
    this.suspendData,
    this.attempts = 0,
  });

  /// Document id (`"{sessionId}_{userId}"`).
  final String id;

  /// The trainee's int id (their `users` doc id) — matches `session.trainees`.
  final int userId;

  /// The session this enrollment is for.
  final String sessionId;

  /// The parent course doc id, denormalized for grouping / display.
  final String? courseId;

  /// How the session is delivered (drives which UI + engine applies).
  final SessionType deliveryType;

  /// The attached material's id (content types).
  final String? materialId;

  /// Display title, denormalized at assignment (material title, else session
  /// name). May drift if the material is re-titled — acceptable for now.
  final String title;

  final LifecycleState lifecycleState;
  final EnrollmentOutcome outcome;

  /// 0..100 percent complete (content types).
  final int progress;

  /// Exam score 0..100, or null when no exam / not yet scored.
  final int? score;

  final bool hasExam;
  final int? passThreshold;
  final bool mandatory;

  /// SCORM bookmark (`cmi.core.lesson_location`) — restored by Resume. Written
  /// by the player (later slice).
  final String? lessonLocation;

  /// SCORM `cmi.suspend_data` — restored by Resume. Written by the player.
  final String? suspendData;

  final int attempts;

  bool get isDone => lifecycleState == LifecycleState.done;
  bool get isStarted => lifecycleState != LifecycleState.notStarted;

  /// Whether the trainee can pick up where they left off (has a bookmark).
  bool get canResume => isStarted && !isDone;

  factory Enrollment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Enrollment(
      id: doc.id,
      userId: (data['user_id'] as num?)?.toInt() ?? 0,
      sessionId: (data['session_id'] ?? '').toString(),
      courseId: data['course_id'] as String?,
      deliveryType: SessionType.fromKey(data['delivery_type'] as String?),
      materialId: data['material_id'] as String?,
      title: (data['title'] ?? '').toString(),
      lifecycleState: LifecycleState.fromKey(data['lifecycle_state'] as String?),
      outcome: EnrollmentOutcome.fromKey(data['outcome'] as String?),
      progress: (data['progress'] as num?)?.toInt() ?? 0,
      score: (data['score'] as num?)?.toInt(),
      hasExam: data['has_exam'] == true,
      passThreshold: (data['pass_threshold'] as num?)?.toInt(),
      mandatory: data['mandatory'] != false,
      lessonLocation: data['lesson_location'] as String?,
      suspendData: data['suspend_data'] as String?,
      attempts: (data['attempts'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        sessionId,
        courseId,
        deliveryType,
        materialId,
        title,
        lifecycleState,
        outcome,
        progress,
        score,
        hasExam,
        passThreshold,
        mandatory,
        lessonLocation,
        suspendData,
        attempts,
      ];
}
