import 'dart:convert';
import 'package:http/http.dart' as http;

// Mock AppConstants to avoid dependency issues
class AppConstants {
  static const String cricApiKey = '5cfd83f3-0d98-4ebc-a50c-2f5d3fe0ada7';
}

void main() async {
  print('🏏 Verifying T20 Scores Integrity...');

  // 1. Fetch Fixtures (Source of Truth for Schedule)
  const leagueUrl =
      'https://fixturedownload.com/feed/json/mens-t20-world-cup-2026';
  print('\n📍 Step 1: Fetching fixtures from $leagueUrl...');

  List<dynamic> fixtures = [];
  try {
    final response = await http.get(Uri.parse(leagueUrl));
    if (response.statusCode == 200) {
      fixtures = json.decode(response.body);
      print('✅ Fetched ${fixtures.length} scheduled fixtures.');
    } else {
      print('❌ Failed to fetch fixtures: ${response.statusCode}');
      return;
    }
  } catch (e) {
    print('❌ Error fetching fixtures: $e');
    return;
  }

  // 2. Fetch CricAPI Data (Source of Truth for Scores)
  print('\n📍 Step 2: Fetching live data from CricAPI...');
  List<Map<String, dynamic>> cricMatches = [];
  try {
    final url =
        'https://api.cricapi.com/v1/currentMatches?apikey=${AppConstants.cricApiKey}&offset=0';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] != 'failure') {
        final List<dynamic> list = data['data'] ?? [];
        cricMatches = list.cast<Map<String, dynamic>>();
        print('✅ Fetched ${cricMatches.length} matches from CricAPI.');
      } else {
        print('❌ CricAPI returned failure: ${data['reason']}');
      }
    } else {
      print('❌ CricAPI HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching CricAPI: $e');
  }

  // 3. Analyze Data
  print('\n${'=' * 50}');
  print('ANALYSIS');
  print('=' * 50);

  // CricAPI Inspection
  print('CricAPI Current Matches Breakdown:');
  if (cricMatches.isEmpty) {
    print('  (No current matches returned)');
  } else {
    for (var m in cricMatches) {
      final names = m['name'] ?? 'Unknown';
      final status = m['status'] ?? 'No Status';
      print('  - $names [$status]');
    }
  }

  // Fixture Inspection
  if (fixtures.isEmpty) {
    print('No Fixtures found.');
    return;
  }

  // Sort by date (Ascending)
  fixtures.sort((a, b) => a['DateUtc'].compareTo(b['DateUtc']));
  final firstMatch = fixtures.first;
  final lastMatch = fixtures.last;

  print('\nFixture Schedule Range:');
  print(
    '  Start: ${firstMatch['DateUtc']} (${firstMatch['HomeTeam']} vs ${firstMatch['AwayTeam']})',
  );
  print(
    '  End:   ${lastMatch['DateUtc']} (${lastMatch['HomeTeam']} vs ${lastMatch['AwayTeam']})',
  );

  final now = DateTime.now(); // 2026-02-10
  print('  Current simulated date: $now');

  // Check for matches that SHOULD have scores (Status Completed or Live)
  // or matches that are in the past.
  final pastMatches = fixtures.where((f) {
    final d = DateTime.tryParse(f['DateUtc']);
    return d != null && d.isBefore(now);
  }).toList();

  print(
    '\nPast Fixtures (Should potentially have scores): ${pastMatches.length}',
  );

  for (var fixture in pastMatches) {
    final home = fixture['HomeTeam'];
    final away = fixture['AwayTeam'];
    final date = fixture['DateUtc'];

    // Try to find in CricAPI
    // Note: CricAPI 'currentMatches' usually returns live + recently completed.
    // If a match is long past, it might not be in 'currentMatches'.

    bool found = false;
    for (var cm in cricMatches) {
      final name = cm['name'].toString().toLowerCase();
      // Use a looser check - if the names are similar enough
      if (name.contains(home.toString().toLowerCase()) &&
          name.contains(away.toString().toLowerCase())) {
        found = true;
        print('  ✅ Found in CricAPI: $home vs $away ($date)');
        // Check if score exists
        if (cm['score'] != null) {
          final scores = cm['score'] as List;
          final scoreStr = scores
              .map((s) => "${s['r']}/${s['w']} (${s['o']}ov)")
              .join(' vs ');
          print('     Score: $scoreStr');
        } else {
          print('     Score: (None)');
        }
        print('     Status: ${cm['status']}');
        break;
      }
    }

    if (!found) {
      print('  ❌ Missing from CricAPI: $home vs $away ($date)');
      // This means we need to fix matching or the API doesn't have it
    }
  }
}
