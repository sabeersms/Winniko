import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  const apiKey = '04a2aaf5d7msh17a87f35bae4c66p1bc2dbjsned2c663a1669';
  const host = 'cricket-highlights-api.p.rapidapi.com';

  print('Step 1: Get League ID...');
  String? leagueId;

  try {
    final lResp = await http.get(
      Uri.parse('https://$host/leagues'),
      headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
    );
    if (lResp.statusCode == 200) {
      final json = jsonDecode(lResp.body);
      final list = json['data'] as List;
      if (list.isNotEmpty) {
        final first = list[0];
        print('League Found: ${first['name']} (ID: ${first['id']})');
        leagueId = first['id'].toString();

        // Try to find T20 league
        for (var l in list) {
          if (l['name'].toString().contains('T20')) {
            print('  Found T20 League: ${l['name']} (ID: ${l['id']})');
            leagueId = l['id'].toString();
            break;
          }
        }
      }
    }
  } catch (e) {
    print('League fetch error: $e');
  }

  if (leagueId != null) {
    print('\nStep 2: Get Matches for League $leagueId...');
    final mUrl = Uri.parse('https://$host/matches?leagueId=$leagueId');

    try {
      final mResp = await http.get(
        mUrl,
        headers: {'x-rapidapi-key': apiKey, 'x-rapidapi-host': host},
      );
      print('Matches Status: ${mResp.statusCode}');
      if (mResp.statusCode == 200) {
        final mJson = jsonDecode(mResp.body);
        final mList = mJson['data'] as List;
        print('Matches Found: ${mList.length}');
        if (mList.isNotEmpty) {
          final m = mList[0];
          print('Sample Match: ${m['name']}');
          print('Status: ${m['status']}');
          print('Scores: ${m['score']}'); // Guessing key
          print('Full Data: $m');
        }
      } else {
        print('Error Header: ${mResp.body}');
      }
    } catch (e) {
      print('Matches fetch error: $e');
    }
  }
}
