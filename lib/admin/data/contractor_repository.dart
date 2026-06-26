import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contractor.dart';

/// Firestore access for the `contractors` collection.
class ContractorRepository {
  ContractorRepository({FirebaseFirestore? firestore})
      : _col =
            (firestore ?? FirebaseFirestore.instance).collection('contractors');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<Contractor>> watch() => _col.orderBy('name').snapshots().map(
        (snap) => snap.docs.map(Contractor.fromDoc).toList(),
      );

  Future<void> add(Contractor c) => _col.add(c.toMap());

  Future<void> update(Contractor c) => _col.doc(c.id).update(c.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Drop a deleted region from every contractor that referenced it, so the
  /// many-to-many list never points at a region that no longer exists.
  Future<void> removeRegionFromAll(String regionId) async {
    final affected =
        await _col.where('regionIds', arrayContains: regionId).get();
    final batch = _col.firestore.batch();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {
        'regionIds': FieldValue.arrayRemove([regionId]),
      });
    }
    await batch.commit();
  }
}
