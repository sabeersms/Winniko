import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();

  // List of potential endpoints to test
  final urls = [
    'https://site.api.espn.com/apis/site/v2/sports/cricket/scoreboard',
    'https://site.api.espn.com/apis/site/v2/sports/cricket/leagues/8048/scoreboard', // IPL typically
    'https://site.api.espn.com/apis/site/v2/sports/cricket/leagues/1/scoreboard',
  ];

  for (final url in urls) {
    print('Testing: $url');
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bodyStart = await response.transform(utf8.decoder).join();
        print('SUCCESS: $url');
        // print('Preview: ${bodyStart.substring(0, 500)}'); // Print first 500 chars

        // Parse JSON to see structure
        final json = jsonDecode(bodyStart);
        if (json['events'] != null) {
          print('Events found: ${(json['events'] as List).length}');
          if ((json['events'] as List).isNotEmpty) {
            print('First event: ${json['events'][0]['name']}');
            print(
              'Competitions: ${json['events'][0]['competitions'][0]['competitors']}',
            );
          }
        }
      } else {
        print('FAILED: $url (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('ERROR: $url - $e');
    }
    print('---');
  }
}
