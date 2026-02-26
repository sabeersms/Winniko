import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url =
      'https://site.api.espn.com/apis/site/v2/sports/soccer/ind.1/scoreboard?limit=100&dates=20240901-20260531';
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);
  final events = data['events'] as List;

  for (var event in events) {
    final competitors = event['competitions'][0]['competitors'] as List;
    for (var comp in competitors) {
      final team = comp['team'];
      if (team['displayName'].toString().toLowerCase().contains('hyderabad')) {
        print('Hyderabad FC:');
        print(' - Name: ${team['displayName']}');
        print(' - ID: ${team['id']}');
        print(' - Logo: ${team['logo']}');
        return;
      }
    }
  }
  print('Hyderabad FC not found in this range.');
}
