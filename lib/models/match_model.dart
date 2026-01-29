import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String competitionId;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final String? team1LogoUrl;
  final String? team2LogoUrl;
  final DateTime scheduledTime;
  final Map<String, dynamic>?
  actualScore; // e.g., {'team1': 2} or {'winnerId': '...', 'marginType': 'runs', 'marginValue': '11-20'}
  final String status; // 'upcoming', 'live', 'completed'
  final String? winnerId;
  final String? round; // e.g., 'Round 1', 'Quarter Final'
  final String? group; // e.g., 'Group A'
  final int? matchNumber;
  final String? location; // e.g. 'Old Trafford'

  MatchModel({
    required this.id,
    required this.competitionId,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    this.team1LogoUrl,
    this.team2LogoUrl,
    required this.scheduledTime,
    this.actualScore,
    required this.status,
    this.winnerId,
    this.round,
    this.group,
    this.matchNumber,
    this.location,
  });

  MatchModel copyWith({
    String? id,
    String? competitionId,
    String? team1Id,
    String? team2Id,
    String? team1Name,
    String? team2Name,
    String? team1LogoUrl,
    String? team2LogoUrl,
    DateTime? scheduledTime,
    Map<String, dynamic>? actualScore,
    String? status,
    String? winnerId,
    String? round,
    String? group,
    int? matchNumber,
    String? location,
  }) {
    return MatchModel(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      team1Id: team1Id ?? this.team1Id,
      team2Id: team2Id ?? this.team2Id,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      team1LogoUrl: team1LogoUrl ?? this.team1LogoUrl,
      team2LogoUrl: team2LogoUrl ?? this.team2LogoUrl,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actualScore: actualScore ?? this.actualScore,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      round: round ?? this.round,
      group: group ?? this.group,
      matchNumber: matchNumber ?? this.matchNumber,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'competitionId': competitionId,
      'team1Id': team1Id,
      'team2Id': team2Id,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'team1LogoUrl': team1LogoUrl,
      'team2LogoUrl': team2LogoUrl,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'actualScore': actualScore,
      'status': status,
      'winnerId': winnerId,
      'round': round,
      'group': group,
      'matchNumber': matchNumber,
      'location': location,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      competitionId: map['competitionId'] ?? '',
      team1Id: map['team1Id'] ?? '',
      team2Id: map['team2Id'] ?? '',
      team1Name: map['team1Name'] ?? '',
      team2Name: map['team2Name'] ?? '',
      team1LogoUrl: map['team1LogoUrl'],
      team2LogoUrl: map['team2LogoUrl'],
      scheduledTime: (map['scheduledTime'] as Timestamp).toDate(),
      actualScore: map['actualScore'] != null
          ? Map<String, dynamic>.from(map['actualScore'])
          : null,
      status: map['status'] ?? 'upcoming',
      winnerId: map['winnerId'],
      round: map['round'],
      group: map['group'],
      matchNumber: map['matchNumber'],
      location: map['location'],
    );
  }

  factory MatchModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return MatchModel.fromMap(data, snapshot.id);
  }

  bool get isUpcoming => status == 'upcoming';
  bool get isLive => status == 'live';
  bool get isCompleted => status == 'completed';
  bool get isPredictionLocked => DateTime.now().isAfter(scheduledTime);
}
