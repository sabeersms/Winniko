import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/official_tournament_model.dart';
import 'teams_data_service.dart';
import 'firestore_service.dart';

class SportsApiService {
  // A curated list of high-quality feeds from fixturedownload.com
  // These are known to have full team lists and fixture data.
  static final List<OfficialTournamentModel> _curatedTournaments = [
    OfficialTournamentModel(
      id: 'epl-2025',
      name: 'Premier League 25/26',
      country: 'England',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/PL.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'champions-league-2025',
      name: 'UEFA Champions League 25/26',
      country: 'Europe',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/CL.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'mls-2026',
      name: 'Major League Soccer 2026',
      country: 'USA',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/MLS.png',
      source: 'fixturedownload',
    ),

    OfficialTournamentModel(
      id: 'la-liga-2025',
      name: 'La Liga 25/26',
      country: 'Spain',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/PD.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'bundesliga-2025',
      name: 'Bundesliga 25/26',
      country: 'Germany',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/BL1.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'serie-a-2025',
      name: 'Serie A 25/26',
      country: 'Italy',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/SA.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'ligue-1-2025',
      name: 'Ligue 1 25/26',
      country: 'France',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/FL1.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'afcon-2025',
      name: 'Africa Cup of Nations 2025',
      country: 'Africa',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),

    OfficialTournamentModel(
      id: 'eredivisie-2025',
      name: 'Eredivisie 25/26',
      country: 'Netherlands',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/ED.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'primeira-liga-2025',
      name: 'Primeira Liga 25/26',
      country: 'Portugal',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/PPL.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'super-lig-2025',
      name: 'Turkish Super Lig 25/26',
      country: 'Turkey',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'championship-2025',
      name: 'English Championship 25/26',
      country: 'England',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/ELC.png',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'aleague-men-2025',
      name: 'A-League Men 25/26',
      country: 'Australia',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
    // Cricket
    OfficialTournamentModel(
      id: 'bbl-2025',

      name: 'Big Bash League 25/26',
      country: 'Australia',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'mens-t20-world-cup-2026',
      name: 'ICC Men\'s T20 World Cup 2026',
      country: 'International',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'ipl-2025',
      name: 'IPL 2025',
      country: 'India',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
    OfficialTournamentModel(
      id: 'fifa-world-cup-2026',
      name: 'FIFA World Cup 2026',
      country: 'Global',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
    ),
  ];

  static Future<List<OfficialTournamentModel>> searchTournaments(
    String query,
  ) async {
    // 1. Get Curated Results
    final curatedResults = _curatedTournaments.where((t) {
      final q = query.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.country.toLowerCase().contains(q);
    }).toList();

    // 2. Get Discovered Results from Firestore (if permissions allow)
    // 2. Get Discovered Results from Firestore (now enabled)
    try {
      final firestore = FirestoreService();
      final discovered = await firestore.getDiscoveredTournaments();
      final filteredDiscovered = discovered.where((t) {
        final q = query.toLowerCase();
        final matchesQuery =
            t.name.toLowerCase().contains(q) ||
            t.country.toLowerCase().contains(q);
        // Avoid duplicates already in curated list
        final isNotCurated = !_curatedTournaments.any((c) => c.id == t.id);
        return matchesQuery && isNotCurated;
      }).toList();

      curatedResults.addAll(filteredDiscovered);
    } catch (e) {
      debugPrint('⚠️ Discovered tournaments fetch warning: $e');
    }

    return curatedResults;
  }

  /// Scrapes the source index for new leagues and saves them to Firestore
  static Future<void> syncNewlyAvailableTournaments(
    FirestoreService firestore,
  ) async {
    try {
      // Frequency Check: Only sync once every 3 days
      final lastSync = await firestore.getLastTournamentSyncAt();
      if (lastSync != null) {
        final difference = DateTime.now().difference(lastSync);
        if (difference.inDays < 3) {
          debugPrint(
            'Skipping search sync (Last sync: ${difference.inHours}h ago)',
          );
          return;
        }
      }

      const url = 'https://fixturedownload.com/index';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final html = response.body;
      final List<OfficialTournamentModel> discovered = [];

      // Simple regex-based extraction for 2025/2026 seasons
      // Format usually: <a href="/results/epl-2025">Premier League 2025/26</a>
      final regExp = RegExp(r'href="/results/([^"]+)"[^>]*>([^<]+)</a>');
      final matches = regExp.allMatches(html);

      for (var m in matches) {
        final id = m.group(1)!;
        final fullName = m.group(2)!;

        // Only interested in current/upcoming standard cycles
        if (id.contains('2025') || id.contains('2026')) {
          // Infer sport and country (Simplified logic for scraper)
          String sport = AppConstants.sportFootball;
          if (id.contains('cricket') ||
              id.contains('ipl') ||
              id.contains('bbl') ||
              id.contains('t20')) {
            sport = AppConstants.sportCricket;
          }

          discovered.add(
            OfficialTournamentModel(
              id: id,
              name: fullName,
              country: 'Global', // Scraper can't easily tell country from index
              sport: sport,
              logoUrl: 'https://crests.football-data.org/758.svg', // Generic
              source: 'fixturedownload',
            ),
          );
        }
      }

      if (discovered.isNotEmpty) {
        await firestore.saveDiscoveredTournaments(discovered);
        await firestore.updateTournamentSyncAt(DateTime.now());
        debugPrint(
          'Sync: Discovered ${discovered.length} potential tournaments.',
        );
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  static Future<List<Map<String, String>>> importTeams(String sourceId) async {
    final url = 'https://fixturedownload.com/feed/json/$sourceId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch teams from $sourceId');
    }

    final List<dynamic> matches = json.decode(response.body);
    final Set<String> teamNames = {};
    final List<Map<String, String>> teams = [];

    for (var match in matches) {
      final homeTeam = match['HomeTeam'] as String?;
      final awayTeam = match['AwayTeam'] as String?;

      if (homeTeam != null && teamNames.add(homeTeam)) {
        final resolvedName = TeamsDataService.resolveTeamName(
          sourceId,
          homeTeam,
        );
        teams.add({
          'name': resolvedName,
          'code': _generateCode(resolvedName),
          'logoUrl':
              TeamsDataService.getTeamAsset(resolvedName, leagueId: sourceId) ??
              '',
        });
      }
      if (awayTeam != null && teamNames.add(awayTeam)) {
        final resolvedName = TeamsDataService.resolveTeamName(
          sourceId,
          awayTeam,
        );
        teams.add({
          'name': resolvedName,
          'code': _generateCode(resolvedName),
          'logoUrl':
              TeamsDataService.getTeamAsset(resolvedName, leagueId: sourceId) ??
              '',
        });
      }
    }

    return teams..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMatches(
    String sourceId,
  ) async {
    final url = 'https://fixturedownload.com/feed/json/$sourceId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return [];

    final List<dynamic> allMatches = json.decode(response.body);
    final now = DateTime.now();

    // Sort and filter matches
    final List<Map<String, dynamic>> filtered = [];
    for (var m in allMatches) {
      DateTime time;
      try {
        time = DateTime.parse(
          m['DateUtc'].toString().replaceAll(' ', 'T') + 'Z',
        ).toLocal();
      } catch (e) {
        continue;
      }

      // We want LIVE (within 2 hours of start) or UPCOMING
      final diff = time.difference(now).inHours;
      if (diff >= -2 && diff < 48) {
        // Matches within next 2 days or just started
        filtered.add({
          'team1': m['HomeTeam'],
          'team2': m['AwayTeam'],
          'time': time,
          'leagueId': sourceId,
        });
      }
    }

    filtered.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    return filtered.take(5).toList(); // Show top 5
  }

  static String _generateCode(String name) {
    if (name.length <= 3) return name.toUpperCase();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] +
              parts[1][0] +
              (parts.length > 2 ? parts[2][0] : parts[1][1]))
          .toUpperCase();
    }
    return name.substring(0, 3).toUpperCase();
  }
}
