import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Use User's Key
  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  final query = "Men's T20 World Cup 2026";
  print('Searching for: "$query"');

  final url = Uri.parse('https://$host/series');
  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final results = json['results'] as List;

      print('Total Results: ${results.length}');

      for (var r in results) {
        if (r['series'] is List) {
          for (var s in r['series']) {
            final name = s['series_name'].toString();
            final sid = s['series_id'].toString();

            // Fuzzy check like the App does?
            // App uses "contains" on query terms?
            // Let's just print matches for "World Cup" or "T20"
            if (name.contains('World Cup') || name.contains('T20')) {
              print('  Found: $name (ID: $sid) - Status: ${s['status']}');

              // If name looks like 2026, fetch fixtures
              if (name.contains('2026')) {
                print('    -> Fetching Fixtures for ID $sid...');
                final fUrl = Uri.parse('https://$host/fixtures-by-series/$sid');
                final fResp = await http.get(
                  fUrl,
                  headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
                );
                final fJson = jsonDecode(fResp.body);
                final fixtures = fJson['results'] as List;
                print('    -> Fixtures Found: ${fixtures.length}');
                if (fixtures.isNotEmpty) {
                  print(
                    '       Sample: ${fixtures[0]['home']['name']} vs ${fixtures[0]['away']['name']}',
                  );
                  print('       Date: ${fixtures[0]['date']}');
                }
              }
            }
          }
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
