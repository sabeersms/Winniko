import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Use User's Key
  const apiKey = '3df386fb-a73f-44a5-a174-ed6801ad6d33';
  const host = 'cricket-live-data.p.rapidapi.com';

  print('Testing RapidAPI Key Status...');

  // Simple endpoint (Series List)
  final url = Uri.parse('https://$host/series');

  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('SUCCESS: API is working!');
      final json = jsonDecode(response.body);
      final results = json['results'] as List;
      print('Data returned: ${results.length} series found.');
    } else if (response.statusCode == 429) {
      print('FAILURE: 429 Too Many Requests (Rate Limited).');
      print('You have exceeded your API quota.');
    } else {
      print('FAILURE: Error ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
