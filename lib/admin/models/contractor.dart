import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A contractor (regional manager / instructor). Stored in the `contractors`
/// collection. [regionIds] is the single source of truth for the many-to-many
/// region assignment — re-assigning a contractor is just editing this list.
class Contractor extends Equatable {
  const Contractor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.regionIds,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final List<String> regionIds;

  factory Contractor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Contractor(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      regionIds: List<String>.from((data['regionIds'] ?? const []) as List),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'regionIds': regionIds,
      };

  Contractor copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    List<String>? regionIds,
  }) {
    return Contractor(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      regionIds: regionIds ?? this.regionIds,
    );
  }

  @override
  List<Object?> get props => [id, name, email, phone, address, regionIds];
}
