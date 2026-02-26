import 'package:flutter/material.dart';
import 'package:winniko/services/allsports_api_service.dart';

/// Quick test script to explore AllSportsApi
///
/// Run this to see available sports, tournaments, and how to find IDs
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = AllSportsApiService();

  print('🔍 AllSportsApi Tournament Discovery Tool');
  print('=' * 60);

  // Step 1: Get all available sports
  print('\n📋 Step 1: Fetching available sports...');
  final sports = await apiService.getSports();

  if (sports.isNotEmpty) {
    print('✅ Found ${sports.length} sports:');
    for (var sport in sports.take(10)) {
      print('   - ${sport['name']} (ID: ${sport['id']})');
    }
  } else {
    print('❌ No sports found');
  }

  // Step 2: Get tournaments for Cricket (ID: 3)
  print('\n🏏 Step 2: Fetching Cricket tournaments...');
  final cricketTournaments = await apiService.getTournamentsBySport(3);

  if (cricketTournaments.isNotEmpty) {
    print('✅ Found ${cricketTournaments.length} cricket tournaments:');
    for (var tournament in cricketTournaments.take(10)) {
      print('   - ${tournament['name']} (ID: ${tournament['id']})');
    }
  } else {
    print('❌ No cricket tournaments found');
  }

  // Step 3: Search for specific tournaments
  print('\n🔎 Step 3: Searching for "Premier League"...');
  final searchResults = await apiService.searchTournaments('Premier League');

  if (searchResults.isNotEmpty) {
    print('✅ Found ${searchResults.length} results:');
    for (var result in searchResults.take(5)) {
      final entity = result['entity'];
      if (entity != null) {
        print(
          '   - ${entity['name']} (ID: ${entity['id']}, Type: ${result['type']})',
        );
      }
    }
  } else {
    print('❌ No search results found');
  }

  // Step 4: Get seasons for a tournament (example: IPL)
  print('\n📅 Step 4: Fetching seasons for IPL (ID: 234)...');
  final iplSeasons = await apiService.getTournamentSeasons('234');

  if (iplSeasons.isNotEmpty) {
    print('✅ Found ${iplSeasons.length} IPL seasons:');
    for (var season in iplSeasons.take(5)) {
      print(
        '   - ${season['name'] ?? season['year']} (Season ID: ${season['id']})',
      );
    }
  } else {
    print('❌ No seasons found');
  }

  // Step 5: Example code snippets
  print('\n💡 Example Usage:');
  print('=' * 60);
  print('''
// Get Premier League 2025/2026 matches
final events = await apiService.getSeasonTeamEventsAway(
  tournamentId: '17',    // Premier League
  seasonId: '61627',     // 2025/2026 season
);

// Get IPL 2024 matches
final iplMatches = await apiService.getSeasonTeamEventsAway(
  tournamentId: '234',   // IPL
  seasonId: '58766',     // 2024 season
);

// Get live cricket matches
final liveMatches = await apiService.getLiveMatches(3); // 3 = Cricket

// Search for any tournament
final results = await apiService.searchTournaments('World Cup');
''');

  print('\n✅ Discovery complete!');
  print(
    '💡 Use the TournamentDiscoveryScreen in your app for a visual interface',
  );
}
