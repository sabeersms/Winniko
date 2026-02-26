import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Use User's Key
  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  final dates = ['2026-02-07', '2026-02-08', '2026-02-09'];

  print('Debugging Matches for Feb 7-9 (2026)...');

  for (var date in dates) {
    print('Checking Date: $date');
    final url = Uri.parse('https://$host/fixtures-by-date/$date');

    try {
      final response = await http.get(
        url,
        headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['results'] is List) {
          final list = json['results'] as List;
          print('  Found ${list.length} matches.');

          for (var m in list) {
            final home = m['home']['name'];
            final away = m['away']['name'];
            final status = m['status'];
            final result = m['result'];
            final id = m['id'];

            print('    -> $home vs $away (ID: $id)');
            print('       Status: "$status"');
            print('       Result: "$result"');

            // If status suggests finished but result empty?
            if (status == 'Finished' &&
                (result == null || result.toString().isEmpty)) {
              print('       ⚠️ SUSPICIOUS: Finished but no result string!');
            }
          }
        }
      } else {
        print('  Error ${response.statusCode}');
      }
    } catch (e) {
      print('  Ex: $e');
    }
    print('');
  }
}
