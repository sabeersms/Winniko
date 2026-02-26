import 'package:http/http.dart' as http;

Future<void> main() async {
  const host = 'cricket-highlights-api.p.rapidapi.com';

  final keys = [
    '04a2aaf5d7msh17a87f35bae4c66p1bc2dbjsned2c663a1669', // Old Key (from curl)
    '65a3eeb3-fbd6-43c1-a228-ae2ead858862', // New Key
  ];

  for (var k in keys) {
    print('Testing Key: ${k.substring(0, 5)}...');
    try {
      final response = await http.get(
        Uri.parse('https://$host/leagues?limit=1'),
        headers: {'x-rapidapi-key': k, 'x-rapidapi-host': host},
      );
      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('SUCCESS!');
      } else {
        print('FAILED');
      }
    } catch (e) {
      print('Error: $e');
    }
    print('---');
  }
}
