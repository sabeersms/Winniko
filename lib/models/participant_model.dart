class ParticipantModel {
  final String userId;
  final String userName;
  final String? photoUrl;
  final String? phoneNumber;
  final String competitionId;
  final int totalPoints;
  final int rank;
  final int perfectScores; // Exact score matches
  final int correctOutcomes; // Correct result (W/D/L) but wrong score
  final int totalPredictions;
  final DateTime joinedAt;

  ParticipantModel({
    required this.userId,
    required this.userName,
    this.photoUrl,
    this.phoneNumber,
    required this.competitionId,
    this.totalPoints = 0,
    this.rank = 0,
    this.perfectScores = 0,
    this.correctOutcomes = 0,
    this.totalPredictions = 0,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'competitionId': competitionId,
      'totalPoints': totalPoints,
      'rank': rank,
      'perfectScores': perfectScores,
      'correctOutcomes': correctOutcomes,
      'totalPredictions': totalPredictions,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory ParticipantModel.fromMap(Map<String, dynamic> map) {
    return ParticipantModel(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      competitionId: map['competitionId'] ?? '',
      totalPoints: map['totalPoints'] ?? 0,
      rank: map['rank'] ?? 0,
      perfectScores: map['perfectScores'] ?? 0,
      correctOutcomes: map['correctOutcomes'] ?? 0,
      totalPredictions: map['totalPredictions'] ?? 0,
      joinedAt: DateTime.parse(map['joinedAt']),
    );
  }

  ParticipantModel copyWith({
    String? userId,
    String? userName,
    String? photoUrl,
    String? phoneNumber,
    String? competitionId,
    int? totalPoints,
    int? rank,
    int? perfectScores,
    int? correctOutcomes,
    int? totalPredictions,
    DateTime? joinedAt,
  }) {
    return ParticipantModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      competitionId: competitionId ?? this.competitionId,
      totalPoints: totalPoints ?? this.totalPoints,
      rank: rank ?? this.rank,
      perfectScores: perfectScores ?? this.perfectScores,
      correctOutcomes: correctOutcomes ?? this.correctOutcomes,
      totalPredictions: totalPredictions ?? this.totalPredictions,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
