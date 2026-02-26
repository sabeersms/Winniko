import 'package:winniko/services/api_usage_tracker.dart';
import 'package:winniko/services/cric_api_service.dart';
import 'package:winniko/services/rapid_api_service.dart';

/// Quick console script to check API usage
///
/// Usage: dart run test_scripts/check_api_limits.dart
void main() async {
  print('\n🔍 Checking API Usage and Limits...\n');

  final tracker = ApiUsageTracker();
  final cricApi = CricApiService();
  final rapidApi = RapidApiService();

  // Make a test call to each API to get fresh rate limit info
  print('📡 Making test API calls to fetch rate limit headers...\n');

  try {
    print('Testing CricAPI...');
    await cricApi.fetchCurrentMatches();
    print('✅ CricAPI call successful\n');
  } catch (e) {
    print('⚠️ CricAPI call failed: $e\n');
  }

  try {
    print('Testing RapidAPI...');
    await rapidApi.searchSeries('ipl');
    print('✅ RapidAPI call successful\n');
  } catch (e) {
    print('⚠️ RapidAPI call failed: $e\n');
  }

  // Print comprehensive report
  tracker.printUsageReport();

  // Check if approaching limits
  if (tracker.isApproachingLimit(threshold: 0.8)) {
    print('⚠️  WARNING: You are approaching your API limits!');
    print('   Consider reducing the frequency of API calls.\n');
  } else {
    print('✅ API usage is healthy. You have plenty of calls remaining.\n');
  }

  // Individual API checks
  final cricRemaining = tracker.getRemainingCalls('cric');
  final rapidRemaining = tracker.getRemainingCalls('rapid');

  if (cricRemaining != null && cricRemaining < 100) {
    print('⚡ CricAPI: Only $cricRemaining calls remaining!');
  }

  if (rapidRemaining != null && rapidRemaining < 100) {
    print('⚡ RapidAPI: Only $rapidRemaining calls remaining!');
  }

  print('\n✨ Check complete!\n');
}
