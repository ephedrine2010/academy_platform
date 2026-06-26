import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A company region (East, West, Central, …). Stored in the `regions`
/// collection. The region↔trainer link lives on the trainer side
/// (`Trainer.regionNames`), so a region holds only its name here.
class Region extends Equatable {
  const Region({required this.id, required this.name});

  final String id;
  final String name;

  factory Region.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Region(id: doc.id, name: (data['name'] ?? '') as String);
  }

  Map<String, dynamic> toMap() => {'name': name};

  @override
  List<Object?> get props => [id, name];
}
