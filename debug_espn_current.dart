import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Just get current scoreboard
  final url =
      'https://site.api.espn.com/apis/site/v2/sports/soccer/ind.1/scoreboard';
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);
  if (data['events'] == null) {
    print('No events right now in ind.1');
    return;
  }
  final events = data['events'] as List;

  for (var event in events) {
    final competitors = event['competitions'][0]['competitors'] as List;
    for (var comp in competitors) {
      final team = comp['team'];
      print('Team: ${team['displayName']} (${team['id']}) - ${team['logo']}');
    }
  }
}
