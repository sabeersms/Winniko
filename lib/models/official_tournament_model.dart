class OfficialTournamentModel {
  final String id;
  final String name;
  final String country;
  final String sport;
  final String? logoUrl;
  final String source; // e.g. 'fixturedownload'

  OfficialTournamentModel({
    required this.id,
    required this.name,
    required this.country,
    required this.sport,
    this.logoUrl,
    required this.source,
  });
}
