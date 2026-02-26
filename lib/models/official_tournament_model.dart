class OfficialTournamentModel {
  final String id;
  final String name;
  final String country;
  final String sport;
  final String? logoUrl;
  final String source; // e.g. 'fixturedownload' or 'cricapi'
  final String? externalId; // e.g. CricAPI ID or FixtureDownload Slug
  final String status; // 'active', 'finished'
  final bool hasFixtures; // Verified to have match data

  OfficialTournamentModel({
    required this.id,
    required this.name,
    required this.country,
    required this.sport,
    this.logoUrl,
    required this.source,
    this.externalId,
    this.status = 'active',
    this.hasFixtures = false,
  });
}
