import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A trainer (regional manager / instructor — the admin02 role). Stored in the
/// `trainers` collection. [trainerId] is the trainer's company/staff id (free
/// text, distinct from the Firestore document [id]). [regionNames] is the
/// single source of truth for the many-to-many region assignment and stores
/// region **names** directly (e.g. `central`) rather than document ids.
class Trainer extends Equatable {
  /// The `admins.role` value that marks a doc as a trainer. Trainers live in the
  /// `admins` collection alongside managers (`admin01`) and are told apart by
  /// this role.
  static const String role = 'admin02';

  const Trainer({
    required this.id,
    required this.trainerId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.regionNames,
  });

  final String id;
  final String trainerId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final List<String> regionNames;

  factory Trainer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Trainer(
      id: doc.id,
      trainerId: (data['trainerId'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      regionNames:
          List<String>.from((data['regionNames'] ?? const []) as List),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'trainerId': trainerId,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'regionNames': regionNames,
      };

  Trainer copyWith({
    String? trainerId,
    String? name,
    String? email,
    String? phone,
    String? address,
    List<String>? regionNames,
  }) {
    return Trainer(
      id: id,
      trainerId: trainerId ?? this.trainerId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      regionNames: regionNames ?? this.regionNames,
    );
  }

  @override
  List<Object?> get props =>
      [id, trainerId, name, email, phone, address, regionNames];
}
