import 'package:http/http.dart' as http;
import 'dart:convert';

// Mock Services
class TeamsDataService {
  static const Map<String, List<String>> _teamAliases = {
    'United States': ['USA', 'U.S.A.', 'United States of America'],
    'West Indies': ['WI', 'Windies'],
    'United Arab Emirates': ['UAE', 'U.A.E.'],
    'South Korea': ['Korea Republic', 'Republic of Korea'],
    'Papua New Guinea': ['PNG', 'P.N.G.'],
    'Namibia': ['NAM'],
    'Oman': ['OMA'],
    'Scotland': ['SCO'],
    'Netherlands': ['NED'],
    'India': ['IND'],
    'Australia': ['AUS'],
    'England': ['ENG'],
    'South Africa': ['RSA', 'SA', 'S.A.'],
    'New Zealand': ['NZ', 'NZL'],
    'Pakistan': ['PAK'],
    'Sri Lanka': ['SL', 'SRI'],
    'Afghanistan': ['AFG'],
    'Bangladesh': ['BAN', 'BD'],
    'Ireland': ['IRE'],
    'Zimbabwe': ['ZIM'],
    'Nepal': ['NEP'],
    'Canada': ['CAN'],
    'Uganda': ['UGA'],
    'Italy': ['ITA'],
  };

  static bool stringContainsTeamName(String text, String teamName) {
    final t = text.toLowerCase();
    final name = teamName.toLowerCase().trim();

    if (t.contains(name)) return true;

    for (var entry in _teamAliases.entries) {
      final key = entry.key.toLowerCase();
      final values = entry.value.map((e) => e.toLowerCase()).toList();

      if (key == name) {
        for (var v in values) {
          if (t.contains(v)) return true;
        }
      }
      if (values.contains(name)) {
        if (t.contains(key)) return true;
        for (var v in values) {
          if (t.contains(v)) return true;
        }
      }
    }
    return false;
  }
}

void main() async {
  print('🏏 Debugging Score Parsing Logic...');
  const cricApiKey = '5cfd83f3-0d98-4ebc-a50c-2f5d3fe0ada7';

  // 1. Fetch from CricAPI
  final url =
      'https://api.cricapi.com/v1/currentMatches?apikey=$cricApiKey&offset=0';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    print('Failed to fetch: ${response.statusCode}');
    return;
  }

  final data = json.decode(response.body);
  final matches = (data['data'] as List).cast<Map<String, dynamic>>();

  // 2. Simulate Parsing
  print('\nParsing Results (Filtering for England/Nepal):');

  for (var match in matches) {
    final name = (match['name'] as String).toLowerCase();

    // Filter
    if (!name.contains('england') && !name.contains('nepal')) continue;

    final status = match['status'] as String;

    // RAW DUMP first
    print('\nRAW MATCH DATA:');
    print(json.encode(match));

    print('\n--- PARSING ANALYSIS ---');
    print('MATCH: ${match['name']}');
    print('STATUS: $status');

    if (match['score'] == null) {
      print('Score is NULL');
      continue;
    }

    final scores = match['score'] as List;
    for (var s in scores) {
      final inning = s['inning'].toString();
      final r = s['r'];
      final w = s['w'];
      final o = s['o'];
      print('  Inning Raw: "$inning" -> Score: $r/$w ($o ov)');

      // TEST: Identification
      bool idHome = TeamsDataService.stringContainsTeamName(inning, 'England');
      bool idAway = TeamsDataService.stringContainsTeamName(inning, 'Nepal');

      if (idHome) print('     > Matches "England"');
      if (idAway) print('     > Matches "Nepal"');

      if (idHome && idAway) print('     !!! AMBIGUOUS MATCH !!!');
      if (!idHome && !idAway) print('     !!! NO MATCH !!!');
    }
  }
}
