import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_usage_tracker.dart';

class RapidApiService {
  static const String _baseUrl = 'https://${AppConstants.rapidApiHost}';

  Future<dynamic> _get(Uri url) async {
    if (AppConstants.rapidApiKey.isEmpty) {
      debugPrint('RapidAPI Key is missing in AppConstants');
      return null;
    }
    try {
      final response = await http.get(
        url,
        headers: {
          'x-rapidapi-key': AppConstants.rapidApiKey,
          'x-rapidapi-host': AppConstants.rapidApiHost,
        },
      );

      // Track API usage
      ApiUsageTracker().recordRapidApiCall(response.headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('RapidAPI Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('RapidAPI Exception for $url: $e');
    }
    return null;
  }

  /// Search for leagues by name (Client-side filtering)
  Future<List<Map<String, dynamic>>> searchSeries(String query) async {
    // API returns all leagues. We filter locally.
    // Fetch with high limit to get most leagues
    final url = Uri.parse('$_baseUrl/leagues?limit=500');
    final response = await _get(url);

    if (response != null && response['data'] is List) {
      final allLeagues = response['data'] as List;
      final lowerQuery = query.toLowerCase();

      final matches = <Map<String, dynamic>>[];
      for (var l in allLeagues) {
        final name = (l['name'] ?? '').toString();
        // Loose matching
        if (name.toLowerCase().contains(lowerQuery)) {
          matches.add({
            'id': l['id'],
            'series_name': name,
            'status': (l['season'] ?? '')
                .toString(), // Use season as status placeholder
            'start_date': '',
            'end_date': '',
          });
        }
      }
      return matches;
    }
    return [];
  }

  /// Get fixtures for a league ID
  Future<List<Map<String, dynamic>>> getFixtures(String leagueId) async {
    final url = Uri.parse('$_baseUrl/matches?leagueId=$leagueId&limit=100');
    final response = await _get(url);

    if (response != null && response['data'] is List) {
      final apiMatches = response['data'] as List;
      final mappedList = <Map<String, dynamic>>[];

      for (var m in apiMatches) {
        // Map New API structure to Old Structure expected by Parser
        final state = m['state'] ?? {};
        final statusDesc = (state['description'] ?? state['status'] ?? '')
            .toString(); // e.g. "Result", "Cancelled"

        final home = m['homeTeam'] ?? {};
        final away = m['awayTeam'] ?? {};

        final homeScore = state['teams']?['home']?['score'];
        final awayScore = state['teams']?['away']?['score'];

        // Construct "details" object for immediate score use
        // Old structure expected: details['live_details']['match_summary']['home_scores']
        final details = {
          'live_details': {
            'match_summary': {
              'home_scores': homeScore ?? '',
              'away_scores': awayScore ?? '',
              'status': statusDesc,
              'result': statusDesc, // result string might need construction?
            },
          },
        };

        mappedList.add({
          'id': m['id'],
          'name': m['name'],
          'status': statusDesc.contains('Result') || statusDesc == 'Finished'
              ? 'Finished'
              : statusDesc.contains('Cancelled')
              ? 'Abandoned'
              : 'Scheduled', // Map to standard status
          'result': statusDesc, // Use description as result text
          'date': m['startTime'],
          'venue': m['venue']?.toString() ?? '', // Check if venue exists
          'home': {
            'name': home['name'],
            'code': home['abbreviation'],
            'id': home['id'],
          },
          'away': {
            'name': away['name'],
            'code': away['abbreviation'],
            'id': away['id'],
          },
          // Pre-populate details!
          'details': details,
        });
      }
      return mappedList;
    }
    return [];
  }

  /// Get match details (No-op as list has details)
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    // New API provides details in list. Return null to signal no extra fetch needed?
    // Or return empty map?
    return null;
  }
}
