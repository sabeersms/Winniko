import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionModel {
  final String id;
  final String userId;
  final String matchId;
  final String competitionId;
  final Map<String, dynamic>
  prediction; // {'team1': 2, 'team2': 1} or {'winnerId': '...', 'marginType': 'runs', 'marginValue': '11-20'}
  final DateTime timestamp;
  final int? points; // Null if not yet scored
  final bool isScored;
  final bool wasPerfectScore;
  final bool wasCorrectOutcome;
  final String? tieBreakerWinnerId;

  PredictionModel({
    this.id = '',
    required this.userId,
    required this.matchId,
    required this.competitionId,
    required this.prediction,
    required this.timestamp,
    this.points,
    this.isScored = false,
    this.wasPerfectScore = false,
    this.wasCorrectOutcome = false,
    this.tieBreakerWinnerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'matchId': matchId,
      'competitionId': competitionId,
      'prediction': prediction,
      'timestamp': Timestamp.fromDate(timestamp),
      'points': points,
      'isScored': isScored,
      'wasPerfectScore': wasPerfectScore,
      'wasCorrectOutcome': wasCorrectOutcome,
      'tieBreakerWinnerId': tieBreakerWinnerId,
    };
  }

  factory PredictionModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return PredictionModel(
      id: snapshot.id,
      userId: data['userId'] ?? '',
      matchId: data['matchId'] ?? '',
      competitionId: data['competitionId'] ?? '',
      prediction: Map<String, dynamic>.from(data['prediction'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      points: data['points'],
      isScored: data['isScored'] ?? false,
      wasPerfectScore: data['wasPerfectScore'] ?? false,
      wasCorrectOutcome: data['wasCorrectOutcome'] ?? false,
      tieBreakerWinnerId: data['tieBreakerWinnerId'],
    );
  }

  PredictionModel copyWith({
    String? id,
    String? userId,
    String? matchId,
    String? competitionId,
    Map<String, dynamic>? prediction,
    DateTime? timestamp,
    int? points,
    bool? isScored,
    bool? wasPerfectScore,
    bool? wasCorrectOutcome,
    String? tieBreakerWinnerId,
  }) {
    return PredictionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      competitionId: competitionId ?? this.competitionId,
      prediction: prediction ?? this.prediction,
      timestamp: timestamp ?? this.timestamp,
      points: points ?? this.points,
      isScored: isScored ?? this.isScored,
      wasPerfectScore: wasPerfectScore ?? this.wasPerfectScore,
      wasCorrectOutcome: wasCorrectOutcome ?? this.wasCorrectOutcome,
      tieBreakerWinnerId: tieBreakerWinnerId ?? this.tieBreakerWinnerId,
    );
  }
}
