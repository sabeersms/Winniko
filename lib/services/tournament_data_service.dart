import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/external_fixture_model.dart';
import 'teams_data_service.dart';
import 'firestore_service.dart';
import 'cric_api_service.dart';
import 'rapid_api_service.dart';

import '../constants/app_constants.dart';

class TournamentDataService {
  static final Map<String, DateTime> _lastRefreshTimes = {};
  static final Map<String, Set<String>> _seriesIdsCache = {};

  static const Map<String, String> _leagueUrls = {
    'pl': 'https://fixturedownload.com/feed/json/epl-2025',
    'laliga': 'https://fixturedownload.com/feed/json/la-liga-2025',
    'bundesliga': 'https://fixturedownload.com/feed/json/bundesliga-2025',
    'seriea': 'https://fixturedownload.com/feed/json/serie-a-2025',
    'ligue1': 'https://fixturedownload.com/feed/json/ligue-1-2025',
    'ucl': 'https://fixturedownload.com/feed/json/champions-league-2025',
    'wc2026': 'https://fixturedownload.com/feed/json/fifa-world-cup-2026',
    'mens-t20-world-cup-2026':
        'https://fixturedownload.com/feed/json/mens-t20-world-cup-2026',
  };

  static List<String> get supportedLeagues => _leagueUrls.keys.toList();

  static String? getLeagueIdByName(String name) {
    switch (name) {
      case 'Premier League':
        return 'pl';
      case 'La Liga':
        return 'laliga';
      case 'Bundesliga':
        return 'bundesliga';
      case 'Serie A':
        return 'seriea';
      case 'Ligue 1':
        return 'ligue1';
      case 'IPL':
        return 'ipl';
      case 'Asia Cup':
        return 'asiacup';
      case 'Cricket World Cup':
        return 'cwc';
      case 'Champions League':
        return 'ucl';
      default:
        return null;
    }
  }

  // We'll treat leagueId as a direct fixturedownload key if not in our fixed list

  static String _getFixtureUrl(String leagueId) {
    if (_leagueUrls.containsKey(leagueId)) {
      return _leagueUrls[leagueId]!;
    }
    // Check if it's a known cricket slug pattern (Cricket feeds usually don't have JSON on fixturedownload)
    if (leagueId.contains('cricket') ||
        leagueId.contains('ipl') ||
        leagueId.contains('bbl')) {
      return '';
    }
    // Assume search-based ID is a direct slug for fixturedownload
    return 'https://fixturedownload.com/feed/json/$leagueId';
  }

  static Future<List<MatchModel>> getTournamentFixtures(
    String competitionId,
    String leagueId,
    List<TeamModel> teams,
  ) async {
    // 1. Prepare dynamic URL logic
    debugPrint('getTournamentFixtures called for leagueId: $leagueId');
    final Map<String, TeamModel> teamMap = {
      for (var t in teams) t.shortName: t,
    };

    // 2. Try to fetch from Official Leagues (Firestore) first to avoid API costs
    try {
      final officialMatches = await _fetchFromOfficialLeagues(
        competitionId,
        leagueId,
        teamMap,
      );
      if (officialMatches.isNotEmpty) {
        debugPrint(
          'TournamentDataService: Using pre-imported data for $leagueId',
        );
        return officialMatches;
      }
    } catch (e) {
      debugPrint('Error checking Official Leagues: $e');
    }

    // (REMOVED fallback to live API fetch: only grab from verified hard copy in Firestore)
    // All API fetching is now isolated to the Master Verification process.

    if (leagueId == 'pl')
      return _getPremierLeagueFixtures(competitionId, teamMap);
    if (leagueId == 'ipl' || leagueId == 'asiacup' || leagueId == 'cwc') {
      return _getCricketFixtures(competitionId, leagueId, teamMap);
    }

    return [];
  }

  static List<MatchModel> _getCricketFixtures(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) {
    // Disabled sample generator to prevent fake scores.
    // If no API/Hardcoded data is found, return empty list.
    return [];
  }

