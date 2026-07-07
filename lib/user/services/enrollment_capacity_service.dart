import 'package:cloud_firestore/cloud_firestore.dart';

import '../../courses/models/appointment.dart';

/// Thrown when a trainee tries to enroll into an appointment that is already
/// at capacity. The UI turns it into a "this appointment is full" message.
class AppointmentFullException implements Exception {
  const AppointmentFullException();

  @override
  String toString() => 'This appointment is full.';
}

/// The one place that owns appointment **capacity** rules for self-enrollment.
///
/// Capacity is the optional `capacity` field on an appointment (null =
/// unlimited); the number already enrolled is `enrolled_trainees.length`. Two
/// pure helpers ([isFull] / [remainingSeats]) answer questions about an
/// already-loaded [Appointment] (used by the UI), and [ensureHasSeat] goes to
/// Firestore to read the **live** count right before a write (used by the repo).
///
/// The check is intentionally a plain read-then-compare — **not** a transaction
/// — so under heavy concurrency an appointment can occasionally overshoot its
/// cap by one or two. That is an accepted trade-off; wrap [ensureHasSeat] +
/// the enroll write in a transaction if it ever needs to be strict.
class EnrollmentCapacityService {
  /// Pass [db] in tests; production uses [FirebaseFirestore.instance] lazily so
  /// the pure helpers stay usable without touching Firebase (and `const`).
  const EnrollmentCapacityService({FirebaseFirestore? db}) : _injectedDb = db;

  final FirebaseFirestore? _injectedDb;

  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  /// Whether [a] has reached its capacity. Always false when uncapped.
  bool isFull(Appointment a) {
    final cap = a.capacity;
    return cap != null && a.enrolledTraineeIds.length >= cap;
  }

  /// Seats still open, or null when the appointment is uncapped.
  int? remainingSeats(Appointment a) {
    final cap = a.capacity;
    if (cap == null) return null;
    final left = cap - a.enrolledTraineeIds.length;
    return left < 0 ? 0 : left;
  }

  /// Reads the appointment fresh from Firestore and throws
  /// [AppointmentFullException] if it is already at capacity. This is the single
  /// place that goes to Firebase to check the live enrolled count before an
  /// enroll write. A missing appointment is treated as "has room" (no guard).
  Future<void> ensureHasSeat(String sessionId, String appointmentId) async {
    final doc = await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('appointments')
        .doc(appointmentId)
        .get();
    if (doc.exists && isFull(Appointment.fromDoc(doc))) {
      throw const AppointmentFullException();
    }
  }
}
