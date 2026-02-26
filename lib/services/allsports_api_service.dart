import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Service for interacting with AllSportsApi (RapidAPI)
/// Provides access to tournament data, team events, and match information
class AllSportsApiService {
  static const String _baseUrl = 'https://allsportsapi2.p.rapidapi.com';

  /// Fetches all available sports
  /// Returns a list of sports with their IDs and names
  Future<List<Map<String, dynamic>>> getSports() async {
    final url = Uri.parse('$_baseUrl/api/sports');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['sports'] != null) {
          return List<Map<String, dynamic>>.from(data['sports']);
        } else {
          debugPrint('AllSportsApi: No sports found in response');
          return [];
        }
      } else {
        debugPrint(
          'AllSportsApi Sports Error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching sports: $e');
      return [];
    }
  }

  /// Fetches all tournaments for a specific sport
  ///
  /// [sportId] - The sport ID (1=Football, 2=Basketball, 3=Cricket, etc.)
  Future<List<Map<String, dynamic>>> getTournamentsBySport(int sportId) async {
    final url = Uri.parse('$_baseUrl/api/sport/$sportId/tournaments');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['groups'] != null) {
          // Extract tournaments from groups
          List<Map<String, dynamic>> tournaments = [];
          for (var group in data['groups']) {
            if (group['uniqueTournaments'] != null) {
              tournaments.addAll(
                List<Map<String, dynamic>>.from(group['uniqueTournaments']),
              );
            }
          }
          return tournaments;
        } else {
          debugPrint('AllSportsApi: No tournaments found');
          return [];
        }
      } else {
        debugPrint('AllSportsApi Tournaments Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching tournaments: $e');
      return [];
    }
  }

  /// Fetches seasons for a specific tournament
  ///
  /// [tournamentId] - The tournament ID
  Future<List<Map<String, dynamic>>> getTournamentSeasons(
    String tournamentId,
  ) async {
    final url = Uri.parse('$_baseUrl/api/tournament/$tournamentId/seasons');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['seasons'] != null) {
          return List<Map<String, dynamic>>.from(data['seasons']);
        } else {
          debugPrint('AllSportsApi: No seasons found');
          return [];
        }
      } else {
        debugPrint('AllSportsApi Seasons Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching seasons: $e');
      return [];
    }
  }

  /// Searches for tournaments by name
  ///
  /// [query] - The search query (e.g., "Premier League", "IPL", "World Cup")
  Future<List<Map<String, dynamic>>> searchTournaments(String query) async {
    final url = Uri.parse('$_baseUrl/api/search/$query');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null) {
          return List<Map<String, dynamic>>.from(data['results']);
        } else {
          debugPrint('AllSportsApi: No search results found');
          return [];
        }
      } else {
        debugPrint('AllSportsApi Search Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception searching tournaments: $e');
      return [];
    }
  }

  /// Fetches season team events for away matches
  ///
  /// [tournamentId] - The tournament ID (e.g., for specific league/competition)
  /// [seasonId] - The season ID
  /// Returns a list of match events
  Future<List<Map<String, dynamic>>> getSeasonTeamEventsAway({
    required String tournamentId,
    required String seasonId,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api/tournament/$tournamentId/season/$seasonId/events/away',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['events'] != null) {
          return List<Map<String, dynamic>>.from(data['events']);
        } else {
          debugPrint('AllSportsApi: No events found in response');
          return [];
        }
      } else {
        debugPrint(
          'AllSportsApi Error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching AllSportsApi events: $e');
      return [];
    }
  }

  /// Fetches tournament standings
  ///
  /// [tournamentId] - The tournament ID
  /// [seasonId] - The season ID
  Future<Map<String, dynamic>?> getTournamentStandings({
    required String tournamentId,
    required String seasonId,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api/tournament/$tournamentId/season/$seasonId/standings/total',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('AllSportsApi Standings Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception fetching standings: $e');
      return null;
    }
  }

  /// Fetches team information
  ///
  /// [teamId] - The team ID
  Future<Map<String, dynamic>?> getTeamInfo(String teamId) async {
    final url = Uri.parse('$_baseUrl/api/team/$teamId');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('AllSportsApi Team Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception fetching team info: $e');
      return null;
    }
  }

  /// Fetches match details
  ///
  /// [eventId] - The event/match ID
  Future<Map<String, dynamic>?> getMatchDetails(String eventId) async {
    final url = Uri.parse('$_baseUrl/api/event/$eventId');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('AllSportsApi Match Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception fetching match details: $e');
      return null;
    }
  }

  /// Fetches live matches for a specific sport
  ///
  /// [sportId] - The sport ID (1=Football, 2=Basketball, 3=Cricket, etc.)
  Future<List<Map<String, dynamic>>> getLiveMatches(int sportId) async {
    final url = Uri.parse('$_baseUrl/api/sport/$sportId/events/live');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': AppConstants.allSportsApiKey,
          'X-RapidAPI-Host': AppConstants.allSportsApiHost,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['events'] != null) {
          return List<Map<String, dynamic>>.from(data['events']);
        } else {
          return [];
        }
      } else {
        debugPrint('AllSportsApi Live Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching live matches: $e');
      return [];
    }
  }
}
