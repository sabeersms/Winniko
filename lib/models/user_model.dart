import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String phone;
  final String name;
  final String? photoUrl;
  final GeoPoint location;
  final String? address;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.phone,
    required this.name,
    this.photoUrl,
    required this.location,
    this.address,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'name': name,
      'photoUrl': photoUrl,
      'location': location,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      location: map['location'] ?? const GeoPoint(0, 0),
      address: map['address'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, snapshot.id);
  }

  // CopyWith method for updates
  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? name,
    String? photoUrl,
    GeoPoint? location,
    String? address,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
