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
  final bool isMajor; // Flagged as a major tournament globally

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
    this.isMajor = false,
  });

  factory OfficialTournamentModel.fromMap(Map<String, dynamic> data) {
    return OfficialTournamentModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      country: data['country'] ?? '',
      sport: data['sport'] ?? '',
      logoUrl: data['logoUrl'],
      source: data['source'] ?? '',
      externalId: data['externalId'],
      status: data['status'] ?? 'active',
      hasFixtures: data['hasFixtures'] ?? false,
      isMajor: data['isMajor'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'sport': sport,
      'logoUrl': logoUrl,
      'source': source,
      'externalId': externalId,
      'status': status,
      'hasFixtures': hasFixtures,
      'isMajor': isMajor,
    };
  }
}
