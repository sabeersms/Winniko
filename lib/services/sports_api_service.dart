import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/official_tournament_model.dart';
import 'teams_data_service.dart';
import 'firestore_service.dart';
import 'cric_api_service.dart';

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
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'champions-league-2025',
      name: 'UEFA Champions League 25/26',
      country: 'Europe',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/CL.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'mls-2026',
      name: 'Major League Soccer 2026',
      country: 'USA',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/MLS.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),

    OfficialTournamentModel(
      id: 'la-liga-2025',
      name: 'La Liga 25/26',
      country: 'Spain',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/PD.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'bundesliga-2025',
      name: 'Bundesliga 25/26',
      country: 'Germany',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/BL1.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'serie-a-2025',
      name: 'Serie A 25/26',
      country: 'Italy',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/SA.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'ligue-1-2025',
      name: 'Ligue 1 25/26',
      country: 'France',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/FL1.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'afcon-2025',
      name: 'Africa Cup of Nations 2025',
      country: 'Africa',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
      status: 'finished', // Ended Feb 2025
    ),

    OfficialTournamentModel(
      id: 'eredivisie-2025',
      name: 'Eredivisie 25/26',
      country: 'Netherlands',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/ED.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'primeira-liga-2025',
      name: 'Primeira Liga 25/26',
      country: 'Portugal',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/PPL.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'super-lig-2025',
      name: 'Turkish Super Lig 25/26',
      country: 'Turkey',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'championship-2025',
      name: 'English Championship 25/26',
      country: 'England',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/ELC.png',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'aleague-men-2025',
      name: 'A-League Men 25/26',
      country: 'Australia',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'isl-2025',
      name: 'Indian Super League 25/26',
      country: 'India',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'manual',
      hasFixtures: true,
    ),
    // Cricket
    OfficialTournamentModel(
      id: 'bbl-2025',

      name: 'Big Bash League 25/26',
      country: 'Australia',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'mens-t20-world-cup-2026',
      name: 'ICC Men\'s T20 World Cup 2026',
      country: 'International',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'ipl-2025',
      name: 'IPL 2025',
      country: 'India',
      sport: AppConstants.sportCricket,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
    OfficialTournamentModel(
      id: 'fifa-world-cup-2026',
      name: 'FIFA World Cup 2026',
      country: 'Global',
      sport: AppConstants.sportFootball,
      logoUrl: 'https://crests.football-data.org/758.svg',
      source: 'fixturedownload',
      hasFixtures: true,
    ),
  ];

  static Future<List<OfficialTournamentModel>> searchTournaments(
    String query,
  ) async {
    // 1. Get Curated Results — only active (ongoing/upcoming) tournaments
    final curatedResults = _curatedTournaments.where((t) {
      final q = query.toLowerCase();
      final matchesSearch =
          t.name.toLowerCase().contains(q) ||
          t.country.toLowerCase().contains(q);
      return matchesSearch && t.hasFixtures && t.status != 'finished';
    }).toList();

    // 2. Get Discovered Results from Firestore (now enabled) + Apply Blacklist
    try {
      final firestore = FirestoreService();

      // Fetch blacklist first
      final blacklist = await firestore.getBlacklistedTournamentIds();

      final discovered = await firestore.getDiscoveredTournaments();

      final filteredDiscovered = discovered.where((t) {
        if (blacklist.contains(t.id)) return false; // Filter blacklisted

        final q = query.toLowerCase();
        final matchesQuery =
            t.name.toLowerCase().contains(q) ||
            t.country.toLowerCase().contains(q);
        // Avoid duplicates already in curated list
        final isNotCurated = !_curatedTournaments.any((c) => c.id == t.id);
        return matchesQuery && isNotCurated;
      }).toList();

      // Also filter curated results against blacklist
      curatedResults.removeWhere((t) => blacklist.contains(t.id));

      curatedResults.addAll(filteredDiscovered);
    } catch (e) {
      debugPrint('⚠️ Discovered tournaments fetch warning: $e');
    }

    return curatedResults;
  }

  /// Live-scrapes the source index to find tournaments not yet in our database.
  /// Useful for the "Discovery" feature.
  static Future<List<OfficialTournamentModel>> discoverNewTournamentsExternal(
    String query,
  ) async {
    try {
      const url = 'https://fixturedownload.com/index';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final html = response.body;
      final List<OfficialTournamentModel> results = [];
      final q = query.toLowerCase();

      // Better scraping: Identify blocks starting with <h4> which contain the league name
      // Example: <h4>EPL</h4> ... <span><a href="/results/epl-2025">2025/26</a></span>
      final blockRegExp = RegExp(
        r'<h4>([^<]+)</h4>(.*?)(?=<h4>|</div>|$)',
        dotAll: true,
      );
      final blocks = blockRegExp.allMatches(html);

      for (var block in blocks) {
        final leagueName = block.group(1)!.trim();
        final content = block.group(2)!;

        // Find links within this league's block
        final linkRegExp = RegExp(r'href="/results/([^"]+)"[^>]*>([^<]+)</a>');
        final links = linkRegExp.allMatches(content);

        for (var l in links) {
          final id = l.group(1)!;
          String seasonText = l.group(2)!;
          String cleanedLeague = leagueName
              .replaceAll('&#39;', "'")
              .replaceAll('&amp;', '&')
              .trim();
          String cleanedSeason = seasonText
              .replaceAll('&#39;', "'")
              .replaceAll('&amp;', '&')
              .trim();
          final fullName = '$cleanedLeague $cleanedSeason';

          // Apply filters
          if (q.isNotEmpty &&
              !fullName.toLowerCase().contains(q) &&
              !id.toLowerCase().contains(q)) {
            continue;
          }

          // Focus on current/future seasons
          if (id.contains('2024') ||
              id.contains('2025') ||
              id.contains('2026')) {
            // Infer sport (Improved logic)
            String sport = AppConstants.sportFootball;
            final lowerId = id.toLowerCase();
            final lowerName = fullName.toLowerCase();

            if (lowerId.contains('cricket') ||
                lowerId.contains('ipl') ||
                lowerId.contains('t20') ||
                lowerId.contains('odi') ||
                lowerId.contains('test') ||
                lowerId.contains('psl') ||
                lowerId.contains('bbl') ||
                lowerId.contains('cpl') ||
                lowerId.contains('lpl') ||
                lowerId.contains('smash') ||
                lowerName.contains('cricket')) {
              sport = AppConstants.sportCricket;
            }

            results.add(
              OfficialTournamentModel(
                id: id,
                name: fullName,
                country: 'Global',
                sport: sport,
                logoUrl: 'https://crests.football-data.org/758.svg',
                source: 'fixturedownload',
              ),
            );
          }
        }
      }

      // Limit results to avoid overwhelming UI
      return results.take(50).toList();
    } catch (e) {
      debugPrint('External Discovery Error: $e');
      return [];
    }
  }

  /// Scrapes the source index for new leagues and saves them to Firestore
  static Future<void> syncNewlyAvailableTournaments(
    FirestoreService firestore,
  ) async {
    try {
      // --- PHASE 1: ATOMIC LOCKING ---
      // Instead of simple date check, we use a transaction-based lock
      final hasLock = await firestore.tryAcquireTournamentSyncLock();
      if (!hasLock) {
        debugPrint('Sync: Lock denied (Sync already in progress or too soon)');
        return;
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
              id.contains('t20') ||
              id.contains('odi') ||
              id.contains('-test') ||
              id.contains('psl') ||
              id.contains('cpl') ||
              id.contains('sa20') ||
              id.contains('wbbl') ||
              id.contains('lpl') ||
              id.contains('hundred')) {
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

      // --- PHASE 2: DIFFERENTIAL DISCOVERY ---
      // Get IDs already in Firestore so we don't re-verify them
      final existingTournaments = await firestore.getDiscoveredTournaments();
      final existingIds = existingTournaments.map((t) => t.id).toSet();

      final List<OfficialTournamentModel> newLeagues = [];
      for (var t in discovered) {
        if (!existingIds.contains(t.id) &&
            !_curatedTournaments.any((c) => c.id == t.id)) {
          newLeagues.add(t);
        }
      }

      if (newLeagues.isNotEmpty) {
        // --- PHASE 3: VERIFICATION (Only for BRAND NEW IDs) ---
        final List<OfficialTournamentModel> verified = [];

        debugPrint(
          'Verifying fixtures for ${newLeagues.length} NEW leagues...',
        );

        for (var t in newLeagues) {
          try {
            final checkUrl = 'https://fixturedownload.com/feed/json/${t.id}';
            final checkResp = await http
                .get(Uri.parse(checkUrl))
                .timeout(const Duration(seconds: 5));

            if (checkResp.statusCode == 200 && checkResp.body != '[]') {
              final List<dynamic> matches = json.decode(checkResp.body);
              if (matches.isNotEmpty) {
                verified.add(
                  OfficialTournamentModel(
                    id: t.id,
                    name: t.name,
                    country: t.country,
                    sport: t.sport,
                    logoUrl: t.logoUrl,
                    source: t.source,
                    hasFixtures: true,
                  ),
                );
              }
            }
          } catch (e) {
            // Skip failed checks
          }
        }

        if (verified.isNotEmpty) {
          await firestore.saveDiscoveredTournaments(verified);
          debugPrint(
            'Sync: Saved ${verified.length} newly discovered leagues.',
          );
        }
      }

      // --- PHASE 4: RELEASE LOCK ---
      await firestore.releaseTournamentSyncLock(success: true);
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  static Future<List<Map<String, String>>> importTeams(
    String tournamentId, {
    String source = 'fixturedownload',
  }) async {
    final isIsl =
        tournamentId.startsWith('isl-') ||
        tournamentId.contains('indian-super-league');
    if (source == 'manual' || isIsl) {
      if (isIsl) {
        // Use local bank for ISL to ensure clean names and logos
        // Try to use the base 'isl-2025' bank which contains all current clubs
        final clubTeams = TeamsDataService.getClubTeams('isl-2025');
        return clubTeams
            .map(
              (t) => {
                'name': t['name']!,
                'code': t['code']!,
                'logoUrl': t['logo']!,
              },
            )
            .toList();
      }
      if (source == 'manual') return [];
    }

    if (source == 'cricapi') {
      final cricService = CricApiService();
      final matches = await cricService.getSeriesMatches(tournamentId);
      final Set<String> teamNames = {};
      final List<Map<String, String>> teams = [];

      for (var m in matches) {
        final name = m['name'] as String? ?? '';
        final parts = name.split('vs');

        String t1 = '';
        String t2 = '';

        if (m['t1'] != null && m['t2'] != null) {
          t1 = m['t1'].toString();
          t2 = m['t2'].toString();
        } else if (parts.length > 1) {
          t1 = parts[0].replaceAll(RegExp(r'\[.*?\]'), '').trim();
          t2 = parts[1].replaceAll(RegExp(r'\[.*?\]'), '').trim();
        } else if (m['teams'] != null) {
          final tList = m['teams'] as List;
          if (tList.length >= 2) {
            t1 = tList[0].toString();
            t2 = tList[1].toString();
          }
        }

        if (t1.isNotEmpty) {
          t1 = t1.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
          if (teamNames.add(t1)) {
            teams.add({'name': t1, 'code': _generateCode(t1), 'logoUrl': ''});
          }
        }
        if (t2.isNotEmpty) {
          t2 = t2.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
          if (teamNames.add(t2)) {
            teams.add({'name': t2, 'code': _generateCode(t2), 'logoUrl': ''});
          }
        }
      }
      return teams..sort((a, b) => a['name']!.compareTo(b['name']!));
    }

    final url = 'https://fixturedownload.com/feed/json/$tournamentId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200 || response.body == '[]') {
      if (tournamentId == 'fifa-world-cup-2026' || tournamentId == 'wc2026') {
        const mockTeams = [
          {
            'name': 'USA',
            'code': 'USA',
            'logoUrl': 'https://crests.football-data.org/772.svg',
          },
          {
            'name': 'Mexico',
            'code': 'MEX',
            'logoUrl': 'https://crests.football-data.org/1077.svg',
          },
          {
            'name': 'Canada',
            'code': 'CAN',
            'logoUrl': 'https://crests.football-data.org/766.svg',
          },
          {
            'name': 'Argentina',
            'code': 'ARG',
            'logoUrl': 'https://crests.football-data.org/762.svg',
          },
          {
            'name': 'France',
            'code': 'FRA',
            'logoUrl': 'https://crests.football-data.org/773.svg',
          },
          {
            'name': 'Brazil',
            'code': 'BRA',
            'logoUrl': 'https://crests.football-data.org/764.svg',
          },
          {
            'name': 'Spain',
            'code': 'ESP',
            'logoUrl': 'https://crests.football-data.org/760.svg',
          },
          {
            'name': 'England',
            'code': 'ENG',
            'logoUrl': 'https://crests.football-data.org/770.svg',
          },
          {
            'name': 'Portugal',
            'code': 'POR',
            'logoUrl': 'https://crests.football-data.org/765.svg',
          },
          {
            'name': 'Senegal',
            'code': 'SEN',
            'logoUrl': 'https://crests.football-data.org/43.svg',
          },
        ];
        return mockTeams;
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch teams from $tournamentId');
      }
    }

    final List<dynamic> matches = json.decode(response.body);
    final Set<String> teamNames = {};
    final List<Map<String, String>> teams = [];

    for (var match in matches) {
      final homeTeam = match['HomeTeam'] as String?;
      final awayTeam = match['AwayTeam'] as String?;

      if (homeTeam != null &&
          !_isPlaceholder(homeTeam) &&
          teamNames.add(homeTeam)) {
        final resolvedName = TeamsDataService.resolveTeamName(
          tournamentId,
          homeTeam,
        );
        teams.add({
          'name': resolvedName,
          'code': _generateCode(resolvedName),
          'logoUrl':
              TeamsDataService.getTeamAsset(
                resolvedName,
                leagueId: tournamentId,
              ) ??
              '',
        });
      }
      if (awayTeam != null &&
          !_isPlaceholder(awayTeam) &&
          teamNames.add(awayTeam)) {
        final resolvedName = TeamsDataService.resolveTeamName(
          tournamentId,
          awayTeam,
        );
        teams.add({
          'name': resolvedName,
          'code': _generateCode(resolvedName),
          'logoUrl':
              TeamsDataService.getTeamAsset(
                resolvedName,
                leagueId: tournamentId,
              ) ??
              '',
        });
      }
    }

    return teams..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMatches(
    String sourceId,
  ) async {
    // LAYER 1: Check Firestore (Official Leagues)
    try {
      final firestore = FirestoreService();
      final matches = await firestore.firestore
          .collection('official_leagues')
          .doc(sourceId)
          .collection('matches')
          .where('scheduledTime', isGreaterThan: Timestamp.now())
          .orderBy('scheduledTime')
          .limit(10)
          .get();

      if (matches.docs.isNotEmpty) {
        return matches.docs.map((doc) {
          final data = doc.data();
          return {
            'team1': data['homeTeamName'] ?? data['team1Name'],
            'team2': data['awayTeamName'] ?? data['team2Name'],
            'time': (data['scheduledTime'] as Timestamp).toDate(),
            'leagueId': sourceId,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Firestore upcoming matches fetch error: $e');
    }

    // LAYER 2: Fallback to API (only if Firestore is empty)
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
          '${m['DateUtc'].toString().replaceAll(' ', 'T')}Z',
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

  static bool _isPlaceholder(String name) {
    final n = name.toLowerCase();
    // 1. Matches patterns like "1A", "2B", "3ABC"
    if (RegExp(r'^\d[a-z]+$').hasMatch(n)) return true;
    // 2. Contains slashes (e.g. "DEN/MKD/CZE/IRL")
    if (n.contains('/')) return true;
    // 3. Generic placeholders
    if (n == 'to be announced' ||
        n.contains('winner match') ||
        n.contains('loser match') ||
        n.contains('match ') ||
        n == 'tba') {
      return true;
    }
    // 4. Very short names that are likely codes but not real countries (optional, but catch codes like T32)
    if (n.length <= 3 && RegExp(r'^[a-z]\d+$').hasMatch(n)) return true;

    return false;
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
