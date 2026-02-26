import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Nov 7 2024
  final url =
      'https://site.api.espn.com/apis/site/v2/sports/soccer/ind.1/scoreboard?dates=20241107';
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);
  final events = data['events'] as List;

  for (var event in events) {
    print('Event: ${event['name']}');
    final competitors = event['competitions'][0]['competitors'] as List;
    for (var comp in competitors) {
      final team = comp['team'];
      print('Team: ${team['displayName']} (${team['id']}) - ${team['logo']}');
    }
  }
}
