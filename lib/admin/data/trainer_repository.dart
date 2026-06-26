import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trainer.dart';

/// Firestore access for trainers. Trainers are stored in the shared `admins`
/// collection and identified by their `role` (`admin02`); managers (`admin01`)
/// live in the same collection but are excluded here.
class TrainerRepository {
  TrainerRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('admins');

  final CollectionReference<Map<String, dynamic>> _col;

  /// Only `admin02` docs are trainers. We filter by role and sort by name
  /// client-side, which avoids needing a composite (role + name) Firestore
  /// index.
  Stream<List<Trainer>> watch() =>
      _col.where('role', isEqualTo: Trainer.role).snapshots().map((snap) {
        final list = snap.docs.map(Trainer.fromDoc).toList();
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return list;
      });

  /// Use the trainer's company id as the Firestore document id.
  Future<void> add(Trainer t) => _col.doc(t.trainerId).set(t.toMap());

  Future<void> update(Trainer t) => _col.doc(t.id).update(t.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Drop a deleted region from every trainer that referenced it, so the
  /// many-to-many list never points at a region that no longer exists.
  Future<void> removeRegionFromAll(String regionName) async {
    final affected =
        await _col.where('regionNames', arrayContains: regionName).get();
    final batch = _col.firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {
        'regionNames': FieldValue.arrayRemove([regionName]),
      });
    }
    await batch.commit();
  }

  /// Replace an old region name with its new one on every trainer, so a region
  /// rename stays in sync with the names stored on the trainer side.
  Future<void> renameRegionInAll(String oldName, String newName) async {
    if (oldName == newName) return;
    final affected =
        await _col.where('regionNames', arrayContains: oldName).get();
    final batch = _col.firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {
        'regionNames': FieldValue.arrayRemove([oldName]),
      });
      batch.update(doc.reference, {
        'regionNames': FieldValue.arrayUnion([newName]),
      });
    }
    await batch.commit();
  }
}
