import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// An instructor (regional manager / instructor — the admin02 role). Stored in
/// the `admins` collection. [instructorId] is the instructor's company/staff id (free
/// text, distinct from the Firestore document [id]). [regionNames] is the
/// single source of truth for the many-to-many region assignment and stores
/// region **names** directly (e.g. `central`) rather than document ids.
class Instructor extends Equatable {
  /// The `admins.role` value that marks a doc as an instructor. Instructors live in the
  /// `admins` collection alongside managers (`admin01`) and are told apart by
  /// this role.
  static const String role = 'admin02';

  const Instructor({
    required this.id,
    required this.instructorId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.regionNames,
  });

  final String id;
  final String instructorId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final List<String> regionNames;

  factory Instructor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Instructor(
      id: doc.id,
      instructorId: (data['instructorId'] ?? '') as String,
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
        'instructorId': instructorId,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'regionNames': regionNames,
      };

  Instructor copyWith({
    String? instructorId,
    String? name,
    String? email,
    String? phone,
    String? address,
    List<String>? regionNames,
  }) {
    return Instructor(
      id: id,
      instructorId: instructorId ?? this.instructorId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      regionNames: regionNames ?? this.regionNames,
    );
  }

  @override
  List<Object?> get props =>
      [id, instructorId, name, email, phone, address, regionNames];
}