  /// Fetches raw fixture data from External API and saves as 'Soft Copy' in Firestore.
  /// This bypasses team-mapping so ALL matches are saved, even when no competition teams are provided.
  /// Called manually by Master Admin or periodically by a Scheduled Job.
  static Future<void> fetchAndSaveSoftCopy(
    String competitionId,
    String leagueId,
    List<TeamModel> teams,
  ) async {
    debugPrint('🔄 SOFT-FETCH: Starting for $leagueId');

    // Try teams-based fetch first if teams are provided
    if (teams.isNotEmpty) {
      final matches = await getLatestScores(
        competitionId,
        leagueId,
        teams,
        isMaster: true,
      );
      if (matches.isNotEmpty) {
        await FirestoreService().saveSoftMatches(leagueId, matches);
        debugPrint(
          '✅ SOFT-FETCH: Saved ${matches.length} mapped matches for $leagueId',
        );
        return;
      }
    }

    // Fallback: Fetch raw JSON directly from fixturedownload.com
    // and save without team mapping using team NAMES as identifiers.
    final url = _getFixtureUrl(leagueId);
    if (url.isEmpty) {
      debugPrint('⚠️ SOFT-FETCH: No URL for league $leagueId');
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('⚠️ SOFT-FETCH: HTTP ${response.statusCode} for $url');
        return;
      }

      final List<dynamic> jsonList = json.decode(response.body);
      if (jsonList.isEmpty) {
        debugPrint('⚠️ SOFT-FETCH: Empty response for $leagueId');
        return;
      }

      final uuid = const Uuid();
      final List<MatchModel> rawMatches = [];

      for (var jsonMatch in jsonList) {
        try {
          final externalMatch = ExternalFixtureModel.fromJson(jsonMatch);

          final homeName = TeamsDataService.resolveTeamName(
            leagueId,
            externalMatch.homeTeam,
          );
          final awayName = TeamsDataService.resolveTeamName(
            leagueId,
            externalMatch.awayTeam,
          );

          DateTime scheduledTime;
          try {
            scheduledTime = DateTime.parse(externalMatch.dateUtc).toLocal();
          } catch (_) {
            scheduledTime = DateTime.now();
          }

          // Determine status from score
          String status = 'upcoming';
          Map<String, dynamic>? actualScore;

          if (externalMatch.homeTeamScore != null &&
              externalMatch.awayTeamScore != null) {
            final h = externalMatch.homeTeamScore!;
            final a = externalMatch.awayTeamScore!;
            if (h >= 0 && a >= 0) {
              status = 'completed';
              String? winnerCode;
              if (h > a)
                winnerCode = externalMatch.homeTeam;
              else if (a > h)
                winnerCode = externalMatch.awayTeam;

              actualScore = {'team1': h, 'team2': a, 'winnerCode': winnerCode};
            }
          }

          // 🛡️ STRICT GUARD: If match is in the future, it MUST be upcoming with no scores
          final now = DateTime.now();
          if (scheduledTime.isAfter(now)) {
            status = 'upcoming';
            actualScore = null;
          }

          // Save with team names as IDs (will be resolved on hard copy promotion)
          rawMatches.add(
            MatchModel(
              id: uuid.v4(),
              competitionId: competitionId,
              team1Id: homeName.toLowerCase().replaceAll(' ', '_'),
              team1Name: homeName,
              team1LogoUrl: '',
              team2Id: awayName.toLowerCase().replaceAll(' ', '_'),
              team2Name: awayName,
              team2LogoUrl: '',
              scheduledTime: scheduledTime,
              status: status,
              round: 'Round ${externalMatch.roundNumber}',
              matchNumber: externalMatch.matchNumber,
              actualScore: actualScore,
              location: externalMatch.location,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ SOFT-FETCH: Skipping match due to parse error: $e');
        }
      }

      if (rawMatches.isEmpty) {
        debugPrint('⚠️ SOFT-FETCH: No matches parsed from feed for $leagueId');
        return;
      }

      // (CRICKET SCORE API CALLS REMOVED: Scores are now 100% manual per user request)

      await FirestoreService().saveSoftMatches(leagueId, rawMatches);
      debugPrint(
        '✅ SOFT-FETCH: Saved ${rawMatches.length} raw matches for $leagueId (Fixtures Only)',
      );
    } catch (e) {
      debugPrint('❌ SOFT-FETCH: Failed for $leagueId: $e');
    }
  }

  /// Fetches the current state of ALL matches in a league (scores + status)
  ///
  /// [isMaster] should be TRUE only for the single master instance (Admin/Cloud Function).
  /// Everyone else reads from Firestore to save API costs.
  static Future<List<MatchModel>> getLatestScores(
    String competitionId,
    String leagueId,
    List<TeamModel> teams, {
    bool isMaster = false,
  }) async {
    final Map<String, TeamModel> teamMap = {
      for (var t in teams) t.shortName: t,
    };

    // MASTER MODE: Costly API Calls (Only for internal sync engine)
    if (isMaster) {
      debugPrint('⚠️ MASTER MODE: Fetching External API for $leagueId');

      // Use ESPN for known leagues (Premier League, La Liga, ISL)
      if (leagueId == 'pl' ||
          leagueId == 'laliga' ||
          leagueId.contains('isl') ||
          leagueId.contains('indian-super-league')) {
        try {
          String slug = 'eng.1';
          String? dates;

          if (leagueId == 'laliga') {
            slug = 'esp.1';
            dates = '20250815-20260531';
          } else if (leagueId.contains('isl') ||
              leagueId.contains('indian-super-league')) {
            slug = 'ind.1';
            final now = DateTime.now();
            final startYear = now.month < 6 ? now.year - 1 : now.year;
            final endYear = startYear + 1;
            dates = '${startYear}0901-${endYear}0531';
          }

          final matches = await _fetchEspnFixtures(
            competitionId,
            leagueId,
            teamMap,
            slug: slug,
            dates: dates,
          );
          if (matches.isNotEmpty) return matches;
        } catch (e) {
          debugPrint('ESPN match fetch failed: $e');
        }
      }

      // Default: FixtureDownload or CricAPI
      try {
        return await _fetchAndParseFixtures(competitionId, leagueId, teamMap);
      } catch (e) {
        debugPrint('Error fetching latest scores for $leagueId: $e');
      }
      return [];
    }

    // FOLLOWER MODE (Default): Read from Firestore "Official Leagues"
    // ENFORCED: Never fall back to API here. Client must wait for Master Sync.
    try {
      final matches = await _fetchFromOfficialLeagues(
        competitionId,
        leagueId,
        teamMap,
      );
      if (matches.isNotEmpty) return matches;
    } catch (e) {
      debugPrint('Error fetching from Official Leagues (Firestore): $e');
    }
    return [];
  }

  /// Reads curated matches from Firestore `official_leagues` collection
  static Future<List<MatchModel>> _fetchFromOfficialLeagues(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    // We access Firestore instance directly here
    final firestore = FirestoreService().firestore;

    final snapshot = await firestore
        .collection('official_leagues')
        .doc(leagueId)
        .collection('matches')
        .get();

    if (snapshot.docs.isEmpty) return [];

    final List<MatchModel> matches = [];
    final uuid = const Uuid();

    debugPrint(
      'TournamentDataService: Found ${snapshot.docs.length} official matches for $leagueId',
    );

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Robust Mapping: Support both MasterSync field names and standard MatchModel names
      final String homeName = (data['homeTeamName'] ?? data['team1Name'] ?? '')
          .toString();
      final String awayName = (data['awayTeamName'] ?? data['team2Name'] ?? '')
          .toString();
      final String homeCode = (data['homeTeamCode'] ?? '').toString();
      final String awayCode = (data['awayTeamCode'] ?? '').toString();

      TeamModel? homeTeam;
      TeamModel? awayTeam;

      // Robust Mapping: Try multiple ways to match
      for (var t in teamMap.values) {
        final tName = t.name.toLowerCase().trim();
        final tShort = t.shortName.toUpperCase().trim();

        // Match Home
        if (homeTeam == null) {
          if ((homeName.isNotEmpty && tName == homeName.toLowerCase().trim()) ||
              (homeCode.isNotEmpty &&
                  tShort == homeCode.toUpperCase().trim()) ||
              t.name == homeName ||
              t.shortName == homeCode) {
            homeTeam = t;
          }
        }

        // Match Away
        if (awayTeam == null) {
          if ((awayName.isNotEmpty && tName == awayName.toLowerCase().trim()) ||
              (awayCode.isNotEmpty &&
                  tShort == awayCode.toUpperCase().trim()) ||
              t.name == awayName ||
              t.shortName == awayCode) {
            awayTeam = t;
          }
        }
      }

      if (homeTeam == null || awayTeam == null) {
        debugPrint(
          'TournamentDataService: Mapping failed for official match: $homeName ($homeCode) vs $awayName ($awayCode)',
        );
        continue;
      }

      // Extract Status & Score
      final status = data['status'] ?? 'upcoming';
      Map<String, dynamic>? actualScore = data['actualScore'];

      // Override winnerId if exists in actualScore to match THIS competition's Team IDs
      if (actualScore != null) {
        final winnerCode = actualScore['winnerCode'];
        final winnerName = actualScore['winnerName']
            ?.toString()
            .toLowerCase()
            .trim();

        if (winnerCode != null) {
          if (homeTeam.shortName == winnerCode) {
            actualScore['winnerId'] = homeTeam.id;
          } else if (awayTeam.shortName == winnerCode) {
            actualScore['winnerId'] = awayTeam.id;
          }
        } else if (winnerName != null) {
          // Fallback to Name matching for shared verified scores
          if (homeTeam.name.toLowerCase().trim() == winnerName) {
            actualScore['winnerId'] = homeTeam.id;
          } else if (awayTeam.name.toLowerCase().trim() == winnerName) {
            actualScore['winnerId'] = awayTeam.id;
          } else if (winnerName == 'tied') {
            actualScore['winnerId'] = 'tied';
          } else if (winnerName == 'draw') {
            actualScore['winnerId'] = 'draw';
          }
        }

        // Ensure battingFirstId is corrected too
        final batFirstCode = actualScore['battingFirstCode'];
        final batFirstName = actualScore['battingFirstName']
            ?.toString()
            .toLowerCase()
            .trim();

        if (batFirstCode != null) {
          if (homeTeam.shortName == batFirstCode) {
            actualScore['battingFirstId'] = homeTeam.id;
          } else if (awayTeam.shortName == batFirstCode) {
            actualScore['battingFirstId'] = awayTeam.id;
          }
        } else if (batFirstName != null) {
          if (homeTeam.name.toLowerCase().trim() == batFirstName) {
            actualScore['battingFirstId'] = homeTeam.id;
          } else if (awayTeam.name.toLowerCase().trim() == batFirstName) {
            actualScore['battingFirstId'] = awayTeam.id;
          }
        }
      }

      final MatchModel currentMatch = MatchModel(
        id: uuid.v4(), // Ephemeral ID for sync comparison
        competitionId: competitionId,
        team1Id: homeTeam.id,
        team1Name: homeTeam.name,
        team1LogoUrl: homeTeam.logoUrl,
        team2Id: awayTeam.id,
        team2Name: awayTeam.name,
        team2LogoUrl: awayTeam.logoUrl,
        scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
        status: status,
        round: data['round'] ?? 'Regular Season',
        matchNumber: data['matchNumber'],
        actualScore: actualScore,
        location: data['location'] ?? 'Stadium',
      );

      // --- DEDUPLICATION LOGIC ---
      // Check if we already have this match representation (by teams + time proximity)
      int existingIdx = matches.indexWhere((m) {
        bool teamsMatch =
            (m.team1Name == currentMatch.team1Name &&
                m.team2Name == currentMatch.team2Name) ||
            (m.team1Name == currentMatch.team2Name &&
                m.team2Name == currentMatch.team1Name);
        if (!teamsMatch) return false;

        final timeDiff = m.scheduledTime
            .difference(currentMatch.scheduledTime)
            .inHours
            .abs();
        return timeDiff < 12; // Same match within 12 hours
      });

      if (existingIdx != -1) {
        final existingMatch = matches[existingIdx];

        // Priority: If current is verified and existing is not, replace it.
        // Otherwise, if existing is verified, keep it and skip current.
        if (currentMatch.isVerified && !existingMatch.isVerified) {
          debugPrint(
            '🔄 TournamentDataService: Prioritizing VERIFIED match over non-verified duplicate.',
          );
          matches[existingIdx] = currentMatch;
        } else if (!currentMatch.isVerified && existingMatch.isVerified) {
          debugPrint(
            '🛡️ TournamentDataService: Keeping existing VERIFIED match, skipping non-verified duplicate.',
          );
        } else if (currentMatch.matchNumber != null &&
            existingMatch.matchNumber == null) {
          // Fallback: If neither is verified, prefer the one with a match number
          matches[existingIdx] = currentMatch;
        }
      } else {
        matches.add(currentMatch);
      }
    }
    return matches;
  }

