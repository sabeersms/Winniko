import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  const apiKey = '04a2aaf5d7msh17a87f35bae4c66p1bc2dbjsned2c663a1669';
  const host = 'cricket-live-data.p.rapidapi.com';

  print('Testing RapidAPI: $host');

  // 1. Search Series
  final url = Uri.parse('https://$host/series');
  try {
    final response = await http.get(
      url,
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );

    if (response.statusCode == 200) {
      print('Search Series Success!');
      final json = jsonDecode(response.body);
      print('Results Count: ${json['results'].length}');
      // Print first result
      if (json['results'].isNotEmpty) {
        print('First Result: ${json['results'][0]}');
      }
    } else {
      print('Search Failed: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
