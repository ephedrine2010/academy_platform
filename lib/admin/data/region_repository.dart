import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/region.dart';

/// Firestore access for the `regions` collection.
class RegionRepository {
  RegionRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('regions');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<Region>> watch() => _col.orderBy('name').snapshots().map(
        (snap) => snap.docs.map(Region.fromDoc).toList(),
      );

  /// Use the region name as the Firestore document id.
  Future<void> add(String name) => _col.doc(name).set({'name': name});

  Future<void> rename(String id, String name) =>
      _col.doc(id).update({'name': name});

  Future<void> delete(String id) => _col.doc(id).delete();
}
