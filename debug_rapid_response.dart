import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // USE USER PROVIDED KEY
  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  print('Searching Series using USER KEY...');
  final url = Uri.parse('https://$host/series');
  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    if (response.statusCode != 200) {
      print('API Error: ${response.statusCode}');
      return;
    }

    final json = jsonDecode(response.body);
    final results = json['results'] as List;

    int checked = 0;
    for (var r in results) {
      if (r['series'] is List) {
        for (var s in r['series']) {
          checked++;
          final sid = s['series_id'].toString();
          final name = s['series_name'].toString();
          final status = s['status'].toString();

          // Filter for "Result" or "Progress"
          if (status.contains('Result') || status.contains('Progress')) {
            //  print('Checking $name ($sid)...');
            final fUrl = Uri.parse('https://$host/fixtures-by-series/$sid');
            final fResp = await http.get(
              fUrl,
              headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
            );
            final fJson = jsonDecode(fResp.body);

            if (fJson['results'] is List) {
              final fixtures = fJson['results'] as List;
              if (fixtures.isNotEmpty) {
                print('FOUND FIXTURES! Series: $name (ID: $sid)');
                print('Matches: ${fixtures.length}');

                // Find FINISHED Match
                final m = fixtures.firstWhere(
                  (x) =>
                      x['result'].toString().isNotEmpty &&
                      x['status'] == 'Finished',
                  orElse: () => null,
                );

                if (m != null) {
                  print(
                    'Sample Match: ${m['home']['name']} vs ${m['away']['name']}',
                  );
                  print('Result: "${m['result']}"');
                  print('Status: "${m['status']}"');

                  // Fetch Detail
                  print('Fetching Detail for ${m['id']}...');
                  final dUrl = Uri.parse('https://$host/match/${m['id']}');
                  final dResp = await http.get(
                    dUrl,
                    headers: {
                      'x-rapidapi-key': apiKey,
                      'x-rapidapi-host': host,
                    },
                  );
                  final dJson = jsonDecode(dResp.body);
                  if (dJson['results'] != null) {
                    final res = dJson['results'];
                    print('Live Details: ${jsonEncode(res['live_details'])}');
                    if (res['scorecard'] != null) {
                      // print keys only
                      print(
                        'Scorecard Keys: ${res['scorecard'].keys.toList()}',
                      );
                    }
                  }
                  return; // Success
                }
              }
            }
          }
          if (checked > 30) break; // Check more this time
        }
      }
      if (checked > 30) break;
    }
    if (checked > 0) print('Checked $checked series. None had fixtures.');
  } catch (e) {
    print('Ex: $e');
  }
}
