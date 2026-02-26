import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();

  // Cricinfo hidden API (often used by extensions)
  final urls = [
    'https://hs-consumer-api.espncricinfo.com/v1/pages/matches/current?lang=en&latest=true',
  ];

  for (final url in urls) {
    print('Testing: $url');
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bodyStart = await response.transform(utf8.decoder).join();
        print('SUCCESS: $url');
        print('Preview: ${bodyStart.substring(0, 500)}');
      } else {
        print('FAILED: $url (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('ERROR: $url - $e');
    }
    print('---');
  }
}
