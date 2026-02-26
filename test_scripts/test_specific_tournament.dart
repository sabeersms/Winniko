import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test AllSportsApi with T20 World Cup 2026
///
/// This script tests the API integration with a real tournament
void main() async {
  const apiKey = '04a2aaf5d7msh17a87f735bae4c66p1c2dbjsned2c6683a1s59';
  const apiHost = 'allsportsapi2.p.rapidapi.com';
  const baseUrl = 'https://allsportsapi2.p.rapidapi.com';

  print('🏏 Testing AllSportsApi with T20 World Cup 2026');
  print('=' * 70);

  // Step 1: Search for T20 World Cup
  print('\n📍 Step 1: Searching for "T20 World Cup"...');
  try {
    final searchUrl = Uri.parse('$baseUrl/api/search/T20 World Cup');
    final searchResponse = await http.get(
      searchUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (searchResponse.statusCode == 200) {
      final searchData = json.decode(searchResponse.body);
      print('✅ Search successful! Status: ${searchResponse.statusCode}');

      if (searchData['results'] != null) {
        final results = searchData['results'] as List;
        print('📊 Found ${results.length} results:');

        for (var i = 0; i < results.length && i < 5; i++) {
          final result = results[i];
          final entity = result['entity'];
          if (entity != null) {
            print('   ${i + 1}. ${entity['name']}');
            print('      - ID: ${entity['id']}');
            print('      - Type: ${result['type']}');
            if (entity['category'] != null) {
              print('      - Category: ${entity['category']['name']}');
            }
          }
        }
      }
    } else {
      print('❌ Search failed: ${searchResponse.statusCode}');
      print('Response: ${searchResponse.body}');
    }
  } catch (e) {
    print('❌ Search error: $e');
  }

  // Step 2: Get T20 World Cup tournament details (ID: 132)
  print('\n📍 Step 2: Getting T20 World Cup seasons (Tournament ID: 132)...');
  try {
    final seasonsUrl = Uri.parse('$baseUrl/api/tournament/132/seasons');
    final seasonsResponse = await http.get(
      seasonsUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (seasonsResponse.statusCode == 200) {
      final seasonsData = json.decode(seasonsResponse.body);
      print('✅ Seasons fetched! Status: ${seasonsResponse.statusCode}');

      if (seasonsData['seasons'] != null) {
        final seasons = seasonsData['seasons'] as List;
        print('📅 Found ${seasons.length} seasons:');

        for (var i = 0; i < seasons.length && i < 5; i++) {
          final season = seasons[i];
          print('   ${i + 1}. ${season['name'] ?? season['year']}');
          print('      - Season ID: ${season['id']}');
          print('      - Year: ${season['year']}');
        }

        // Find 2026 season
        final season2026 = seasons.firstWhere(
          (s) => s['year']?.toString() == '2026',
          orElse: () => seasons.isNotEmpty ? seasons[0] : null,
        );

        if (season2026 != null) {
          final seasonId = season2026['id'];
          print('\n🎯 Using 2026 season (ID: $seasonId)');

          // Step 3: Get matches for this season
          print('\n📍 Step 3: Fetching matches for T20 World Cup 2026...');
          await _testGetMatches(
            apiKey,
            apiHost,
            baseUrl,
            '132',
            seasonId.toString(),
          );

          // Step 4: Get standings
          print('\n📍 Step 4: Fetching standings for T20 World Cup 2026...');
          await _testGetStandings(
            apiKey,
            apiHost,
            baseUrl,
            '132',
            seasonId.toString(),
          );
        }
      }
    } else {
      print('❌ Seasons fetch failed: ${seasonsResponse.statusCode}');
      print('Response: ${seasonsResponse.body}');
    }
  } catch (e) {
    print('❌ Seasons error: $e');
  }

  // Step 5: Test with IPL as backup (more likely to have current data)
  print('\n${'=' * 70}');
  print('🏏 Testing with IPL 2024 (Tournament ID: 234)...');
  print('=' * 70);

  await _testIPL(apiKey, apiHost, baseUrl);

  // Step 6: Get live cricket matches
  print('\n📍 Step 6: Fetching live cricket matches...');
  await _testLiveMatches(apiKey, apiHost, baseUrl);

  print('\n✅ All tests complete!');
  print('=' * 70);
}

Future<void> _testGetMatches(
  String apiKey,
  String apiHost,
  String baseUrl,
  String tournamentId,
  String seasonId,
) async {
  try {
    final eventsUrl = Uri.parse(
      '$baseUrl/api/tournament/$tournamentId/season/$seasonId/events/next/0',
    );
    final eventsResponse = await http.get(
      eventsUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (eventsResponse.statusCode == 200) {
      final eventsData = json.decode(eventsResponse.body);
      print('✅ Matches fetched! Status: ${eventsResponse.statusCode}');

      if (eventsData['events'] != null) {
        final events = eventsData['events'] as List;
        print('🏆 Found ${events.length} matches');

        for (var i = 0; i < events.length && i < 5; i++) {
          final event = events[i];
          final homeTeam = event['homeTeam']?['name'] ?? 'Unknown';
          final awayTeam = event['awayTeam']?['name'] ?? 'Unknown';
          final status = event['status']?['description'] ?? 'Scheduled';
          final timestamp = event['startTimestamp'];

          String dateStr = 'TBD';
          if (timestamp != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            dateStr = '${date.day}/${date.month}/${date.year}';
          }

          print('   ${i + 1}. $homeTeam vs $awayTeam');
          print('      - Status: $status');
          print('      - Date: $dateStr');
          print('      - Event ID: ${event['id']}');
        }
      } else {
        print('⚠️  No matches found for this season');
      }
    } else {
      print('❌ Matches fetch failed: ${eventsResponse.statusCode}');
      print('Response: ${eventsResponse.body}');
    }
  } catch (e) {
    print('❌ Matches error: $e');
  }
}

Future<void> _testGetStandings(
  String apiKey,
  String apiHost,
  String baseUrl,
  String tournamentId,
  String seasonId,
) async {
  try {
    final standingsUrl = Uri.parse(
      '$baseUrl/api/tournament/$tournamentId/season/$seasonId/standings/total',
    );
    final standingsResponse = await http.get(
      standingsUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (standingsResponse.statusCode == 200) {
      final standingsData = json.decode(standingsResponse.body);
      print('✅ Standings fetched! Status: ${standingsResponse.statusCode}');

      if (standingsData['standings'] != null) {
        final standings = standingsData['standings'] as List;
        print('📊 Found ${standings.length} standing groups');

        for (var group in standings) {
          if (group['rows'] != null) {
            final rows = group['rows'] as List;
            print('   Group: ${group['name'] ?? 'Main'}');

            for (var i = 0; i < rows.length && i < 5; i++) {
              final row = rows[i];
              final team = row['team']?['name'] ?? 'Unknown';
              final position = row['position'] ?? i + 1;
              final points = row['points'] ?? 0;
              final wins = row['wins'] ?? 0;

              print('      $position. $team - $points pts ($wins wins)');
            }
          }
        }
      } else {
        print('⚠️  No standings available for this season');
      }
    } else {
      print('❌ Standings fetch failed: ${standingsResponse.statusCode}');
      print('Response: ${standingsResponse.body}');
    }
  } catch (e) {
    print('❌ Standings error: $e');
  }
}

Future<void> _testIPL(String apiKey, String apiHost, String baseUrl) async {
  try {
    // Get IPL seasons
    final seasonsUrl = Uri.parse('$baseUrl/api/tournament/234/seasons');
    final seasonsResponse = await http.get(
      seasonsUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (seasonsResponse.statusCode == 200) {
      final seasonsData = json.decode(seasonsResponse.body);

      if (seasonsData['seasons'] != null) {
        final seasons = seasonsData['seasons'] as List;
        print('📅 Found ${seasons.length} IPL seasons');

        // Get latest season
        if (seasons.isNotEmpty) {
          final latestSeason = seasons[0];
          final seasonId = latestSeason['id'];
          final seasonName = latestSeason['name'] ?? latestSeason['year'];

          print('🎯 Testing with: $seasonName (Season ID: $seasonId)');

          // Get matches
          await _testGetMatches(
            apiKey,
            apiHost,
            baseUrl,
            '234',
            seasonId.toString(),
          );
        }
      }
    }
  } catch (e) {
    print('❌ IPL test error: $e');
  }
}

Future<void> _testLiveMatches(
  String apiKey,
  String apiHost,
  String baseUrl,
) async {
  try {
    final liveUrl = Uri.parse('$baseUrl/api/sport/3/events/live');
    final liveResponse = await http.get(
      liveUrl,
      headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
    );

    if (liveResponse.statusCode == 200) {
      final liveData = json.decode(liveResponse.body);
      print('✅ Live matches fetched! Status: ${liveResponse.statusCode}');

      if (liveData['events'] != null) {
        final events = liveData['events'] as List;

        if (events.isEmpty) {
          print('⚠️  No live cricket matches at the moment');
        } else {
          print('🔴 Found ${events.length} LIVE cricket matches:');

          for (var i = 0; i < events.length && i < 5; i++) {
            final event = events[i];
            final homeTeam = event['homeTeam']?['name'] ?? 'Unknown';
            final awayTeam = event['awayTeam']?['name'] ?? 'Unknown';
            final homeScore = event['homeScore']?['current'];
            final awayScore = event['awayScore']?['current'];
            final status = event['status']?['description'] ?? 'Live';

            print('   ${i + 1}. $homeTeam vs $awayTeam');
            if (homeScore != null && awayScore != null) {
              print('      - Score: $homeScore - $awayScore');
            }
            print('      - Status: $status');
            print(
              '      - Tournament: ${event['tournament']?['name'] ?? 'Unknown'}',
            );
          }
        }
      }
    } else {
      print('❌ Live matches fetch failed: ${liveResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Live matches error: $e');
  }
}
