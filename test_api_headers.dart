import 'package:http/http.dart' as http;

Future<void> main() async {
  // Use User's Key
  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  print('Checking RapidAPI Rate Limits (Fixtures Endpoint)...');

  // Use endpoint that previously returned 429
  final url = Uri.parse('https://$host/fixtures-by-date/2026-02-08');

  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    print('Status Code: ${response.statusCode}');
    print('--- Response Headers ---');

    // Print ALL headers to be sure
    response.headers.forEach((k, v) {
      // Focus on rate limits
      if (k.toLowerCase().contains('ratelimit') ||
          k.toLowerCase().contains('x-rate') ||
          k.toLowerCase().contains('limit')) {
        print('$k: $v');
      }
    });
    print('------------------------');
  } catch (e) {
    print('Exception: $e');
  }
}
