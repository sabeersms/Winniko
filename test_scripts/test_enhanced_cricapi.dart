import 'package:winniko/services/cric_api_service.dart';

/// Test script for enhanced CricAPI service
///
/// Tests error handling, caching, retry logic, and monitoring features
void main() async {
  print('🏏 Testing Enhanced CricAPI Service');
  print('=' * 70);

  final apiService = CricApiService();

  // Test 1: Normal fetch
  print('\n📍 Test 1: Normal Fetch');
  print('-' * 70);
  try {
    final matches = await apiService.fetchCurrentMatches();
    print('✅ Success! Fetched ${matches.length} matches');

    if (matches.isNotEmpty) {
      print('\nSample matches:');
      for (var i = 0; i < matches.length && i < 3; i++) {
        final match = matches[i];
        print('   ${i + 1}. ${match['name']}');
        print('      - ID: ${match['id']}');
        print('      - Status: ${match['status']}');
        print('      - Match Type: ${match['matchType']}');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 2: Cache stats
  print('\n📍 Test 2: Cache Statistics');
  print('-' * 70);
  final stats = apiService.getCacheStats();
  print('Cache Stats:');
  stats.forEach((key, value) {
    print('   $key: $value');
  });

  // Test 3: Health status
  print('\n📍 Test 3: Health Status');
  print('-' * 70);
  final health = apiService.getHealthStatus();
  print('Health Status: $health');

  String healthEmoji;
  switch (health) {
    case CricApiHealthStatus.healthy:
      healthEmoji = '✅';
      break;
    case CricApiHealthStatus.degraded:
      healthEmoji = '⚠️';
      break;
    case CricApiHealthStatus.critical:
      healthEmoji = '❌';
      break;
    case CricApiHealthStatus.unknown:
      healthEmoji = '❓';
      break;
  }
  print('Status: $healthEmoji $health');

  // Test 4: Cache hit (should use cached data)
  print('\n📍 Test 4: Cache Hit Test');
  print('-' * 70);
  print('Fetching again immediately (should use cache)...');
  final startTime = DateTime.now();
  try {
    final matches = await apiService.fetchCurrentMatches();
    final duration = DateTime.now().difference(startTime);
    print(
      '✅ Fetched ${matches.length} matches in ${duration.inMilliseconds}ms',
    );

    if (duration.inMilliseconds < 100) {
      print('🎯 Cache hit! (Very fast response)');
    } else {
      print('⚠️  Possible API call (Slower response)');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 5: Score extraction
  print('\n📍 Test 5: Score Extraction');
  print('-' * 70);
  try {
    final matches = await apiService.fetchCurrentMatches();

    if (matches.isNotEmpty) {
      print('Testing score extraction on first match...');
      final firstMatch = matches[0];
      final score = apiService.extractScore(firstMatch);

      if (score != null) {
        print('✅ Score extracted successfully:');
        print('   Status: ${score['status']}');
        print('   Match Type: ${score['matchType']}');
        print('   Scores: ${score['scores']?.length ?? 0} innings');

        if (score['scores'] != null) {
          for (var i = 0; i < (score['scores'] as List).length; i++) {
            final inning = score['scores'][i];
            print(
              '   Inning ${i + 1}: ${inning['r']}/${inning['w']} in ${inning['o']} overs',
            );
          }
        }
      } else {
        print('⚠️  No score data available for this match');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 6: Force refresh
  print('\n📍 Test 6: Force Refresh');
  print('-' * 70);
  print('Forcing refresh (bypassing cache)...');
  try {
    final matches = await apiService.fetchCurrentMatches(forceRefresh: true);
    print('✅ Force refresh successful! Fetched ${matches.length} matches');
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 7: Final stats
  print('\n📍 Test 7: Final Statistics');
  print('-' * 70);
  final finalStats = apiService.getCacheStats();
  print('Final Cache Stats:');
  print('   Cached Matches: ${finalStats['cachedMatchCount']}');
  print('   Cache Age: ${finalStats['cacheAge']}');
  print('   Cache Valid: ${finalStats['isCacheValid']}');
  print('   Consecutive Errors: ${finalStats['consecutiveErrors']}');
  print('   Last Error: ${finalStats['lastError'] ?? 'None'}');

  print('\n${'=' * 70}');
  print('✅ All tests complete!');
  print('=' * 70);

  print('\n💡 Integration Tips:');
  print('   1. Use fetchCurrentMatches() in your sync service');
  print('   2. Cache automatically handles rate limiting');
  print('   3. Errors are logged with detailed information');
  print('   4. Stale cache is used as fallback on errors');
  print('   5. Add CricApiHealthMonitor widget to your settings/debug screen');
}
