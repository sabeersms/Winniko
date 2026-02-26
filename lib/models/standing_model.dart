class StandingModel {
  final String teamId;
  final String teamName;
  final String? teamLogoUrl;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final int tied;
  final int noResult;
  final double netRunRate;
  final String? group; // e.g., 'Group A'

  StandingModel({
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.points = 0,
    this.tied = 0,
    this.noResult = 0,
    this.netRunRate = 0.0,
    this.group,
    this.oversFaced = 0.0,
    this.oversBowled = 0.0,
  });

  // Intermediate helper fields for NRR calculation (not necessarily displayed)
  final double oversFaced;
  final double oversBowled;

  int get goalDifference => goalsFor - goalsAgainst;

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'teamLogoUrl': teamLogoUrl,
      'played': played,
      'won': won,
      'drawn': drawn,
      'lost': lost,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'points': points,
      'tied': tied,
      'noResult': noResult,
      'netRunRate': netRunRate,
      'group': group,
      'oversFaced': oversFaced,
      'oversBowled': oversBowled,
    };
  }

  StandingModel copyWith({
    String? teamId,
    String? teamName,
    String? teamLogoUrl,
    int? played,
    int? won,
    int? drawn,
    int? lost,
    int? goalsFor,
    int? goalsAgainst,
    int? points,
    int? tied,
    int? noResult,
    double? netRunRate,
    String? group,
    double? oversFaced,
    double? oversBowled,
  }) {
    return StandingModel(
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      teamLogoUrl: teamLogoUrl ?? this.teamLogoUrl,
      played: played ?? this.played,
      won: won ?? this.won,
      drawn: drawn ?? this.drawn,
      lost: lost ?? this.lost,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      points: points ?? this.points,
      tied: tied ?? this.tied,
      noResult: noResult ?? this.noResult,
      netRunRate: netRunRate ?? this.netRunRate,
      group: group ?? this.group,
      oversFaced: oversFaced ?? this.oversFaced,
      oversBowled: oversBowled ?? this.oversBowled,
    );
  }

  factory StandingModel.fromMap(Map<String, dynamic> map) {
    return StandingModel(
      teamId: map['teamId'] ?? '',
      teamName: map['teamName'] ?? '',
      teamLogoUrl: map['teamLogoUrl'],
      played: (map['played'] ?? 0) is num ? (map['played'] as num).toInt() : 0,
      won: (map['won'] ?? 0) is num ? (map['won'] as num).toInt() : 0,
      drawn: (map['drawn'] ?? 0) is num ? (map['drawn'] as num).toInt() : 0,
      lost: (map['lost'] ?? 0) is num ? (map['lost'] as num).toInt() : 0,
      goalsFor: (map['goalsFor'] ?? 0) is num
          ? (map['goalsFor'] as num).toInt()
          : 0,
      goalsAgainst: (map['goalsAgainst'] ?? 0) is num
          ? (map['goalsAgainst'] as num).toInt()
          : 0,
      points: (map['points'] ?? 0) is num ? (map['points'] as num).toInt() : 0,
      tied: (map['tied'] ?? 0) is num ? (map['tied'] as num).toInt() : 0,
      noResult: (map['noResult'] ?? 0) is num
          ? (map['noResult'] as num).toInt()
          : 0,
      netRunRate: (map['netRunRate'] ?? 0.0).toDouble(),
      group: map['group'],
      oversFaced: (map['oversFaced'] ?? 0.0).toDouble(),
      oversBowled: (map['oversBowled'] ?? 0.0).toDouble(),
    );
  }
}
