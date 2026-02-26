import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  print('Testing ESPN Cricket Scorepanel with Dates...\n');

  final dates = ['20260214', '20240629']; // YYYYMMDD

  for (var d in dates) {
    print('Checking Date: $d');
    final url =
        'https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel?dates=$d';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['scores'] is List) {
          final scores = json['scores'] as List;
          var found = false;
          for (var s in scores) {
            final leagues = s['leagues'] as List?;
            if (leagues != null) {
              for (var l in leagues) {
                final events = l['events'] as List?;
                if (events != null && events.isNotEmpty) {
                  found = true;
                  print('  League: ${l['name']} (${events.length} matches)');
                  for (var e in events) {
                    final c = e['competitions'][0];
                    final status = e['status']['type']['description'];
                    final home = c['competitors'][0]['team']['displayName'];
                    final away = c['competitors'][1]['team']['displayName'];
                    final scoreLine = c['competitors'][0]['score'] ?? '0';
                    print('    -> $home vs $away ($status) [$scoreLine]');
                  }
                }
              }
            }
          }
          if (!found) print('  No matches found.');
        }
      }
    } catch (e) {
      print('  Error: $e');
    }
    print('');
  }
}
