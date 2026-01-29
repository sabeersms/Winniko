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
  });

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
    };
  }

  factory StandingModel.fromMap(Map<String, dynamic> map) {
    return StandingModel(
      teamId: map['teamId'] ?? '',
      teamName: map['teamName'] ?? '',
      teamLogoUrl: map['teamLogoUrl'],
      played: map['played'] ?? 0,
      won: map['won'] ?? 0,
      drawn: map['drawn'] ?? 0,
      lost: map['lost'] ?? 0,
      goalsFor: map['goalsFor'] ?? 0,
      goalsAgainst: map['goalsAgainst'] ?? 0,
      points: map['points'] ?? 0,
      tied: map['tied'] ?? 0,
      noResult: map['noResult'] ?? 0,
      netRunRate: (map['netRunRate'] ?? 0.0).toDouble(),
      group: map['group'],
    );
  }
}
