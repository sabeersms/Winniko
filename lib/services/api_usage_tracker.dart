import 'package:flutter/foundation.dart';

/// Tracks API usage and rate limits across different API services
///
/// This service helps monitor:
/// - Total API calls made
/// - Rate limit headers from APIs
/// - Daily/Monthly usage tracking
/// - Alert when approaching limits
class ApiUsageTracker {
  static final ApiUsageTracker _instance = ApiUsageTracker._internal();
  factory ApiUsageTracker() => _instance;
  ApiUsageTracker._internal();

  // CricAPI tracking
  int _cricApiCallsToday = 0;
  int? _cricApiDailyLimit;
  int? _cricApiRemaining;
  DateTime? _cricApiResetTime;
  DateTime _lastCricApiReset = DateTime.now();

  // RapidAPI tracking
  int _rapidApiCallsToday = 0;
  int? _rapidApiDailyLimit;
  int? _rapidApiRemaining;
  DateTime? _rapidApiResetTime;
  DateTime _lastRapidApiReset = DateTime.now();

  /// Record a CricAPI call and extract rate limit info from headers
  void recordCricApiCall(Map<String, String>? headers) {
    _resetDailyCountersIfNeeded();
    _cricApiCallsToday++;

    if (headers != null) {
      // Common rate limit headers
      _cricApiRemaining = int.tryParse(headers['x-ratelimit-remaining'] ?? '');
      _cricApiDailyLimit = int.tryParse(headers['x-ratelimit-limit'] ?? '');

      // Parse reset time if available
      final resetHeader = headers['x-ratelimit-reset'];
      if (resetHeader != null) {
        final resetTimestamp = int.tryParse(resetHeader);
        if (resetTimestamp != null) {
          _cricApiResetTime = DateTime.fromMillisecondsSinceEpoch(
            resetTimestamp * 1000,
          );
        }
      }
    }

    _logUsage('CricAPI');
  }

  /// Record a RapidAPI call and extract rate limit info from headers
  void recordRapidApiCall(Map<String, String>? headers) {
    _resetDailyCountersIfNeeded();
    _rapidApiCallsToday++;

    if (headers != null) {
      // RapidAPI uses different header names
      _rapidApiRemaining = int.tryParse(
        headers['x-ratelimit-requests-remaining'] ??
            headers['x-ratelimit-remaining'] ??
            '',
      );
      _rapidApiDailyLimit = int.tryParse(
        headers['x-ratelimit-requests-limit'] ??
            headers['x-ratelimit-limit'] ??
            '',
      );
    }

    _logUsage('RapidAPI');
  }

  /// Reset daily counters if it's a new day
  void _resetDailyCountersIfNeeded() {
    final now = DateTime.now();

    // Reset CricAPI counter
    if (now.day != _lastCricApiReset.day ||
        now.month != _lastCricApiReset.month ||
        now.year != _lastCricApiReset.year) {
      _cricApiCallsToday = 0;
      _lastCricApiReset = now;
      debugPrint('🔄 CricAPI daily counter reset');
    }

    // Reset RapidAPI counter
    if (now.day != _lastRapidApiReset.day ||
        now.month != _lastRapidApiReset.month ||
        now.year != _lastRapidApiReset.year) {
      _rapidApiCallsToday = 0;
      _lastRapidApiReset = now;
      debugPrint('🔄 RapidAPI daily counter reset');
    }
  }

  /// Log current usage with warnings if approaching limits
  void _logUsage(String apiName) {
    final isRapidApi = apiName == 'RapidAPI';
    final callsToday = isRapidApi ? _rapidApiCallsToday : _cricApiCallsToday;
    final remaining = isRapidApi ? _rapidApiRemaining : _cricApiRemaining;
    final limit = isRapidApi ? _rapidApiDailyLimit : _cricApiDailyLimit;

    debugPrint('📊 $apiName Usage: $callsToday calls today');

    if (remaining != null && limit != null) {
      final usedPercent = ((limit - remaining) / limit * 100).toStringAsFixed(
        1,
      );
      debugPrint('   Remaining: $remaining / $limit ($usedPercent% used)');

      // Warning if approaching limit
      if (remaining < limit * 0.1) {
        debugPrint(
          '⚠️ WARNING: Only $remaining API calls remaining for $apiName!',
        );
      } else if (remaining < limit * 0.25) {
        debugPrint('⚡ ALERT: $apiName usage at $usedPercent%');
      }
    }
  }