  static Future<List<MatchModel>> _fetchAndParseFixtures(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    final url = _getFixtureUrl(leagueId);
    if (url.isEmpty) {
      if (leagueId == 'fifa-world-cup-2026' || leagueId == 'wc2026') {
        return _getFIFAWorldCup2026Fixtures(competitionId, teamMap);
      }
      if (leagueId == 'mens-t20-world-cup-2026') {
        return _getT20WorldCup2026Fixtures(competitionId, teamMap);
      }
      // If it's cricket, we might need CricAPI list if it's a "current" match list
      if (leagueId.contains('ipl') ||
          leagueId.contains('cricket') ||
          leagueId.contains('t20')) {
        // Try Real Data First
        final realMatches = await _tryFetchRapidApiSeries(
          competitionId,
          leagueId,
          teamMap,
        );
        if (realMatches.isNotEmpty) return realMatches;

        return _getCricketFixtures(competitionId, leagueId, teamMap);
      }
      return [];
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200 || response.body == '[]') {
      // Fallback for known IDs if URL failed or returned empty
      if (leagueId == 'pl') {
        return _getPremierLeagueFixtures(competitionId, teamMap);
      }
      if (leagueId == 'fifa-world-cup-2026' || leagueId == 'wc2026') {
        return _getFIFAWorldCup2026Fixtures(competitionId, teamMap);
      }
      if (leagueId.contains('ipl') ||
          leagueId.contains('cricket') ||
          leagueId.contains('t20')) {
        return _getCricketFixtures(competitionId, leagueId, teamMap);
      }
      return [];
    }

    final List<dynamic> jsonList = json.decode(response.body);

    // Fetch live scores from CricAPI if applicable
    List<Map<String, dynamic>> cricMatches = [];
    if (leagueId.contains('t20') ||
        leagueId.contains('cricket') ||
        leagueId.contains('world-cup')) {
      try {
        // STRATEGY UPGRADE: Try to fetch FULL SERIES matches first
        final seriesMatches = await _tryFetchRapidApiSeries(
          competitionId,
          leagueId,
          teamMap,
        );
        if (seriesMatches.isNotEmpty) {
          debugPrint(
            'TournamentDataService: Using RapidAPI Full Series for $leagueId',
          );
          return seriesMatches;
        }

        final cricSeriesMatches = await _tryFetchCricApiSeries(
          competitionId,
          leagueId,
          teamMap,
        );
        if (cricSeriesMatches.isNotEmpty) {
          debugPrint(
            'TournamentDataService: Using CricAPI Full Series for $leagueId',
          );
          return cricSeriesMatches;
        }

        // Fallback to Current Matches Only
        cricMatches = await CricApiService().fetchCurrentMatches();
      } catch (e) {
        debugPrint('CricAPI Fetch Error: $e');
      }
    }
    final List<MatchModel> matches = [];
    final uuid = const Uuid();

    for (var jsonMatch in jsonList) {
      final externalMatch = ExternalFixtureModel.fromJson(jsonMatch);

      // Resolve Team Names
      final homeName = TeamsDataService.resolveTeamName(
        leagueId,
        externalMatch.homeTeam,
      );
      final awayName = TeamsDataService.resolveTeamName(
        leagueId,
        externalMatch.awayTeam,
      );

      // Find Internal Team Models (Match by Name)
      // Since teamMap keys are shortCodes (e.g. 'ARS'), we need to look through values for names
      TeamModel? homeTeam;
      TeamModel? awayTeam;

      try {
        // We use firstWhere with orElse to avoid StateError, but cleaner to catch state error or check
        // Iterating map values for every match is O(N*M), but N (matches) is ~380 and M (teams) is 20, so it's fine.
        // A name->team map would be O(1).

        for (var t in teamMap.values) {
          // 1. Exact Name
          if (t.name == homeName) homeTeam = t;
          if (t.name == awayName) awayTeam = t;
        }

        // 2. Fallback: Contains / Substring (if still null)
        if (homeTeam == null || awayTeam == null) {
          for (var t in teamMap.values) {
            if (homeTeam == null) {
              if (t.name.contains(homeName) || homeName.contains(t.name)) {
                homeTeam = t;
              }
            }
            if (awayTeam == null) {
              if (t.name.contains(awayName) || awayName.contains(t.name)) {
                awayTeam = t;
              }
            }
          }
        }
      } catch (e) {
        // ignore
      }

      if (homeTeam == null || awayTeam == null) {
        debugPrint('Team not found for match: $homeName vs $awayName');
        continue;
      }

      // Parse Date (Assuming format "2024-08-16 19:00:00" from this specific feed, or standard ISO)
      // The ExternalFixtureModel.fromJson will pass the string raw.
      // Typical fixturedownload.com format: "2024-08-16 19:00:00" (UTC usually implied or specified)
      // We'll treat it as UTC.

      DateTime scheduledTime;
      try {
        // Simple replace space with T for ISO parsing if needed
        String dateStr = externalMatch.dateUtc;
        if (!dateStr.contains('T')) {
          dateStr = dateStr.replaceAll(' ', 'T');
        }
        if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
          dateStr += 'Z';
        }
        scheduledTime = DateTime.parse(dateStr).toLocal();
      } catch (e) {
        // Fallback or skip
        debugPrint('Error parsing date: ${externalMatch.dateUtc}');
        scheduledTime = DateTime.now().add(const Duration(days: 30));
      }

      // SPECIAL LOGIC: Simulate scores for T20 World Cup 2026 if real scores are missing
      // This is because the feed might not have live scores for this tournament yet.
      String status = _inferMatchStatus(
        scheduledTime,
        externalMatch.homeTeamScore,
        externalMatch.awayTeamScore,
      );

      Map<String, dynamic>? actualScore;
      // Only set actualScore if the match is considered COMPLETED (no live scores)
      // Only set actualScore if the match is considered COMPLETED or LIVE (if we want to show live scores)
      if (status == AppConstants.matchStatusCompleted ||
          status == AppConstants.matchStatusLive ||
          status == 'match ended') {
        actualScore =
            (externalMatch.homeTeamScore != null &&
                externalMatch.awayTeamScore != null)
            ? {
                'team1': externalMatch.homeTeamScore!,
                'team2': externalMatch.awayTeamScore!,
              }
            : null;
      } else {
        actualScore = null;
        // Do NOT force status to 'upcoming' here anymore.
        // If _inferMatchStatus returned 'live', let it be 'live'.
      }

      // Fallback: Check CricAPI
      if (actualScore == null && cricMatches.isNotEmpty) {
        try {
          final homeNameLower = homeTeam.name.toLowerCase();
          final awayNameLower = awayTeam.name.toLowerCase();

          var cricMatch = cricMatches.firstWhere((cm) {
            final teams =
                (cm['teams'] as List?)?.map((e) => e.toString()).toList() ?? [];
            // Check if both teams are present using alias-aware matching
            bool hasHome = teams.any(
              (t) =>
                  t.toLowerCase() == homeNameLower || // Exact (Lower)
                  TeamsDataService.areTeamNamesEquivalent(t, homeTeam!.name),
            );
            bool hasAway = teams.any(
              (t) =>
                  t.toLowerCase() == awayNameLower || // Exact (Lower)
                  TeamsDataService.areTeamNamesEquivalent(t, awayTeam!.name),
            );
            return hasHome && hasAway;
          }, orElse: () => {});

          if (cricMatch.isNotEmpty) {
            // NEW: Check if score is empty/null, and if so, fetch details
            if (cricMatch['score'] == null ||
                (cricMatch['score'] is List &&
                    (cricMatch['score'] as List).isEmpty)) {
              debugPrint(
                'Fetching detailed score for match: ${cricMatch['name']}',
              );
              final detailed = await CricApiService().getMatchScore(
                cricMatch['id'],
              );
              if (detailed != null) {
                cricMatch = detailed;
              }
            }
          }

          if (cricMatch.isNotEmpty && cricMatch['score'] != null) {
            final List<dynamic> scores = cricMatch['score'];
            int t1r = 0, t1w = 0;
            double t1o = 0.0;
            int t2r = 0, t2w = 0;
            double t2o = 0.0;

            for (var s in scores) {
              final inning = s['inning'].toString();
              final r = int.tryParse(s['r'].toString()) ?? 0;
              final w = int.tryParse(s['w'].toString()) ?? 0;
              final o = double.tryParse(s['o'].toString()) ?? 0.0;

              bool matchesHome = TeamsDataService.stringContainsTeamName(
                inning,
                homeTeam.name,
              );
              bool matchesAway = TeamsDataService.stringContainsTeamName(
                inning,
                awayTeam.name,
              );

              // Resolve ambiguity by picking longer match
              if (matchesHome && matchesAway) {
                if (homeTeam.name.length >= awayTeam.name.length) {
                  matchesAway = false;
                } else {
                  matchesHome = false;
                }
              }

              if (matchesHome) {
                t1r += r; // Sum for safety
                t1w = w;
                t1o = o;
              } else if (matchesAway) {
                t2r += r;
                t2w = w;
                t2o = o;
              }
            }

            // Update if we have data
            if (t1r > 0 || t2r > 0 || t1o > 0 || t2o > 0) {
              final String cStatus = cricMatch['status']?.toString() ?? '';
              final String lowerStatus = cStatus.toLowerCase();
              String? winnerId;
              String marginType = '';
              String marginValue = '';

              // 1. DETERMINE WINNER AND MARGIN FROM STATUS TEXT (Reliable)
              if (lowerStatus.contains('won') || lowerStatus.contains('beat')) {
                bool matchesHome = TeamsDataService.stringContainsTeamName(
                  lowerStatus,
                  homeTeam.name,
                );
                bool matchesAway = TeamsDataService.stringContainsTeamName(
                  lowerStatus,
                  awayTeam.name,
                );

                if (matchesHome && matchesAway) {
                  int hi = _getBestIndex(lowerStatus, homeTeam.name);
                  int ai = _getBestIndex(lowerStatus, awayTeam.name);
                  int wonIdx = lowerStatus.indexOf('won');
                  int beatIdx = lowerStatus.indexOf('beat');
                  int indicator = wonIdx != -1 ? wonIdx : beatIdx;

                  bool homeAfterWonBy = _checkAfterWonBy(
                    lowerStatus,
                    homeTeam.name,
                  );
                  bool awayAfterWonBy = _checkAfterWonBy(
                    lowerStatus,
                    awayTeam.name,
                  );

                  if (homeAfterWonBy) {
                    winnerId = homeTeam.id;
                  } else if (awayAfterWonBy) {
                    winnerId = awayTeam.id;
                  } else if (indicator != -1) {
                    if (hi != -1 && hi < indicator)
                      winnerId = homeTeam.id;
                    else if (ai != -1 && ai < indicator)
                      winnerId = awayTeam.id;
                    else
                      winnerId = (hi < ai) ? homeTeam.id : awayTeam.id;
                  } else {
                    winnerId = (hi < ai) ? homeTeam.id : awayTeam.id;
                  }
                } else if (matchesHome) {
                  winnerId = homeTeam.id;
                } else if (matchesAway) {
                  winnerId = awayTeam.id;
                }

                if (lowerStatus.contains('run')) {
                  marginType = 'runs';
                  final m = RegExp(
                    r'(\d+)\s+(?:runs?|rns?)',
                  ).firstMatch(lowerStatus);
                  if (m != null) marginValue = m.group(1)!;
                } else if (lowerStatus.contains('wicket') ||
                    lowerStatus.contains('wkt')) {
                  marginType = 'wickets';
                  final m = RegExp(
                    r'(\d+)\s+(?:wickets?|wkts?)',
                  ).firstMatch(lowerStatus);
                  if (m != null) marginValue = m.group(1)!;
                } else if (lowerStatus.contains('super over')) {
                  marginType = 'super_over';
                }
              } else if (lowerStatus.contains('tied')) {
                winnerId = 'tied';
              }

              // 2. DETERMINE BATTING FIRST (For Fallback and Metadata)
              String battingFirstId = '';
              final tossWonName = cricMatch['tossWon']?.toString();
              final tossDecision = cricMatch['tossDecision']?.toString();

              if (tossWonName != null && tossDecision != null) {
                bool homeIsTossWinner = TeamsDataService.areTeamNamesEquivalent(
                  tossWonName,
                  homeTeam.name,
                );
                if (tossDecision.toLowerCase().contains('bat')) {
                  battingFirstId = homeIsTossWinner ? homeTeam.id : awayTeam.id;
                } else {
                  battingFirstId = homeIsTossWinner ? awayTeam.id : homeTeam.id;
                }
              } else if (scores.isNotEmpty) {
                // Guess from first score entry
                final inn = scores[0]['inning'].toString();
                if (TeamsDataService.stringContainsTeamName(
                  inn,
                  awayTeam.name,
                )) {
                  battingFirstId = awayTeam.id;
                } else {
                  battingFirstId = homeTeam.id;
                }
              }

              // 3. FALLBACK CALCULATION (If status generic)
              if (winnerId == null &&
                  (lowerStatus.contains('ended') ||
                      lowerStatus.contains('completed') ||
                      lowerStatus.contains('result'))) {
                if (t1r > t2r) {
                  winnerId = homeTeam.id;
                } else if (t2r > t1r) {
                  winnerId = awayTeam.id;
                } else {
                  winnerId = 'tied';
                }

                // If we know winner and batting first, we know margin type
                if (winnerId != 'tied' && battingFirstId.isNotEmpty) {
                  marginType = (winnerId == battingFirstId)
                      ? 'runs'
                      : 'wickets';
                  if (marginType == 'runs')
                    marginValue = (t1r - t2r).abs().toString();
                  else
                    marginValue = (winnerId == homeTeam.id)
                        ? (10 - t1w).toString()
                        : (10 - t2w).toString();
                }
              }

              actualScore = {
                'team1': t1r,
                'team2': t2r,
                't1Runs': t1r,
                't1Wickets': t1w,
                't1Overs': t1o,
                't2Runs': t2r,
                't2Wickets': t2w,
                't2Overs': t2o,
                'winnerId': winnerId,
                'marginType': marginType,
                'marginValue': marginValue,
                'battingFirstId': battingFirstId,
                'status': cStatus.isNotEmpty ? cStatus : status,
              };

              // Update Match Status
              final isActuallyLive =
                  lowerStatus.contains('need') ||
                  lowerStatus.contains('require') ||
                  lowerStatus.contains('trail') ||
                  lowerStatus.contains('opt to');

              if (isActuallyLive) {
                status = AppConstants.matchStatusProgressing;
              } else if (winnerId != null ||
                  lowerStatus.contains('completed') ||
                  lowerStatus.contains('result')) {
                status = AppConstants.matchStatusCompleted;
              } else {
                status = AppConstants.matchStatusProgressing;
              }
            }
          }
        } catch (e) {
          debugPrint('Error matching CricAPI score: $e');
        }
      }

      // Fallback: Simulation if still no score and match should be done
      // Removed simulation logic. If CricAPI fails, we show as upcoming or use whatever we have.

      matches.add(
        MatchModel(
          id: uuid.v4(),
          competitionId: competitionId,
          team1Id: homeTeam.id,
          team1Name: homeTeam.name,
          team1LogoUrl: homeTeam.logoUrl,
          team2Id: awayTeam.id,
          team2Name: awayTeam.name,
          team2LogoUrl: awayTeam.logoUrl,
          scheduledTime: scheduledTime,
          status: status,
          round: _formatRoundName(leagueId, externalMatch.roundNumber),
          group: externalMatch.group,
          matchNumber: externalMatch.matchNumber,
          actualScore: actualScore,
          location: externalMatch.location,
        ),
      );
    }

