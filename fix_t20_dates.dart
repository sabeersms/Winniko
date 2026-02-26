import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';

/// Script to fix incorrect match dates/times in T20 World Cup 2026 competition
///
/// This script will:
/// 1. Find your T20 World Cup competition
/// 2. Fetch correct match dates from RapidAPI
/// 3. Compare and update any mismatched dates
/// 4. Preserve manually scored matches (won't update their dates)

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;

  print('🔍 Searching for T20 World Cup 2026 competitions...\n');

  // Find all competitions with T20 World Cup
  final competitionsSnapshot = await firestore
      .collection('competitions')
      .where('sport', isEqualTo: 'Cricket')
      .get();

  List<Map<String, dynamic>> t20Competitions = [];

  for (var doc in competitionsSnapshot.docs) {
    final data = doc.data();
    final name = data['name']?.toString() ?? '';

    if (name.toLowerCase().contains('t20') &&
        name.toLowerCase().contains('world cup')) {
      t20Competitions.add({
        'id': doc.id,
        'name': name,
        'leagueId': data['leagueId'],
        'organizerId': data['organizerId'],
      });
      print('✅ Found: $name (ID: ${doc.id})');
    }
  }

  if (t20Competitions.isEmpty) {
    print('❌ No T20 World Cup competitions found!');
    return;
  }

  print('\n📋 Found ${t20Competitions.length} T20 World Cup competition(s)\n');

  // Process each competition
  for (var comp in t20Competitions) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Processing: ${comp['name']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    await fixCompetitionDates(firestore, comp);
  }

  print('\n✅ All done!');
}

Future<void> fixCompetitionDates(
  FirebaseFirestore firestore,
  Map<String, dynamic> competition,
) async {
  final competitionId = competition['id'];
  final leagueId = competition['leagueId'];

  // Fetch matches from competition
  final matchesSnapshot = await firestore
      .collection('competitions')
      .doc(competitionId)
      .collection('matches')
      .get();

  print('📊 Found ${matchesSnapshot.docs.length} matches in competition\n');

  if (leagueId == null || leagueId.isEmpty) {
    print('⚠️  No leagueId found - this is a custom tournament');
    print('   Manual date editing required through the app\n');
    return;
  }

  // Fetch correct dates from official_leagues
  print('🌍 Fetching correct dates from official_leagues...');
  final officialMatchesSnapshot = await firestore
      .collection('official_leagues')
      .doc(leagueId)
      .collection('matches')
      .get();

  if (officialMatchesSnapshot.docs.isEmpty) {
    print('⚠️  No official matches found for leagueId: $leagueId');
    print('   Trying to fetch from RapidAPI...\n');
    await fetchAndUpdateFromAPI(firestore, competitionId, matchesSnapshot.docs);
    return;
  }

  print('✅ Found ${officialMatchesSnapshot.docs.length} official matches\n');

  // Create a map of official matches by team names
  Map<String, Map<String, dynamic>> officialMatchMap = {};
  for (var doc in officialMatchesSnapshot.docs) {
    final data = doc.data();
    final home = data['homeTeamName']?.toString() ?? '';
    final away = data['awayTeamName']?.toString() ?? '';
    final key = _createMatchKey(home, away);
    officialMatchMap[key] = {
      'scheduledTime': data['scheduledTime'],
      'id': doc.id,
      ...data,
    };
  }

  // Compare and update
  int updatedCount = 0;
  int skippedCount = 0;
  int notFoundCount = 0;

  for (var matchDoc in matchesSnapshot.docs) {
    final matchData = matchDoc.data();
    final team1 = matchData['team1Name']?.toString() ?? '';
    final team2 = matchData['team2Name']?.toString() ?? '';
    final currentTime = matchData['scheduledTime'] as Timestamp?;
    final isManuallyScored =
        matchData['actualScore']?['manuallyScored'] == true;
    final isVerified = matchData['actualScore']?['verified'] == true;

    // Skip verified matches
    if (isVerified) {
      print('🔒 SKIPPED (Verified): $team1 vs $team2');
      skippedCount++;
      continue;
    }

    // Find matching official match
    final key1 = _createMatchKey(team1, team2);
    final key2 = _createMatchKey(team2, team1); // Try reversed

    final officialMatch = officialMatchMap[key1] ?? officialMatchMap[key2];

    if (officialMatch == null) {
      print('❓ NOT FOUND in official data: $team1 vs $team2');
      notFoundCount++;
      continue;
    }

    final correctTime = officialMatch['scheduledTime'] as Timestamp;

    // Check if times are different
    if (currentTime == null ||
        currentTime.toDate().difference(correctTime.toDate()).abs().inMinutes >
            5) {
      final currentStr = currentTime?.toDate().toString() ?? 'NULL';
      final correctStr = correctTime.toDate().toString();

      print('🔄 UPDATING: $team1 vs $team2');
      print('   Old: $currentStr');
      print('   New: $correctStr');

      // Update the match
      await firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchDoc.id)
          .update({'scheduledTime': correctTime});

      updatedCount++;
      print('   ✅ Updated!\n');
    } else {
      print('✓ OK: $team1 vs $team2 (${correctTime.toDate()})');
    }
  }

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 Summary:');
  print('   ✅ Updated: $updatedCount matches');
  print(
    '   ✓  Already correct: ${matchesSnapshot.docs.length - updatedCount - skippedCount - notFoundCount} matches',
  );
  print('   🔒 Skipped (verified): $skippedCount matches');
  print('   ❓ Not found in official data: $notFoundCount matches');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

