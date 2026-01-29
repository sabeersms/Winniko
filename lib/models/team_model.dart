import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String shortName;
  final String? logoUrl;
  final String competitionId;
  final DateTime createdAt;
  final String? group;
  final String? competitionName;

  TeamModel({
    required this.id,
    required this.name,
    required this.shortName,
    this.logoUrl,
    required this.competitionId,
    required this.createdAt,
    this.group,
    this.competitionName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'logoUrl': logoUrl,
      'competitionId': competitionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'group': group,
      'competitionName': competitionName,
    };
  }

  factory TeamModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TeamModel(
      id: documentId,
      name: map['name'] ?? '',
      shortName: map['shortName'] ?? '',
      logoUrl: map['logoUrl'],
      competitionId: map['competitionId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      group: map['group'],
      competitionName: map['competitionName'],
    );
  }

  factory TeamModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return TeamModel.fromMap(data, snapshot.id);
  }
  TeamModel copyWith({
    String? id,
    String? name,
    String? shortName,
    String? logoUrl,
    String? competitionId,
    DateTime? createdAt,
    String? group,
    String? competitionName,
  }) {
    return TeamModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      logoUrl: logoUrl ?? this.logoUrl,
      competitionId: competitionId ?? this.competitionId,
      createdAt: createdAt ?? this.createdAt,
      group: group ?? this.group,
      competitionName: competitionName ?? this.competitionName,
    );
  }
}
