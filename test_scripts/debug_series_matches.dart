import 'package:http/http.dart' as http;
import 'dart:convert';

const String API_KEY = "5cfd83f3-0d98-4ebc-a50c-2f5d3fe0ada7";
const String BASE_URL = "https://api.cricapi.com/v1";

void main() async {
  print('--- DEBUG SERIES MATCHES ---');

  // 1. Get Series List
  final seriesUrl = Uri.parse('$BASE_URL/series?apikey=$API_KEY&offset=0');
  print('Fetching Series: $seriesUrl');

  String targetSeriesId = '';

  try {
    final resp = await http.get(seriesUrl);
    final data = json.decode(resp.body);
    final seriesList = data['data'] as List<dynamic>;

    print('Found ${seriesList.length} series.');

    // Find relevant series
    for (var s in seriesList) {
      String name = s['name'].toString();
      // Look for "World Cup" or active
      if (name.contains('World Cup') && name.contains('2026')) {
        print('Found Target Series: $name (${s['id']})');
        targetSeriesId = s['id'];
        // Don't break, see all
      }
    }

    if (targetSeriesId.isEmpty && seriesList.isNotEmpty) {
      targetSeriesId = seriesList.first['id']; // Fallback
      print('Fallback to first series: ${seriesList.first['name']}');
    }

    if (targetSeriesId.isNotEmpty) {
      // 2. Fetch Series Info (Matches)
      final infoUrl = Uri.parse(
        '$BASE_URL/series_info?apikey=$API_KEY&id=$targetSeriesId',
      );
      print('\nFetching Info: $infoUrl');

      final infoResp = await http.get(infoUrl);
      final infoData = json.decode(infoResp.body);

      if (infoData['data'] != null && infoData['data']['matchList'] != null) {
        final matches = infoData['data']['matchList'] as List<dynamic>;
        print('Found ${matches.length} matches in series.');

        bool foundEnded = false;
        for (var m in matches) {
          String status = (m['status'] ?? '').toString();
          if (status.contains('Ended') || status.contains('won')) {
            print('\n--- FINISHED MATCH ---');
            print('Name: ${m['name']}');
            print('Status: $status');
            print('Score Field: ${m['score']}'); // Check this field!
            print('Full Object: $m');
            foundEnded = true;
            if (foundEnded) break; // Just need one example
          }
        }

        if (!foundEnded) {
          print('No finished matches found in this series.');
          // Print a random one
          if (matches.isNotEmpty) print('Sample Match: ${matches.first}');
        }
      } else {
        print('No match list in series info.');
        print(infoData);
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