    return matches;
  }

  static String _inferMatchStatus(
    DateTime scheduledTime,
    int? homeScore,
    int? awayScore,
  ) {
    final now = DateTime.now();
    final difference = now.difference(scheduledTime).inMinutes;

    // Fix: If it hasn't started yet, it must be upcoming
    if (difference < -5) {
      return AppConstants.matchStatusUpcoming;
    }

    // If it has scores, it's either Live or Completed
    if (homeScore != null && awayScore != null) {
      // T20 matches usually finish in 3.5 hours.
      // If started > 4 hours ago and has scores, it's likely finished.
      if (difference >= 0 && difference < 240) {
        return AppConstants.matchStatusProgressing;
      }
      return AppConstants.matchStatusCompleted;
    }

    // No scores in feed
    if (difference < 0) {
      return AppConstants.matchStatusUpcoming;
    }

    // Started but no scores yet in feed
    // Buffer time: 4 hours
    if (difference < 240) {
      return AppConstants.matchStatusProgressing;
    }

    // Long time ago, still no scores? Likely completed but feed missing data
    return AppConstants.matchStatusCompleted;
  }

  static List<MatchModel> _getPremierLeagueFixtures(
    String competitionId,
    Map<String, TeamModel> teamMap,
  ) {
    // Manual entry of Round 1 Premier League 2024/25
    // Friday 16 August 2024
    // Man Utd vs Fulham

    final matches = <MatchModel>[];
    final uuid = const Uuid();

    // Helper to add match
    void addMatch(String homeCode, String awayCode, DateTime time) {
      final home = teamMap[homeCode];
      final away = teamMap[awayCode];
      if (home != null && away != null) {
        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: home.id,
            team1Name: home.name,
            team1LogoUrl: home.logoUrl,
            team2Id: away.id,
            team2Name: away.name,
            team2LogoUrl: away.logoUrl,
            scheduledTime: time,
            status: 'upcoming', // Standardize to 'upcoming'
            round: 'Round 1',
            matchNumber: matches.length + 1,
          ),
        );
      } else {
        // Debug print if needed
        debugPrint('Missing team for match: $homeCode vs $awayCode');
      }
    }

    // Round 1
    addMatch('MUN', 'FUL', DateTime(2024, 8, 16, 20, 0)); // Man Utd v Fulham
    addMatch(
      'IPS',
      'LIV',
      DateTime(2024, 8, 17, 12, 30),
    ); // Ipswich v Liverpool
    addMatch('ARS', 'WOL', DateTime(2024, 8, 17, 15, 0)); // Arsenal v Wolves
    addMatch('EVE', 'BHA', DateTime(2024, 8, 17, 15, 0)); // Everton v Brighton
    addMatch(
      'NEW',
      'SOU',
      DateTime(2024, 8, 17, 15, 0),
    ); // Newcastle v Southampton
    addMatch(
      'NFO',
      'BOU',
      DateTime(2024, 8, 17, 15, 0),
    ); // Nottm Forest v Bournemouth
    addMatch(
      'WHU',
      'AVL',
      DateTime(2024, 8, 17, 17, 30),
    ); // West Ham v Aston Villa
    addMatch(
      'BRE',
      'CRY',
      DateTime(2024, 8, 18, 14, 0),
    ); // Brentford v Crystal Palace
    addMatch('CHE', 'MCI', DateTime(2024, 8, 18, 16, 30)); // Chelsea v Man City
    addMatch('LEI', 'TOT', DateTime(2024, 8, 19, 20, 0)); // Leicester v Spurs

    return matches;
  }

  static Future<List<MatchModel>> _fetchEspnFixtures(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap, {
    String slug = 'eng.1',
    String? dates,
  }) async {
    // Public ESPN Status Endpoint
    String url =
        'https://site.api.espn.com/apis/site/v2/sports/soccer/$slug/scoreboard?limit=100';

    if (dates != null) {
      url += '&dates=$dates';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('ESPN API Error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final events = data['events'] as List<dynamic>? ?? [];

    final List<MatchModel> matches = [];
    final uuid = const Uuid();

    for (var event in events) {
      final competition = event['competitions']?[0];
      if (competition == null) continue;

      final competitors = competition['competitors'] as List<dynamic>;
      var homeComp = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => null,
      );
      var awayComp = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => null,
      );

      if (homeComp == null || awayComp == null) continue;

      final homeNameRaw = homeComp['team']['displayName'];
      final awayNameRaw = awayComp['team']['displayName'];

      final homeScoreStr = homeComp['score']; // usually String in ESPN JSON
      final awayScoreStr = awayComp['score'];

      final statusDict = event['status'];
      final statusType = statusDict['type']['name'] ?? '';

      // Resolve Names
      final homeName = TeamsDataService.resolveTeamName(leagueId, homeNameRaw);
      final awayName = TeamsDataService.resolveTeamName(leagueId, awayNameRaw);

      // Find Internal Teams
      TeamModel? homeTeam;
      TeamModel? awayTeam;

      // Robust Mapping: Try multiple ways to match
      for (var t in teamMap.values) {
        if (TeamsDataService.areTeamNamesEquivalent(t.name, homeName)) {
          homeTeam = t;
        }
        if (TeamsDataService.areTeamNamesEquivalent(t.name, awayName)) {
          awayTeam = t;
        }
      }

      // Exact Name
      if (homeTeam == null || awayTeam == null) {
        for (var t in teamMap.values) {
          if (t.name == homeName) homeTeam = t;
          if (t.name == awayName) awayTeam = t;
        }
      }

      // Fuzzy/Contains
      if (homeTeam == null || awayTeam == null) {
        for (var t in teamMap.values) {
          if (homeTeam == null &&
              (t.name.toLowerCase().contains(homeName.toLowerCase()) ||
                  homeName.toLowerCase().contains(t.name.toLowerCase()))) {
            homeTeam = t;
          }
          if (awayTeam == null &&
              (t.name.toLowerCase().contains(awayName.toLowerCase()) ||
                  awayName.toLowerCase().contains(t.name.toLowerCase()))) {
            awayTeam = t;
          }
        }
      }

      if (homeTeam == null || awayTeam == null) {
        continue;
      }

      DateTime date = DateTime.parse(event['date']);

      // Determine Status
      String status = 'upcoming';
      if (statusType.contains('STATUS_FULL_TIME') ||
          statusType.contains('STATUS_FINAL')) {
        status = 'completed';
      } else if (statusType.contains('STATUS_IN_PROGRESS') ||
          statusType.contains('STATUS_HALFTIME') ||
          statusType.contains('STATUS_ADDED_TIME')) {
        status = 'live';
      } else if (statusType.contains('STATUS_POSTPONED')) {
        status = 'upcoming';
      }

      // Scores
      Map<String, dynamic>? actualScore;
      // Only set score if live or completed
      if (status != 'upcoming' &&
          homeScoreStr != null &&
          awayScoreStr != null) {
        actualScore = {
          'team1': int.tryParse(homeScoreStr.toString()) ?? 0,
          'team2': int.tryParse(awayScoreStr.toString()) ?? 0,
          'winnerId':
              (int.parse(homeScoreStr.toString()) >
                  int.parse(awayScoreStr.toString()))
              ? homeTeam.id
              : (int.parse(awayScoreStr.toString()) >
                    int.parse(homeScoreStr.toString()))
              ? awayTeam.id
              : 'draw',
        };
      }

      final matchId =
          'espn-${leagueId.replaceAll('.', '-')}-${homeTeam.shortName}-${awayTeam.shortName}-${date.millisecondsSinceEpoch}';

      matches.add(
        MatchModel(
          id: matchId,
          competitionId: competitionId,
          team1Id: homeTeam.id,
          team2Id: awayTeam.id,
          team1Name: homeTeam.name,
          team2Name: awayTeam.name,
          team1LogoUrl: homeTeam.logoUrl,
          team2LogoUrl: awayTeam.logoUrl,
          scheduledTime: date,
          status: status,
          actualScore: actualScore,
        ),
      );
    }

    debugPrint(
      'TournamentDataService: Successfully matched ${matches.length} out of ${events.length} ESPN events for $leagueId',
    );

    return matches;
  }

  /// Refresh schedules and scores for an active competition tied to an official source
  /// Returns the number of matches updated (approximate).
  static Future<int> refreshCompetitionFixtures({
    required String competitionId,
    required String leagueId,
    required FirestoreService firestore,
    bool force = false,
  }) async {
    try {
      // 1. LOCAL THROTTLE (2 mins) - Prevents same UI instance from spamming
      if (!force) {
        final lastRefresh = _lastRefreshTimes[competitionId];
        if (lastRefresh != null &&
            DateTime.now().difference(lastRefresh).inMinutes < 2) {
          debugPrint('Throttled refresh for $competitionId');
          return 0;
        }
      }
      _lastRefreshTimes[competitionId] = DateTime.now();

      // 2. Load the Competition Metadata and VERIFIED HARD COPY
      final compDoc = await FirebaseFirestore.instance
          .collection('competitions')
          .doc(competitionId)
          .get();
      final lastCleanedAt = (compDoc.data()?['lastCleanedAt'] as Timestamp?)
          ?.toDate();

      // Fetch League Metadata to check for global cleaning
      final leagueDoc = await FirebaseFirestore.instance
          .collection('official_leagues')
          .doc(leagueId)
          .get();
      final leagueLastCleanedAt =
          (leagueDoc.data()?['lastCleanedAt'] as Timestamp?)?.toDate();

      final internalMatches = await firestore.getMatches(competitionId).first;

      // Process matches directly from the VERIFIED HARD COPY, NEVER the live API
      final hardCopySnap = await FirebaseFirestore.instance
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .get();

      final List<MatchModel> externalMatches = hardCopySnap.docs
          .map(
            (doc) => MatchModel.fromSnapshot(
              doc,
            ).copyWith(competitionId: competitionId),
          )
          .toList();

      if (externalMatches.isEmpty) {
        // 🧹 SYNC CLEANUP: If official source is empty, and it was globally cleaned
        // OR if the competition has matches that should have been removed.
        if (internalMatches.isNotEmpty) {
          // We only clean if the league was explicitly cleaned MORE RECENTLY than the last internal match was created/updated
          // Or simply if the user wants it cleaned. To be safe, we check if global cleaning occurred.
          if (leagueLastCleanedAt != null) {
            debugPrint(
              '🧹 SYNC: Official source for $leagueId was cleaned at $leagueLastCleanedAt. Cleaning competition $competitionId.',
            );
            await firestore.deleteCompetitionMatches(competitionId);
            return internalMatches.length;
          }
        }
        return 0;
      }

      // 3. Load Competition Teams for ID resolution
      final compTeams = await firestore.getTeams(competitionId).first;
      final Map<String, String> teamNameToId = {
        for (var t in compTeams) t.name.toLowerCase().trim(): t.id,
      };

      // 5. Apply Updates to Local Competition
      final List<MatchModel> newMatches = [];
      final List<MatchModel> matchesToUpdate = [];
      final now = DateTime.now();

      for (var rawExt in externalMatches) {
        // Resolve IDs for the external match to match this competition's teams
        var ext = rawExt;
        final t1Id = teamNameToId[ext.team1Name.toLowerCase().trim()];
        final t2Id = teamNameToId[ext.team2Name.toLowerCase().trim()];

        if (t1Id != null && t2Id != null) {
          ext = ext.copyWith(team1Id: t1Id, team2Id: t2Id);
        }

        // 5. MATCH PAIRING (Improved to handle recurring matches like IND vs PAK)
        // Find by Team IDs OR Team Names AND Time proximity (within 12 hours)
        final matchesWithSameTeams = internalMatches.where((m) {
          final isSameDirectId =
              m.team1Id == ext.team1Id && m.team2Id == ext.team2Id;
          final isSameReversedId =
              m.team1Id == ext.team2Id && m.team2Id == ext.team1Id;

          final isSameDirectName =
              m.team1Name == ext.team1Name && m.team2Name == ext.team2Name;
          final isSameReversedName =
              m.team1Name == ext.team2Name && m.team2Name == ext.team1Name;

          return isSameDirectId ||
              isSameReversedId ||
              isSameDirectName ||
              isSameReversedName;
        }).toList();

        MatchModel? internal;
        if (matchesWithSameTeams.length == 1) {
          internal = matchesWithSameTeams.first;
        } else if (matchesWithSameTeams.length > 1) {
          // If multiple matches exist between same teams, pick the one closest in time (within ~12h)
          internal = matchesWithSameTeams.firstWhere(
            (m) =>
                m.scheduledTime.difference(ext.scheduledTime).inHours.abs() <
                12,
            orElse: () => matchesWithSameTeams.first,
          );
        }

        if (internal == null) {
          // 🛡️ TOMBSTONE CHECK: Don't re-add matches that were explicitly cleaned
          // UNLESS the match is explicitly verified (it's the source of truth)
          final bool isExtVerified = ext.actualScore?['verified'] == true;
          if (!isExtVerified &&
              lastCleanedAt != null &&
              ext.scheduledTime.isBefore(lastCleanedAt)) {
            debugPrint(
              '🚫 Sync blocked: Skipping old match ${ext.team1Name} vs ${ext.team2Name} (Cleaned at $lastCleanedAt)',
            );
            continue; // Skip this match entirely
          }
          // ADD NEW MATCH to the competition if it doesn't exist
          debugPrint(
            '➕ TournamentDataService: Adding new official match to competition: ${ext.team1Name} vs ${ext.team2Name}',
          );
          newMatches.add(ext);
          continue;
        }

        // SANITIZATION
        var sanitizedExt = ext;
        final ageHours = now.difference(ext.scheduledTime).inHours;

        // 👻 GHOST PURGE: If external match says it's completed but it's in the future
        if (ext.scheduledTime.isAfter(now.add(const Duration(minutes: 5)))) {
          sanitizedExt = ext.copyWith(
            status: 'upcoming',
            actualScore: null,
            winnerId: null,
          );
          debugPrint(
            '👻 GHOST PURGE (Sync): Intercepted future match with scores/wrong status: ${ext.team1Name} vs ${ext.team2Name}',
          );
        } else if (ageHours > 24) {
          final s = ext.status.toLowerCase();
          final isFinal =
              s.contains('won') ||
              s.contains('beat') ||
              s.contains('tied') ||
              s.contains('ended') ||
              s.contains('result') ||
              s == 'completed';
          if (!isFinal) {
            sanitizedExt = ext.copyWith(status: 'Match Ended');
            debugPrint(
              'Forcing completion for external match: ${ext.team1Name} vs ${ext.team2Name}',
            );
          }
        }

        final bool isReversed = internal.team1Id == ext.team2Id;
        final bool isManuallyScored =
            internal.actualScore?['manuallyScored'] == true;
        final bool isVerified = internal.actualScore?['verified'] == true;

        // 🛡️ COMPLETE PROTECTION: If manually scored OR verified, skip ALL updates
        if (isManuallyScored || isVerified) {
          final reason = isVerified
              ? 'verified by super admin'
              : 'manually scored by master admin';
          debugPrint(
            '🛡️ FULLY PROTECTED: Skipping ALL API updates for ${internal.team1Name} vs ${internal.team2Name} ($reason)',
          );
          continue; // Skip this match entirely
        }

        bool changed = false;
        var updated = internal;

        // Sync Scheduled Time if mismatch > 1 min
        if (internal.scheduledTime
                .difference(sanitizedExt.scheduledTime)
                .inMinutes
                .abs() >
            1) {
          updated = updated.copyWith(scheduledTime: sanitizedExt.scheduledTime);
          changed = true;
        }

        // Sync Status
        if (internal.status != sanitizedExt.status) {
          updated = updated.copyWith(status: sanitizedExt.status);
          changed = true;
        }

        // Sync Round/Group labels (Ensure Super 8 etc are reflected)
        if (internal.round != sanitizedExt.round) {
          updated = updated.copyWith(round: sanitizedExt.round);
          changed = true;
        }
        if (internal.group != sanitizedExt.group) {
          updated = updated.copyWith(group: sanitizedExt.group);
          changed = true;
        }

        // Sync Score (Now allowed for Cricket since source is VERIFIED Hard Copy)
        if (sanitizedExt.actualScore != null) {
          var scoreToApply = sanitizedExt.actualScore!;

          // If teams are in reversed order in internal vs external, we need to swap the scores
          // However, Cricket score maps often use team names or 'team1'/'team2' labels.
          // If using 'team1'/'team2', we swap based on reversed flag.
          if (isReversed) {
            final Map<String, dynamic> swapped = Map.from(scoreToApply);
            if (swapped.containsKey('team1') && swapped.containsKey('team2')) {
              final t1Score = swapped['team1'];
              swapped['team1'] = swapped['team2'];
              swapped['team2'] = t1Score;
            }
            // Also need to adjust winnerId if it's one of the teams
            if (swapped['winnerId'] == rawExt.team1Id) {
              swapped['winnerId'] = rawExt.team2Id;
            } else if (swapped['winnerId'] == rawExt.team2Id) {
              swapped['winnerId'] = rawExt.team1Id;
            }
            scoreToApply = swapped;
          }

          if (internal.actualScore == null ||
              internal.actualScore.toString() != scoreToApply.toString()) {
            updated = updated.copyWith(actualScore: scoreToApply);
            changed = true;
          }
        }

        // Sync winnerId
        if (internal.winnerId != sanitizedExt.winnerId) {
          // Mapping winner ID from Official (Slug) to Contest (UUID)
          String? resolvedWinner = sanitizedExt.winnerId;
          if (resolvedWinner != null) {
            if (resolvedWinner == rawExt.team1Id)
              resolvedWinner = ext.team1Id;
            else if (resolvedWinner == rawExt.team2Id)
              resolvedWinner = ext.team2Id;
          }

          if (internal.winnerId != resolvedWinner) {
            updated = updated.copyWith(winnerId: resolvedWinner);
            changed = true;
          }
        }

        if (changed) {
          matchesToUpdate.add(updated);
        }
      }

      // 6. ZOMBIE CLEANUP: Check for local matches that are old but still stuck
      // This handles cases where API dropped the match entirely
      for (var m in internalMatches) {
        // Skip if already being updated
        if (matchesToUpdate.any((u) => u.id == m.id)) continue;

        final ageHours = DateTime.now().difference(m.scheduledTime).inHours;
        if (ageHours > 24) {
          final s = m.status.toLowerCase();
          if (s.contains('live') ||
              s == 'scheduled' ||
              s == 'upcoming' ||
              s == 'progressing') {
            // Force update
            // ZOMBIE CLEANUP DISABLED TEMPORARILY
            // matchUpdates.add(m.copyWith(status: 'Match Ended'));
            debugPrint(
              'Zombie Cleanup (DISABLED): WOULD force completion for ${m.team1Name} vs ${m.team2Name}. Age Hours: $ageHours',
            );
          }
        }
      }

      int totalHandled = 0;
      if (newMatches.isNotEmpty) {
        await firestore.createBatchMatches(newMatches);
        totalHandled += newMatches.length;
      }
      if (matchesToUpdate.isNotEmpty) {
        await firestore.updateMatchScoreBulk(competitionId, matchesToUpdate);
        totalHandled += matchesToUpdate.length;
      }

      return totalHandled;
    } catch (e) {
      debugPrint('Error in autonomous sync: $e');
      return 0;
    }
  }

  static Future<List<MatchModel>> _getT20WorldCup2026Fixtures(
    String competitionId,
    Map<String, TeamModel> teamMap,
  ) async {
    final uuid = const Uuid();
    final List<MatchModel> matches = [];

    // Helper to find team with debug logging
    TeamModel? findTeam(String name) {
      final normalizedName = name.toLowerCase().trim();

      // 1. Exact Match
      for (var t in teamMap.values) {
        if (t.name.toLowerCase().trim() == normalizedName) return t;
      }

      // 2. Contains Match
      for (var t in teamMap.values) {
        final tName = t.name.toLowerCase().trim();
        if (tName.contains(normalizedName) || normalizedName.contains(tName)) {
          return t;
        }
      }
      return null;
    }

    // Let's print available teams to debug
    debugPrint(
      'T20 WC 2026: Resolving against ${teamMap.length} teams: ${teamMap.values.map((e) => e.name).join(", ")}',
    );

    final fixturesForLoop = [
      // June 7
      {
        'home': 'Pakistan',
        'away': 'Netherlands',
        'time': '2026-06-07T14:30:00Z',
        'status': 'Pakistan won by 3 wickets',
        'winner': 'Pakistan',
        'marginType': 'wickets',
        'marginValue': '3',
        'location': 'Sinhalese Sports Club, Colombo',
        'round': 'Group A',
      },
      {
        'home': 'West Indies',
        'away': 'Scotland',
        'time': '2026-06-07T18:30:00Z',
        'status': 'West Indies won by 35 runs',
        'winner': 'West Indies',
        'marginType': 'runs',
        'marginValue': '35',
        'location': 'Eden Gardens, Kolkata',
        'round': 'Group C',
      },
      {
        'home': 'India',
        'away': 'United States',
        'time': '2026-06-07T18:30:00Z',
        'status': 'India won by 29 runs',
        'winner': 'India',
        'marginType': 'runs',
        'marginValue': '29',
        'location': 'Wankhede Stadium, Mumbai',
        'round': 'Group A',
      },
      // June 8
      {
        'home': 'New Zealand',
        'away': 'Afghanistan',
        'time': '2026-06-08T14:30:00Z',
        'status': 'New Zealand won by 5 wickets',
        'winner': 'New Zealand',
        'marginType': 'wickets',
        'marginValue': '5',
        'location': 'MA Chidambaram Stadium, Chennai',
        'round': 'Group D',
      },
      {
        'home': 'England',
        'away': 'Nepal',
        'time': '2026-06-08T18:30:00Z',
        'status': 'England won by 4 runs',
        'winner': 'England',
        'marginType': 'runs',
        'marginValue': '4',
        'location': 'Wankhede Stadium, Mumbai',
        'round': 'Group C',
      },
      {
        'home': 'Sri Lanka',
        'away': 'Ireland',
        'time': '2026-06-08T18:30:00Z',
        'status': 'Sri Lanka won by 20 runs',
        'winner': 'Sri Lanka',
        'marginType': 'runs',
        'marginValue': '20',
        'location': 'R. Premadasa Stadium, Colombo',
        'round': 'Group B',
      },
      // June 9
      {
        'home': 'Scotland',
        'away': 'Italy',
        'time': '2026-06-09T14:30:00Z',
        'status': 'Scotland won by 73 runs',
        'winner': 'Scotland',
        'marginType': 'runs',
        'marginValue': '73',
        'location': 'Eden Gardens, Kolkata',
        'round': 'Group C',
      },
      {
        'home': 'Zimbabwe',
        'away': 'Oman',
        'time': '2026-06-09T14:30:00Z',
        'status': 'Zimbabwe won by 8 wickets',
        'winner': 'Zimbabwe',
        'marginType': 'wickets',
        'marginValue': '8',
        'location': 'Sinhalese Sports Club, Colombo',
        'round': 'Group B',
      },
      {
        'home': 'South Africa',
        'away': 'Canada',
        'time': '2026-06-09T18:30:00Z',
        'status': 'South Africa won by 57 runs',
        'winner': 'South Africa',
        'marginType': 'runs',
        'marginValue': '57',
        'location': 'Narendra Modi Stadium, Ahmedabad',
        'round': 'Group D',
      },
    ];

    for (var f in fixturesForLoop) {
      final t1 = findTeam(f['home']!.trim());
      final t2 = findTeam(f['away']!.trim());

      if (t1 != null && t2 != null) {
        // Resolve Winner ID
        String? winnerId;
        final winnerName = f['winner']!;

        if (t1.name.toLowerCase() == winnerName.toLowerCase() ||
            t1.name.toLowerCase().contains(winnerName.toLowerCase())) {
          winnerId = t1.id;
        } else if (t2.name.toLowerCase() == winnerName.toLowerCase() ||
            t2.name.toLowerCase().contains(winnerName.toLowerCase())) {
          winnerId = t2.id;
        }

        // Special case overrides for T20 WC 2026
        if (winnerName == 'United States' || winnerName == 'USA') {
          if (t1.name == 'United States' || t1.name == 'USA') {
            winnerId = t1.id;
          } else if (t2.name == 'United States' || t2.name == 'USA')
            winnerId = t2.id;
        }

        // Debug
        if (winnerId == null) {
          debugPrint(
            'T20 WC 2026: Could not determine winner ID for $winnerName in ${t1.name} vs ${t2.name}',
          );
        }

        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: t1.id,
            team2Id: t2.id,
            team1Name: t1.name,
            team2Name: t2.name,
            team1LogoUrl: t1.logoUrl,
            team2LogoUrl: t2.logoUrl,
            scheduledTime: DateTime.parse(f['time']!).toLocal(),
            status: DateTime.parse(f['time']!).isAfter(DateTime.now())
                ? AppConstants.matchStatusUpcoming
                : AppConstants.matchStatusCompleted,
            round: f['round'],
            matchNumber: matches.length + 1,
            location: f['location'],
            winnerId: winnerId,
            actualScore: {
              'status': f['status'],
              'winnerId': winnerId,
              'marginType': f['marginType'],
              'marginValue': f['marginValue'],
            },
          ),
        );
      } else {
        debugPrint(
          'T20 WC 2026: Teams not found for ${f['home']} vs ${f['away']}',
        );
      }
    }
    return matches;
  }

  static Future<List<MatchModel>> _getFIFAWorldCup2026Fixtures(
    String competitionId,
    Map<String, TeamModel> teamMap,
  ) async {
    final uuid = const Uuid();
    final List<MatchModel> matches = [];

    final List<Map<String, dynamic>> fixtures = [
      {
        'home': 'USA',
        'away': 'Mexico',
        'time': '2026-06-11T18:00:00Z',
        'round': 'Group A',
      },
      {
        'home': 'Canada',
        'away': 'Senegal',
        'time': '2026-06-12T15:00:00Z',
        'round': 'Group B',
      },
      {
        'home': 'Argentina',
        'away': 'France',
        'time': '2026-06-13T20:00:00Z',
        'round': 'Group C',
      },
      {
        'home': 'Brazil',
        'away': 'Spain',
        'time': '2026-06-14T20:00:00Z',
        'round': 'Group D',
      },
      {
        'home': 'England',
        'away': 'Portugal',
        'time': '2026-06-15T20:00:00Z',
        'round': 'Group E',
      },
    ];

    for (var f in fixtures) {
      TeamModel? t1;
      TeamModel? t2;

      for (var t in teamMap.values) {
        if (t.name.toLowerCase().contains(f['home'].toString().toLowerCase())) {
          t1 = t;
        }
        if (t.name.toLowerCase().contains(f['away'].toString().toLowerCase())) {
          t2 = t;
        }
      }

      if (t1 != null && t2 != null) {
        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: t1.id,
            team2Id: t2.id,
            team1Name: t1.name,
            team2Name: t2.name,
            scheduledTime: DateTime.parse(f['time']).toLocal(),
            status: 'upcoming',
            round: f['round'],
            matchNumber: 0,
            location: 'Various Stadia',
          ),
        );
      }
    }
    return matches;
  }

  /// Parses matches directly from CricAPI Series List
  static List<MatchModel> _parseCricApiSeriesMatches(
    String competitionId,
    List<Map<String, dynamic>> cricMatches,
    Map<String, TeamModel> teamMap,
  ) {
    final matches = <MatchModel>[];
    final uuid = const Uuid();

    for (var m in cricMatches) {
      final name = m['name'] as String? ?? '';
      if (!name.contains('vs')) continue;

      // Extract Team Names
      // Name usually: "Team A vs Team B, 1st Match"
      final parts = name.split(',');
      final teamParts = parts[0].split('vs');
      if (teamParts.length < 2) continue;

      String t1Raw = teamParts[0].trim();
      String t2Raw = teamParts[1].trim();

      // Resolve Teams
      TeamModel? t1;
      TeamModel? t2;

      // 1. Exact Match on resolved name
      for (var t in teamMap.values) {
        if (TeamsDataService.areTeamNamesEquivalent(t.name, t1Raw)) t1 = t;
        if (TeamsDataService.areTeamNamesEquivalent(t.name, t2Raw)) t2 = t;
      }

      // 2. Contains (Fuzzy) if failed
      if (t1 == null || t2 == null) {
        for (var t in teamMap.values) {
          if (t1 == null && t1Raw.contains(t.name)) t1 = t;
          if (t2 == null && t2Raw.contains(t.name)) t2 = t;
        }
      }

      if (t1 == null || t2 == null) continue;

      // Parse Date (CricAPI returns GMT strings often without 'Z')
      DateTime scheduledTime;
      try {
        final gmt = m['dateTimeGMT'];
        if (gmt != null) {
          // If explicitly GMT, ensure it's treated as UTC
          var dateStr = gmt.toString();
          if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
            dateStr += 'Z';
          }
          scheduledTime = DateTime.parse(dateStr).toLocal();
        } else {
          // Fallback to 'date' (YYYY-MM-DD), treat as local midnight
          scheduledTime = DateTime.parse(m['date']).toLocal();
        }
      } catch (e) {
        debugPrint('Error parsing date for ${m['name']}: $e');
        scheduledTime = DateTime.parse(m['date']).toLocal(); // Last resort
      }
      String status = 'upcoming';
      if (m['status'] != null) {
        final s = m['status'].toString().toLowerCase();
        if (s.contains('won') ||
            s.contains('beat') ||
            s.contains('tied') ||
            s == 'completed' ||
            s.contains('match ended') ||
            s.contains('result')) {
          status = AppConstants.matchStatusCompleted;
        } else if (s.contains('live') ||
            s.contains('progress') ||
            s.contains('progressing') ||
            s.contains('break') ||
            s.contains('started')) {
          status = AppConstants.matchStatusProgressing;
        } else if (s.contains('abandoned') || s.contains('no result')) {
          status = AppConstants.matchStatusCompleted;
        }
      }

      // (SCORE PARSING REMOVED: Cricket scores are now manual only)
      Map<String, dynamic>? finalScore;
      String? winnerId;

      matches.add(
        MatchModel(
          id: uuid.v4(),
          competitionId: competitionId,
          team1Id: t1.id,
          team1Name: t1.name,
          team1LogoUrl: t1.logoUrl,
          team2Id: t2.id,
          team2Name: t2.name,
          team2LogoUrl: t2.logoUrl,
          scheduledTime: scheduledTime,
          status: status,
          round: _getCricketMatchRound(m['name'] ?? ''),
          matchNumber:
              int.tryParse(
                RegExp(
                      r'(?:Match\s+|#|(\d+)(?:st|nd|rd|th)\s+Match)(\d+)?',
                    ).firstMatch(m['name'] ?? '')?.group(2) ??
                    RegExp(r'(\d+)').firstMatch(m['name'] ?? '')?.group(1) ??
                    '0',
              ) ??
              0,
          actualScore: finalScore,
          winnerId: winnerId,
          location: m['venue'] ?? 'Stadium',
        ),
      );
    }

    return matches;
  }

  static Future<List<MatchModel>> _tryFetchCricApiSeries(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    try {
      String? seriesSearchQuery;
      final yearMatch = RegExp(r'(20\d{2})').firstMatch(leagueId);
      final String? targetYear = yearMatch?.group(1);

      // Order matters: Check more specific patterns first
      if (leagueId.contains('ipl')) {
        seriesSearchQuery = 'Indian Premier League';
      } else if (leagueId.contains('bbl')) {
        seriesSearchQuery = 'Big Bash';
      } else if (leagueId.contains('psl')) {
        seriesSearchQuery = 'Pakistan Super League';
      } else if (leagueId.contains('sa20')) {
        seriesSearchQuery = 'SA20';
      } else if (leagueId.contains('ilt20')) {
        seriesSearchQuery = 'ILT20';
      } else if (leagueId.contains('smash')) {
        seriesSearchQuery = 'Super Smash';
      } else if (leagueId.contains('t20-world-cup') ||
          leagueId.contains('wc20') ||
          leagueId == 'mens-t20-world-cup-2026') {
        seriesSearchQuery = 'T20 World Cup';
      } else if (leagueId.contains('cwc') || leagueId.contains('world-cup')) {
        seriesSearchQuery = 'World Cup';
      } else if (leagueId.contains('t20')) {
        seriesSearchQuery = 'T20';
      }

      if (seriesSearchQuery != null) {
        final Set<String> matchingIds = {};

        // CHECK CACHE FIRST (Save 5 calls!)
        if (_seriesIdsCache.containsKey(leagueId) &&
            _seriesIdsCache[leagueId]!.isNotEmpty) {
          debugPrint('Using cached Series IDs for $leagueId');
          matchingIds.addAll(_seriesIdsCache[leagueId]!);
        } else {
          // Fetch ALL series first
          final allSeries = await CricApiService().getSeriesList();

          // Find all matching series (e.g. "Warm up" + "Main Event")
          final normalizedQuery = seriesSearchQuery.toLowerCase();
          for (var s in allSeries) {
            final sName = s['name'].toString().toLowerCase();
            if (sName.contains(normalizedQuery)) {
              // Apply Year filtering if available (e.g. don't pull 2024 for a 2026 league)
              if (targetYear != null) {
                if (!sName.contains(targetYear)) continue;
              }
              // Check dates to prioritize current year? (Assume API returns recent)
              matchingIds.add(s['id']);
              debugPrint(
                'DEBUG: Found matching series: ${s['name']} (${s['id']})',
              );
            }
          }
          // Populate Cache if found
          if (matchingIds.isNotEmpty) {
            _seriesIdsCache[leagueId] = matchingIds;
          }
        }

        if (matchingIds.isEmpty) {
          debugPrint('DEBUG: No series found for query: $seriesSearchQuery');
        }

        if (matchingIds.isNotEmpty) {
          List<Map<String, dynamic>> allMatches = [];
          int attempts = 0;

          // Fetch matches for top matching series (Limit to 3 to avoid rate limits)
          for (var id in matchingIds) {
            if (attempts >= 3) break;
            try {
              final m = await CricApiService().getSeriesMatches(id);
              allMatches.addAll(m);
              attempts++;
            } catch (e) {
              debugPrint('Error fetching series matches for $id: $e');
            }
          }

          if (allMatches.isNotEmpty) {
            // (SCORE ENRICHMENT REMOVED: Cricket scores are now manual only)
            return _parseCricApiSeriesMatches(
              competitionId,
              allMatches,
              teamMap,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error trying to fetch CricAPI series: $e');
    }
    return [];
  }

  // UNUSED: _safeParseDate removed as part of cricket score cleanup

  // RAPID API IMPLEMENTATION
  static Future<List<MatchModel>> _tryFetchRapidApiSeries(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    try {
      String? seriesSearchQuery;
      // Extract Year from leagueId if present (e.g. 2024, 2025, 2026)
      final yearMatch = RegExp(r'(20\d{2})').firstMatch(leagueId);
      final String? targetYear = yearMatch?.group(1);

      if (leagueId.contains('ipl')) {
        seriesSearchQuery = 'Indian Premier League';
      } else if (leagueId.contains('bbl')) {
        seriesSearchQuery = 'Big Bash';
      } else if (leagueId.contains('psl')) {
        seriesSearchQuery = 'Pakistan Super League';
      } else if (leagueId.contains('sa20')) {
        seriesSearchQuery = 'SA20';
      } else if (leagueId.contains('ilt20')) {
        seriesSearchQuery = 'ILT20';
      } else if (leagueId.contains('smash')) {
        seriesSearchQuery = 'Super Smash';
      } else if (leagueId.contains('t20-world-cup') ||
          leagueId.contains('wc20')) {
        seriesSearchQuery = 'T20 World Cup';
      } else if (leagueId.contains('cwc') || leagueId.contains('world-cup')) {
        seriesSearchQuery = 'World Cup';
      } else if (leagueId.contains('t20')) {
        seriesSearchQuery = 'T20';
      }

      // If we have a target year, append it to query to improve relevance if API supports it
      if (seriesSearchQuery != null && targetYear != null) {
        // seriesSearchQuery = '$seriesSearchQuery $targetYear';
        // Actually RapidAPI search might be fuzzy, better to filter client side
      }

      if (seriesSearchQuery != null) {
        final Set<String> matchingIds = {};

        if (_seriesIdsCache.containsKey(leagueId) &&
            _seriesIdsCache[leagueId]!.isNotEmpty) {
          debugPrint('Using cached Series IDs for $leagueId');
          matchingIds.addAll(_seriesIdsCache[leagueId]!);
        } else {
          final results = await RapidApiService().searchSeries(
            seriesSearchQuery,
          );

          for (var s in results) {
            final sName = s['series_name'].toString();
            // FILTER BY YEAR if targetYear is known
            if (targetYear != null) {
              if (sName.contains(targetYear)) {
                matchingIds.add(s['id'].toString());
              }
            } else {
              // Default behavior: Add all matches? Or only recent?
              // Maybe check if series is active or recent (e.g. current year or next)
              // For now, if no year specified, take all to keep existing behavior
              matchingIds.add(s['id'].toString());
            }
          }

          if (matchingIds.isNotEmpty) {
            _seriesIdsCache[leagueId] = matchingIds;
          }
        }

        if (matchingIds.isEmpty) {
          debugPrint('DEBUG: No series found for query: $seriesSearchQuery');
        }

        List<MatchModel> allMatches = [];
        for (final sid in matchingIds) {
          debugPrint('Fetching fixtures for Series ID: $sid');
          try {
            final rapidMatches = await RapidApiService().getFixtures(sid);

            // (SCORE ENRICHMENT REMOVED: Cricket scores are now manual only)

            final parsed = _parseRapidApiMatches(
              competitionId,
              rapidMatches,
              teamMap,
            );
            allMatches.addAll(parsed);
          } catch (e) {
            debugPrint('Error fetching series $sid: $e');
          }
        }
        return allMatches;
      }
    } catch (e) {
      debugPrint('Error in _tryFetchRapidApiSeries: $e');
    }
    return [];
  }

  static List<MatchModel> _parseRapidApiMatches(
    String competitionId,
    List<Map<String, dynamic>> rapidMatches,
    Map<String, TeamModel> teamMap,
  ) {
    final matches = <MatchModel>[];
    final uuid = const Uuid();

    for (var m in rapidMatches) {
      if (m['home'] == null || m['away'] == null) continue;

      final dateStr = m['date'] as String? ?? '';
      final venue = m['venue'] as String? ?? '';

      final homeName = m['home']['name']?.toString() ?? 'Team A';
      final awayName = m['away']['name']?.toString() ?? 'Team B';
      final homeCode = m['home']['code']?.toString() ?? '';
      final awayCode = m['away']['code']?.toString() ?? '';

      TeamModel? t1, t2;
      for (var t in teamMap.values) {
        if (TeamsDataService.areTeamNamesEquivalent(t.name, homeName)) t1 = t;
        if (TeamsDataService.areTeamNamesEquivalent(t.name, awayName)) t2 = t;
      }

      t1 ??= TeamModel(
        id: uuid.v4(),
        name: homeName,
        shortName: homeCode.isNotEmpty
            ? homeCode
            : homeName.substring(0, 3).toUpperCase(),
        logoUrl: AppConstants.defaultCompetitionLogo,
        competitionId: competitionId,
        createdAt: DateTime.now(),
      );
      t2 ??= TeamModel(
        id: uuid.v4(),
        name: awayName,
        shortName: awayCode.isNotEmpty
            ? awayCode
            : awayName.substring(0, 3).toUpperCase(),
        logoUrl: AppConstants.defaultCompetitionLogo,
        competitionId: competitionId,
        createdAt: DateTime.now(),
      );

      final TeamModel T1 = t1;
      final TeamModel T2 = t2;

      String status = AppConstants.matchStatusUpcoming;
      // (SCORE PARSING REMOVED: Cricket scores are now manual only)
      Map<String, dynamic>? finalScore;
      String wId = '';

      DateTime scheduledTime;
      try {
        scheduledTime = DateTime.parse(dateStr).toLocal();
      } catch (_) {
        scheduledTime = DateTime.now().add(const Duration(days: 30));
      }

      matches.add(
        MatchModel(
          id: uuid.v4(),
          competitionId: competitionId,
          team1Id: T1.id,
          team1Name: T1.name,
          team1LogoUrl: T1.logoUrl,
          team2Id: T2.id,
          team2Name: T2.name,
          team2LogoUrl: T2.logoUrl,
          scheduledTime: scheduledTime,
          status: status,
          location: venue,
          matchNumber:
              int.tryParse(
                RegExp(
                      r'(?:Match\s+|#|(\d+)(?:st|nd|rd|th)\s+Match)(\d+)?',
                    ).firstMatch(m['name'] ?? '')?.group(2) ??
                    RegExp(r'(\d+)').firstMatch(m['name'] ?? '')?.group(1) ??
                    '0',
              ) ??
              0,
          actualScore: finalScore,
          winnerId: wId,
          round: 'Group Stage',
        ),
      );
    }
    return matches;
  }

  static int _getBestIndex(String text, String teamName) {
    final lowerText = text.toLowerCase();

    // Check after colon first if colon exists (ignore match title prefix)
    String searchIn = lowerText;
    int offset = 0;
    if (lowerText.contains(':')) {
      int colonIdx = lowerText.indexOf(':');
      searchIn = lowerText.substring(colonIdx + 1);
      offset = colonIdx + 1;
    }

    int minIdx = -1;
    final aliases = TeamsDataService.getTeamAliases(teamName);
    for (var alias in aliases) {
      final aLower = alias.toLowerCase();
      final match = RegExp(
        '\\b${RegExp.escape(aLower)}\\b',
      ).firstMatch(searchIn);
      if (match != null) {
        int idx = match.start + offset;
        if (minIdx == -1 || idx < minIdx) minIdx = idx;
      }
    }
    return minIdx;
  }

  static bool _checkAfterWonBy(String text, String teamName) {
    final lowerText = text.toLowerCase();
    String searchIn = lowerText;
    if (lowerText.contains(':')) {
      searchIn = lowerText.substring(lowerText.indexOf(':') + 1);
    }

    final aliases = TeamsDataService.getTeamAliases(teamName);
    for (var a in aliases) {
      if (searchIn.contains('won by ${a.toLowerCase()}')) return true;
    }
    return false;
  }

  static String _formatRoundName(String leagueId, int roundNumber) {
    if (leagueId == 'mens-t20-world-cup-2026') {
      if (roundNumber >= 1 && roundNumber <= 5) return 'Group Stage';
      if (roundNumber >= 6 && roundNumber <= 8) return 'Super 8';
      if (roundNumber == 9) return 'Semi Final';
      if (roundNumber == 10) return 'Final';
    } else if (leagueId == 'fifa-world-cup-2026' || leagueId == 'wc2026') {
      if (roundNumber >= 1 && roundNumber <= 3) return 'Group Stage';
      if (roundNumber == 4) return 'Round of 32';
      if (roundNumber == 5) return 'Round of 16';
      if (roundNumber == 6) return 'Quarter Final';
      if (roundNumber == 7) return 'Semi Final';
      if (roundNumber == 8) return 'Final';
    }
    return 'Round $roundNumber';
  }

  static String _getCricketMatchRound(String matchName) {
    final name = matchName.toLowerCase();
    if (name.contains('final') && !name.contains('semi')) return 'Final';
    if (name.contains('semi-final') ||
        name.contains('semi final') ||
        name.contains('semifinal')) {
      return 'Semi Final';
    }
    if (name.contains('super 8') || name.contains('super8')) return 'Super 8';
    if (name.contains('super 4') || name.contains('super4')) return 'Super 4';
    if (name.contains('qualifier')) return 'Qualifiers';
    if (name.contains('eliminator')) return 'Eliminator';
    if (name.contains('group')) return 'Group Stage';
    if (name.contains('match')) return 'Group Stage';
    return 'Group Stage';
  }
}
