class ExternalFixtureModel {
  final int matchNumber;
  final int roundNumber;
  final String dateUtc;
  final String location;
  final String homeTeam;
  final String awayTeam;
  final String? group;
  final int? homeTeamScore;
  final int? awayTeamScore;

  ExternalFixtureModel({
    required this.matchNumber,
    required this.roundNumber,
    required this.dateUtc,
    required this.location,
    required this.homeTeam,
    required this.awayTeam,
    this.group,
    this.homeTeamScore,
    this.awayTeamScore,
  });

  factory ExternalFixtureModel.fromJson(Map<String, dynamic> json) {
    return ExternalFixtureModel(
      matchNumber: json['MatchNumber'] ?? json['Match Number'] ?? 0,
      roundNumber: json['RoundNumber'] ?? json['Round Number'] ?? 0,
      dateUtc: json['DateUtc'] ?? json['Date UTC'] ?? '',
      location: json['Location'] ?? '',
      homeTeam: json['HomeTeam'] ?? json['Home Team'] ?? '',
      awayTeam: json['AwayTeam'] ?? json['Away Team'] ?? '',
      group: json['Group'],
      homeTeamScore: json['HomeTeamScore'] ?? json['Home Team Score'],
      awayTeamScore: json['AwayTeamScore'] ?? json['Away Team Score'],
    );
  }
}
