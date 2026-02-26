import 'package:flutter/foundation.dart';
import 'package:winniko/services/rapid_api_service.dart';

Future<void> main() async {
  debugPrint('Verifying RapidApiService...');

  // 1. Search Logic
  final service = RapidApiService();
  final query = 'T20'; // Broad query

  debugPrint('Searching for "$query"...');
  final results = await service.searchSeries(query);

  if (results.isEmpty) {
    debugPrint('No series found. Check API Key or Quota.');
    return;
  }

  debugPrint('Found ${results.length} series.');
  for (var s in results.take(3)) {
    debugPrint('- ${s['name']} (ID: ${s['id']})');
  }

  // 2. Fetch Fixtures for first result
  final first = results.first;
  final id = first['id'];
  debugPrint('Fetching fixtures for Series ID: $id...');

  final fixtures = await service.getFixtures(id.toString());
  debugPrint('Found ${fixtures.length} fixtures.');

  if (fixtures.isNotEmpty) {
    final f = fixtures.first;
    debugPrint('First Fixture: ${f['home']['name']} vs ${f['away']['name']}');
    debugPrint('Status: ${f['status']}');

    // 3. Fetch Details if Live/Finished
    if (f['status'] == 'Finished' || f['status'].contains('Result')) {
      debugPrint('Fetching details for match ${f['id']}...');
      final detail = await service.getMatchDetails(f['id'].toString());
      if (detail != null) {
        debugPrint('Detail fetched successfully!');
        debugPrint('Summary: ${detail['live_details']?['match_summary']}');
      }
    }
  }
}
