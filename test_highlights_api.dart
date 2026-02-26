import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Use User's New Key (assuming 65a3... works for this API per Step 1292 context)
  // Or maybe OLD key 04a2... works as per curl request? Let's try 04a2 first as per curl.
  const apiKey = '04a2aaf5d7msh17a87f35bae4c66p1bc2dbjsned2c663a1669';
  const host = 'cricket-highlights-api.p.rapidapi.com';

  print('Testing Cricket Highlights API Endpoints ($host)...');

  final endpoints = [
    'https://$host/matches', // Common?
    'https://$host/fixtures', // Maybe?
    'https://$host/series', // Maybe?
    'https://$host/matches/upcoming', // Highlights API often has this structure?
    'https://$host/leagues',
  ];

  for (var url in endpoints) {
    print('Checking: $url');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
      );

      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('SUCCESS!');
        try {
          final json = jsonDecode(response.body);
          if (json is List) {
            print('Returned List of ${json.length} items.');
            if (json.isNotEmpty) print('Sample: ${json[0]}');
          } else if (json is Map) {
            print('Returned Map with keys: ${json.keys.toList()}');
            if (json['data'] != null) {
              print('Data count: ${(json['data'] as List).length}');
            }
          }
        } catch (e) {
          print('Body is not JSON? ${response.body.substring(0, 50)}');
        }
      } else {
        print('Error Body: ${response.body}');
      }
    } catch (e) {
      print('Exception: $e');
    }
    print('---');
  }
}
