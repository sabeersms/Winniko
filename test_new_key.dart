import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Use New User Key
  const apiKey = '65a3eeb3-fbd6-43c1-a228-ae2ead858862';
  const host = 'cricket-live-data.p.rapidapi.com';

  print('Testing New RapidAPI Key Status ($apiKey)...');

  // Simple endpoint (Series List)
  final url = Uri.parse('https://$host/series');

  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('SUCCESS: Key is working!');
      final json = jsonDecode(response.body);
      final results = json['results'] as List;
      print('Data returned: ${results.length} series found.');

      // Try fixtures-by-date for Feb 8 (previously limited)
      // To ensure endpoint is accessible
      final fUrl = Uri.parse('https://$host/fixtures-by-date/2026-02-08');
      print('Testing fixtures-by-date/2026-02-08 (previously 429)...');
      final fResp = await http.get(
        fUrl,
        headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
      );
      print('Fixtures Status: ${fResp.statusCode}');
      if (fResp.statusCode == 200) {
        print('Fixtures Endpoint also works!');
      } else {
        print('Fixtures Endpoint Failed: ${fResp.statusCode}');
      }
    } else if (response.statusCode == 403) {
      print('FAILURE: 403 Forbidden (Unsubscribed or Invalid Key).');
    } else {
      print('FAILURE: Error ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
