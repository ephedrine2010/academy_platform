import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../academy/utils/log.dart';
import '../models/training_material.dart';

/// Firestore + Storage access for the shared **material library**.
///
/// Model: `materials/{id}` where the doc id is the generated 10-digit
/// `material_id` (as a string). The uploaded `.zip` is stored in Firebase
/// Storage at `materials/{id}/{fileName}` and its path is recorded on the doc
/// (`storage_path`).
///
/// The library is **unscoped** — [watch] returns *every* material so any admin
/// can attach any material to any session. [creatorEmail] is stamped on new
/// uploads for audit only; it does not filter the listing.
class MaterialRepository {
  MaterialRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    this.creatorId,
    this.creatorEmail,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// Uploader identity, stamped on new materials (audit only — the library is
  /// shared, not scoped by creator).
  final String? creatorId;
  final String? creatorEmail;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('materials');

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  static final _rng = Random();

  /// A random 10-digit positive integer, used as the stable `material_id` and
  /// document id (matches the id scheme used for courses / sessions).
  static int _newId() {
    final buf = StringBuffer(1 + _rng.nextInt(9)); // first digit 1-9
    for (var i = 0; i < 9; i++) {
      buf.write(_rng.nextInt(10));
    }
    return int.parse(buf.toString());
  }

  /// One-shot read of a single material (for the trainee viewer, which needs the
  /// `entry_point` + `status`). Null when the doc is missing.
  Future<TrainingMaterial?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return TrainingMaterial.fromDoc(snap);
  }

  /// Live list of every material in the library, newest first. Sorting is done
  /// client-side so no index is needed on `created_at`.
  Stream<List<TrainingMaterial>> watch() {
    return _col.snapshots().map((snap) {
      logCourse('materials collection → ${snap.docs.length} document(s)');
      final list = snap.docs.map(TrainingMaterial.fromDoc).toList();
      // Newest first by numeric id when present (ids are random, so this is a
      // rough proxy for recency; upload order isn't otherwise stored).
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return list;
    });
  }

  /// Uploads a material zip to Storage then writes its `materials` doc.
  ///
  /// [bytes] are the raw zip bytes (on web, `PlatformFile.bytes`). [onProgress]
  /// is called with a 0..1 fraction as the upload streams. Returns the new
  /// document id. The Firestore doc is written **first** (status `uploaded`),
  /// then the zip is uploaded — so the Storage-triggered unzip
  /// (`processMaterialUpload`) fires against an existing doc and its
  /// `status`/`entry_point` writes are never clobbered by this client write.
  Future<String> uploadMaterial({
    required String title,
    required MaterialType type,
    required Uint8List bytes,
    required String fileName,
    bool hasExam = false,
    int? passThreshold,
    int? durationMinutes,
    void Function(double fraction)? onProgress,
  }) async {
    final materialId = _newId();
    final id = materialId.toString();
    final safeName = _safeFileName(fileName);
    final storagePath = 'materials/$id/$safeName';

    // 1. Write the doc first, so the Storage trigger has something to update.
    logCourse('uploadMaterial → writing /materials/$id (status: uploaded)');
    await _col.doc(id).set({
      'material_id': materialId,
      'title': title.trim(),
      'type': type.key,
      'storage_path': storagePath,
      'file_name': fileName,
      'size_bytes': bytes.length,
      'has_exam': hasExam,
      if (hasExam && passThreshold != null) 'pass_threshold': passThreshold,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      // Upload year, set automatically — the coarse library filter.
      'year': DateTime.now().year,
      'status': 'uploaded',
      'created_at': FieldValue.serverTimestamp(),
      if (creatorId != null) 'created_by': creatorId,
      if (creatorEmail != null) 'created_by_email': creatorEmail,
    });

    // 2. Upload the zip — this finalize event triggers processMaterialUpload,
    //    which flips status → processing → ready|failed and adds entry_point.
    logCourse('uploadMaterial → uploading $storagePath (${bytes.length} bytes)');
    final ref = _storage.ref(storagePath);
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/zip'),
    );
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        onProgress?.call(s.bytesTransferred / s.totalBytes);
      }
    });
    await task;
    return id;
  }

  /// Updates a material's editable metadata (not the uploaded file).
  Future<void> editMaterial(
    String id, {
    required String title,
    required MaterialType type,
    required bool hasExam,
    int? passThreshold,
    int? durationMinutes,
  }) {
    logCourse('editMaterial → /materials/$id');
    return _col.doc(id).set({
      'title': title.trim(),
      'type': type.key,
      'has_exam': hasExam,
      'pass_threshold': hasExam ? passThreshold : null,
      'duration_minutes': durationMinutes,
    }, SetOptions(merge: true));
  }

  /// How many sessions currently point at this material (`material_id == id`).
  /// Used to guard deletion — a shared material must not vanish from under a
  /// session that still uses it.
  Future<int> sessionUsageCount(String id) async {
    final snap =
        await _sessions.where('material_id', isEqualTo: id).count().get();
    return snap.count ?? 0;
  }

  /// Deletes a material's Storage object and its doc. Throws [StateError] if any
  /// session still uses it (call [sessionUsageCount] first to warn the admin).
  Future<void> deleteMaterial(TrainingMaterial material) async {
    final uses = await sessionUsageCount(material.id);
    if (uses > 0) {
      throw StateError(
        'This material is used by $uses session(s). Remove it from those '
        'sessions before deleting it.',
      );
    }
    logCourse('deleteMaterial → /materials/${material.id}');
    if (material.storagePath.isNotEmpty) {
      try {
        await _storage.ref(material.storagePath).delete();
      } on FirebaseException catch (e) {
        // Object already gone — the doc delete below still cleans up.
        logCourse('  storage delete skipped: ${e.code}');
      }
    }
    await _col.doc(material.id).delete();
  }

  /// Strips path separators / odd characters so the stored object name is safe.
  static String _safeFileName(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'package.zip' : cleaned;
  }
}