  /// Get comprehensive usage report
  Map<String, dynamic> getUsageReport() {
    _resetDailyCountersIfNeeded();

    return {
      'cricApi': {
        'callsToday': _cricApiCallsToday,
        'remaining': _cricApiRemaining,
        'limit': _cricApiDailyLimit,
        'resetTime': _cricApiResetTime?.toIso8601String(),
        'percentUsed': _cricApiDailyLimit != null && _cricApiRemaining != null
            ? (((_cricApiDailyLimit! - _cricApiRemaining!) /
                          _cricApiDailyLimit!) *
                      100)
                  .toStringAsFixed(1)
            : 'Unknown',
      },
      'rapidApi': {
        'callsToday': _rapidApiCallsToday,
        'remaining': _rapidApiRemaining,
        'limit': _rapidApiDailyLimit,
        'resetTime': _rapidApiResetTime?.toIso8601String(),
        'percentUsed': _rapidApiDailyLimit != null && _rapidApiRemaining != null
            ? (((_rapidApiDailyLimit! - _rapidApiRemaining!) /
                          _rapidApiDailyLimit!) *
                      100)
                  .toStringAsFixed(1)
            : 'Unknown',
      },
    };
  }

  /// Print detailed usage report to console
  void printUsageReport() {
    final report = getUsageReport();

    debugPrint('\n' + '=' * 60);
    debugPrint('📊 API USAGE REPORT');
    debugPrint('=' * 60);

    // CricAPI
    final cricApi = report['cricApi'] as Map<String, dynamic>;
    debugPrint('\n🏏 CricAPI:');
    debugPrint('   Calls Today: ${cricApi['callsToday']}');
    if (cricApi['limit'] != null) {
      debugPrint('   Limit: ${cricApi['limit']}');
      debugPrint('   Remaining: ${cricApi['remaining']}');
      debugPrint('   Usage: ${cricApi['percentUsed']}%');
      if (cricApi['resetTime'] != null) {
        debugPrint('   Resets: ${cricApi['resetTime']}');
      }
    } else {
      debugPrint('   ⚠️ No rate limit info available yet');
    }

    // RapidAPI
    final rapidApi = report['rapidApi'] as Map<String, dynamic>;
    debugPrint('\n⚡ RapidAPI:');
    debugPrint('   Calls Today: ${rapidApi['callsToday']}');
    if (rapidApi['limit'] != null) {
      debugPrint('   Limit: ${rapidApi['limit']}');
      debugPrint('   Remaining: ${rapidApi['remaining']}');
      debugPrint('   Usage: ${rapidApi['percentUsed']}%');
      if (rapidApi['resetTime'] != null) {
        debugPrint('   Resets: ${rapidApi['resetTime']}');
      }
    } else {
      debugPrint('   ⚠️ No rate limit info available yet');
    }

    debugPrint('\n' + '=' * 60 + '\n');
  }

  /// Check if we're approaching any API limits
  bool isApproachingLimit({double threshold = 0.8}) {
    if (_cricApiDailyLimit != null && _cricApiRemaining != null) {
      final cricUsage =
          (_cricApiDailyLimit! - _cricApiRemaining!) / _cricApiDailyLimit!;
      if (cricUsage >= threshold) return true;
    }

    if (_rapidApiDailyLimit != null && _rapidApiRemaining != null) {
      final rapidUsage =
          (_rapidApiDailyLimit! - _rapidApiRemaining!) / _rapidApiDailyLimit!;
      if (rapidUsage >= threshold) return true;
    }

    return false;
  }

  /// Get remaining calls for a specific API
  int? getRemainingCalls(String apiName) {
    if (apiName.toLowerCase().contains('cric')) {
      return _cricApiRemaining;
    } else if (apiName.toLowerCase().contains('rapid')) {
      return _rapidApiRemaining;
    }
    return null;
  }
}