Future<void> fetchAndUpdateFromAPI(
  FirebaseFirestore firestore,
  String competitionId,
  List<QueryDocumentSnapshot> matches,
) async {
  print('🌐 Fetching from RapidAPI...\n');

  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  // Search for T20 World Cup 2026
  final seriesUrl = Uri.parse('https://$host/series');

  try {
    final seriesResponse = await http.get(
      seriesUrl,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    if (seriesResponse.statusCode != 200) {
      print('❌ API Error: ${seriesResponse.statusCode}');
      return;
    }

    final seriesJson = jsonDecode(seriesResponse.body);
    final results = seriesJson['results'] as List;

    String? seriesId;

    // Find T20 World Cup 2026
    for (var r in results) {
      if (r['series'] is List) {
        for (var s in r['series']) {
          final name = s['series_name'].toString();
          if (name.contains('T20') &&
              name.contains('World Cup') &&
              name.contains('2026')) {
            seriesId = s['series_id'].toString();
            print('✅ Found series: $name (ID: $seriesId)\n');
            break;
          }
        }
      }
      if (seriesId != null) break;
    }

    if (seriesId == null) {
      print('❌ Could not find T20 World Cup 2026 series in API');
      return;
    }

    // Fetch fixtures
    final fixturesUrl = Uri.parse('https://$host/fixtures-by-series/$seriesId');
    final fixturesResponse = await http.get(
      fixturesUrl,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    if (fixturesResponse.statusCode != 200) {
      print('❌ Fixtures API Error: ${fixturesResponse.statusCode}');
      return;
    }

    final fixturesJson = jsonDecode(fixturesResponse.body);
    final fixtures = fixturesJson['results'] as List;

    print('✅ Found ${fixtures.length} fixtures from API\n');

    // Create map of API fixtures
    Map<String, DateTime> apiFixtureMap = {};
    for (var fixture in fixtures) {
      final home = fixture['home']['name']?.toString() ?? '';
      final away = fixture['away']['name']?.toString() ?? '';
      final dateStr = fixture['date']?.toString() ?? '';

      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          final key = _createMatchKey(home, away);
          apiFixtureMap[key] = date;
        } catch (e) {
          print('⚠️  Could not parse date: $dateStr');
        }
      }
    }

    // Update matches
    int updatedCount = 0;

    for (var matchDoc in matches) {
      final matchData = matchDoc.data() as Map<String, dynamic>;
      final team1 = matchData['team1Name']?.toString() ?? '';
      final team2 = matchData['team2Name']?.toString() ?? '';
      final currentTime = matchData['scheduledTime'] as Timestamp?;
      final isVerified = matchData['actualScore']?['verified'] == true;

      if (isVerified) {
        print('🔒 SKIPPED (Verified): $team1 vs $team2');
        continue;
      }

      final key1 = _createMatchKey(team1, team2);
      final key2 = _createMatchKey(team2, team1);

      final correctDate = apiFixtureMap[key1] ?? apiFixtureMap[key2];

      if (correctDate != null) {
        final currentStr = currentTime?.toDate().toString() ?? 'NULL';
        final correctStr = correctDate.toString();

        if (currentTime == null ||
            currentTime.toDate().difference(correctDate).abs().inMinutes > 5) {
          print('🔄 UPDATING: $team1 vs $team2');
          print('   Old: $currentStr');
          print('   New: $correctStr');

          await firestore
              .collection('competitions')
              .doc(competitionId)
              .collection('matches')
              .doc(matchDoc.id)
              .update({'scheduledTime': Timestamp.fromDate(correctDate)});

          updatedCount++;
          print('   ✅ Updated!\n');
        }
      }
    }

    print('\n✅ Updated $updatedCount matches from API\n');
  } catch (e) {
    print('❌ Error fetching from API: $e');
  }
}

String _createMatchKey(String team1, String team2) {
  return '${team1.toLowerCase().trim()}_vs_${team2.toLowerCase().trim()}';
}
