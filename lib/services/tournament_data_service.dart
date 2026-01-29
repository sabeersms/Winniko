import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/external_fixture_model.dart';
import 'teams_data_service.dart';
import 'firestore_service.dart';

class TournamentDataService {
  static final Map<String, DateTime> _lastRefreshTimes = {};

  static const Map<String, String> _leagueUrls = {
    'pl': 'https://fixturedownload.com/feed/json/epl-2025',
    'laliga': 'https://fixturedownload.com/feed/json/la-liga-2025',
    'bundesliga': 'https://fixturedownload.com/feed/json/bundesliga-2025',
    'seriea': 'https://fixturedownload.com/feed/json/serie-a-2025',
    'ligue1': 'https://fixturedownload.com/feed/json/ligue-1-2025',
    'ucl': 'https://fixturedownload.com/feed/json/champions-league-2025',
    'wc2026': 'https://fixturedownload.com/feed/json/fifa-world-cup-2026',
  };

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
    // Assume search-based ID is a direct slug for fixturedownload
    return 'https://fixturedownload.com/feed/json/$leagueId';
  }

  static Future<List<MatchModel>> getTournamentFixtures(
    String competitionId,
    String leagueId,
    List<TeamModel> teams,
  ) async {
    // 1. Prepare dynamic URL logic
    final Map<String, TeamModel> teamMap = {
      for (var t in teams) t.shortName: t,
    };

    // 2. Try to fetch live data (curated or dynamic)
    try {
      final matches = await _fetchAndParseFixtures(
        competitionId,
        leagueId,
        teamMap,
      );
      if (matches.isNotEmpty) return matches;
    } catch (e) {
      debugPrint('Error fetching fixtures for $leagueId: $e');
    }

    // 3. Fallback (e.g. for offline dev or internal types)

    if (leagueId == 'pl') {
      return _getPremierLeagueFixtures(competitionId, teamMap);
    }

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
    final matches = <MatchModel>[];
    final uuid = const Uuid();
    final List<TeamModel> allTeams = teamMap.values.toList();

    if (allTeams.length < 2) return [];

    // Simple Round Robin / Sample Fixtures
    int matchNumber = 1;
    DateTime startTime = DateTime.now().add(const Duration(days: 1));

    if (leagueId == 'ipl') {
      // IPL Sample matches (first 10 matches)
      for (int i = 0; i < allTeams.length; i++) {
        final team1 = allTeams[i];
        final team2 = allTeams[(i + 1) % allTeams.length];

        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: team1.id,
            team1Name: team1.name,
            team1LogoUrl: team1.logoUrl,
            team2Id: team2.id,
            team2Name: team2.name,
            team2LogoUrl: team2.logoUrl,
            scheduledTime: startTime.add(Duration(days: i)),
            status: 'upcoming',
            round: 'Group Stage',
            matchNumber: matchNumber++,
            location: 'Various Stadiums, India',
          ),
        );
        if (matchNumber > 10) break;
      }
    } else if (leagueId == 'asiacup') {
      // Asia Cup Sample
      for (int i = 0; i < allTeams.length; i += 2) {
        if (i + 1 >= allTeams.length) break;
        final team1 = allTeams[i];
        final team2 = allTeams[i + 1];

        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: team1.id,
            team1Name: team1.name,
            team1LogoUrl: team1.logoUrl,
            team2Id: team2.id,
            team2Name: team2.name,
            team2LogoUrl: team2.logoUrl,
            scheduledTime: startTime.add(Duration(days: i ~/ 2)),
            status: 'upcoming',
            round: 'Group Stage',
            matchNumber: matchNumber++,
            location: 'Sri Lanka/Pakistan',
          ),
        );
      }
    } else if (leagueId == 'cwc') {
      // World Cup Sample
      // Use some major teams if available in the map
      final sampleTeams = allTeams.take(10).toList();
      for (int i = 0; i < sampleTeams.length; i += 2) {
        if (i + 1 >= sampleTeams.length) break;
        final team1 = sampleTeams[i];
        final team2 = sampleTeams[i + 1];

        matches.add(
          MatchModel(
            id: uuid.v4(),
            competitionId: competitionId,
            team1Id: team1.id,
            team1Name: team1.name,
            team1LogoUrl: team1.logoUrl,
            team2Id: team2.id,
            team2Name: team2.name,
            team2LogoUrl: team2.logoUrl,
            scheduledTime: startTime.add(Duration(days: i ~/ 2)),
            status: 'upcoming',
            round: 'Group Stage',
            matchNumber: matchNumber++,
            location: 'Various Locations',
          ),
        );
      }
    }

    return matches;
  }

  /// Fetches the current state of ALL matches in a league (scores + status)
  static Future<List<MatchModel>> getLatestScores(
    String competitionId,
    String leagueId,
    List<TeamModel> teams,
  ) async {
    final Map<String, TeamModel> teamMap = {
      for (var t in teams) t.shortName: t,
    };

    // Use ESPN for Premier League
    if (leagueId == 'pl') {
      try {
        final matches = await _fetchEspnFixtures(
          competitionId,
          leagueId,
          teamMap,
        );
        if (matches.isNotEmpty) return matches;
      } catch (e) {
        debugPrint('Error fetching ESPN scores: $e');
      }
    }

    if (_leagueUrls.containsKey(leagueId)) {
      try {
        return await _fetchAndParseFixtures(competitionId, leagueId, teamMap);
      } catch (e) {
        debugPrint('Error fetching latest scores for $leagueId: $e');
      }
    }
    return [];
  }

  static Future<List<MatchModel>> _fetchAndParseFixtures(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    final url = _getFixtureUrl(leagueId);

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load fixtures: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
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
          status: _inferMatchStatus(
            scheduledTime,
            externalMatch.homeTeamScore,
            externalMatch.awayTeamScore,
          ),
          round: 'Round ${externalMatch.roundNumber}',
          group: externalMatch.group,
          matchNumber: externalMatch.matchNumber,
          actualScore:
              (externalMatch.homeTeamScore != null &&
                  externalMatch.awayTeamScore != null)
              ? {
                  'team1': externalMatch.homeTeamScore!,
                  'team2': externalMatch.awayTeamScore!,
                }
              : null,
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
    if (homeScore == null || awayScore == null) {
      return 'upcoming';
    }

    final now = DateTime.now();
    // Assuming a football match + break + injury time takes roughly 110-120 mins.
    // Let's use 130 mins to be safe for "Live".
    // If it has scores and is within 130 mins of start, it's Live.
    // Otherwise Completed.
    final difference = now.difference(scheduledTime).inMinutes;
    if (difference >= 0 && difference < 130) {
      return 'live';
    }
    return 'completed';
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
    Map<String, TeamModel> teamMap,
  ) async {
    // Public ESPN Status Endpoint for EPL
    const url =
        'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard';

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

      // 1. Exact Name
      for (var t in teamMap.values) {
        if (t.name == homeName) homeTeam = t;
        if (t.name == awayName) awayTeam = t;
      }

      // 2. Fuzzy/Contains
      if (homeTeam == null || awayTeam == null) {
        for (var t in teamMap.values) {
          if (homeTeam == null &&
              (t.name.contains(homeName) || homeName.contains(t.name))) {
            homeTeam = t;
          }
          if (awayTeam == null &&
              (t.name.contains(awayName) || awayName.contains(t.name))) {
            awayTeam = t;
          }
        }
      }

      if (homeTeam == null || awayTeam == null) {
        // debugPrint('ESPN: Team not found $homeNameRaw vs $awayNameRaw');
        continue;
      }
      // debugPrint('ESPN SYNC: Found ${homeTeam.name} vs ${awayTeam.name} (Status: $statusType)');

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
        };
      }

      matches.add(
        MatchModel(
          id: uuid.v4(),
          competitionId: competitionId,
          team1Id: homeTeam.id,
          team2Id: awayTeam.id,
          team1Name: homeTeam.name,
          team2Name: awayTeam.name,
          // date: date, // Removed
          scheduledTime: date, // Pass DateTime directly
          status: status,
          round: '1', // String
          matchNumber: 0,
          actualScore: actualScore,
          group: 'League',
        ),
      );
    }
    return matches;
  }

  /// Refresh schedules and scores for an active competition tied to an official source
  static Future<void> refreshCompetitionFixtures({
    required String competitionId,
    required String leagueId,
    required FirestoreService firestore,
  }) async {
    try {
      // Throttle Check (15 minutes)
      final lastRefresh = _lastRefreshTimes[competitionId];
      if (lastRefresh != null &&
          DateTime.now().difference(lastRefresh).inMinutes < 15) {
        debugPrint(
          'Skipping fixture refresh for $competitionId (Throttled: ${DateTime.now().difference(lastRefresh).inMinutes}m ago)',
        );
        return;
      }
      _lastRefreshTimes[competitionId] = DateTime.now();

      // 1. Get current state
      final teams = await firestore.getTeams(competitionId).first;
      final internalMatches = await firestore.getMatches(competitionId).first;

      // 2. Fetch latest from source
      final externalMatches = await _fetchAndParseFixtures(
        competitionId,
        leagueId,
        {for (var t in teams) t.shortName: t},
      );

      if (externalMatches.isEmpty) return;

      final List<MatchModel> matchUpdates = [];
      final now = DateTime.now();

      for (var ext in externalMatches) {
        // Find internal counterpart by team names
        final internal = internalMatches.firstWhere(
          (m) => m.team1Id == ext.team1Id && m.team2Id == ext.team2Id,
          orElse: () => internalMatches.firstWhere(
            (m) =>
                m.team1Id == ext.team2Id &&
                m.team2Id == ext.team1Id, // Handle reverse direction if any
            orElse: () => MatchModel(
              id: 'notfile',
              competitionId: '',
              team1Id: '',
              team2Id: '',
              team1Name: '',
              team2Name: '',
              scheduledTime: now,
              status: '',
            ),
          ),
        );

        if (internal.id == 'notfile') continue;

        // Compare and detect changes
        bool changed = false;
        var updated = internal;

        // Check time change (> 1 min)
        if (internal.scheduledTime
                .difference(ext.scheduledTime)
                .inMinutes
                .abs() >
            1) {
          updated = updated.copyWith(scheduledTime: ext.scheduledTime);
          changed = true;
        }

        // Check status change
        if (internal.status != ext.status) {
          updated = updated.copyWith(status: ext.status);
          changed = true;
        }

        // Check score change
        if (ext.actualScore != null) {
          final s1 = internal.actualScore;
          final s2 = ext.actualScore!;
          if (s1 == null ||
              s1['team1'] != s2['team1'] ||
              s1['team2'] != s2['team2']) {
            updated = updated.copyWith(actualScore: s2);
            changed = true;
          }
        }

        if (changed) {
          matchUpdates.add(updated);
        }
      }

      if (matchUpdates.isNotEmpty) {
        await firestore.updateBatchMatches(competitionId, matchUpdates);
        debugPrint(
          'Refreshed ${matchUpdates.length} matches for $competitionId',
        );
      }
    } catch (e) {
      debugPrint('Error refreshing fixtures: $e');
    }
  }
}
