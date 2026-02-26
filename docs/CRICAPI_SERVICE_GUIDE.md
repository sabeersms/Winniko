# Enhanced CricAPI Service Documentation

## 🎯 Overview

The enhanced CricAPI service provides production-grade cricket match data fetching with robust error handling, intelligent caching, and comprehensive monitoring.

## ✨ Features

### 1. **Smart Caching**
- ✅ **2-minute fresh cache**: Returns cached data if less than 2 minutes old
- ✅ **30-minute fallback cache**: Uses stale cache on API errors (up to 30 minutes old)
- ✅ **Automatic cache management**: No manual intervention needed
- ✅ **Cache statistics**: Monitor cache performance

### 2. **Error Handling**
- ✅ **Automatic retry**: Up to 3 attempts with exponential backoff
- ✅ **Timeout protection**: 10-second request timeout
- ✅ **Graceful degradation**: Falls back to cached data on errors
- ✅ **Detailed error types**: Network, timeout, auth, rate limit, etc.
- ✅ **Error tracking**: Monitors consecutive errors

### 3. **Rate Limiting**
- ✅ **Minimum 1-second delay**: Between API requests
- ✅ **Automatic throttling**: Prevents hitting API limits
- ✅ **Smart request spacing**: Protects your API quota

### 4. **Monitoring**
- ✅ **Health status**: Healthy, Degraded, Critical, Unknown
- ✅ **Cache statistics**: Age, validity, match count
- ✅ **Error reporting**: Last error, consecutive failures
- ✅ **Visual health monitor**: Widget for debugging

### 5. **Data Validation**
- ✅ **Match validation**: Ensures required fields exist
- ✅ **Score validation**: Validates score data structure
- ✅ **Safe parsing**: Handles malformed data gracefully

## 📖 Usage

### Basic Usage

```dart
import 'package:winniko/services/cric_api_service.dart';

final apiService = CricApiService();

// Fetch current matches (uses cache if available)
final matches = await apiService.fetchCurrentMatches();

// Process matches
for (var match in matches) {
  print('${match['name']} - ${match['status']}');
}
```

### Force Refresh

```dart
// Bypass cache and fetch fresh data
final matches = await apiService.fetchCurrentMatches(forceRefresh: true);
```

### Extract Score Data

```dart
final matches = await apiService.fetchCurrentMatches();

for (var match in matches) {
  final score = apiService.extractScore(match);
  
  if (score != null) {
    print('Status: ${score['status']}');
    print('Match Type: ${score['matchType']}');
    
    // Access innings data
    for (var inning in score['scores']) {
      print('${inning['r']}/${inning['w']} in ${inning['o']} overs');
    }
  }
}
```

### Monitor Health

```dart
// Get health status
final health = apiService.getHealthStatus();

switch (health) {
  case CricApiHealthStatus.healthy:
    print('✅ Service is healthy');
    break;
  case CricApiHealthStatus.degraded:
    print('⚠️ Service is degraded');
    break;
  case CricApiHealthStatus.critical:
    print('❌ Service is critical');
    break;
  case CricApiHealthStatus.unknown:
    print('❓ Service status unknown');
    break;
}
```

### Get Cache Statistics

```dart
final stats = apiService.getCacheStats();

print('Cached Matches: ${stats['cachedMatchCount']}');
print('Cache Age: ${stats['cacheAge']}');
print('Cache Valid: ${stats['isCacheValid']}');
print('Consecutive Errors: ${stats['consecutiveErrors']}');
print('Last Error: ${stats['lastError']}');
```

### Clear Cache

```dart
// Manually clear cache (useful for testing)
apiService.clearCache();
```

## 🎨 Health Monitor Widget

Add the health monitor widget to your settings or debug screen:

```dart
import 'package:winniko/widgets/cric_api_health_monitor.dart';

// In your widget tree
CricApiHealthMonitor()
```

**Features:**
- Real-time health status badge
- Cache statistics display
- Test connection button
- Clear cache button
- Error information display

## 🔧 Integration with Tournament Sync

### Update your tournament_data_service.dart:

```dart
import 'package:winniko/services/cric_api_service.dart';

class TournamentDataService {
  static final CricApiService _cricApiService = CricApiService();
  
  static Future<List<MatchModel>> _fetchAndParseFixtures(
    String competitionId,
    String leagueId,
    Map<String, TeamModel> teamMap,
  ) async {
    // ... existing code ...
    
    // Fetch live scores from CricAPI
    List<Map<String, dynamic>> cricMatches = [];
    if (leagueId.contains('t20') ||
        leagueId.contains('cricket') ||
        leagueId.contains('world-cup')) {
      try {
        // Enhanced service with automatic caching and error handling
        cricMatches = await _cricApiService.fetchCurrentMatches();
        
        // Check service health
        final health = _cricApiService.getHealthStatus();
        if (health == CricApiHealthStatus.critical) {
          debugPrint('⚠️ CricAPI service is critical, using cached data');
        }
      } catch (e) {
        debugPrint('CricAPI Fetch Error: $e');
        // Service automatically falls back to cache
      }
    }
    
    // ... rest of your code ...
  }
}
```

## 📊 Error Types

The service categorizes errors for better handling:

| Error Type | Description | Action |
|------------|-------------|--------|
| `networkError` | Network connectivity issues | Retry automatically |
| `timeout` | Request took too long | Retry with backoff |
| `authentication` | Invalid API key | Check credentials |
| `rateLimited` | Too many requests | Use cache, wait |
| `serverError` | CricAPI server issues | Retry, use cache |
| `httpError` | Other HTTP errors | Log and retry |
| `parseError` | Invalid JSON response | Log error |
| `apiError` | API returned failure | Check API status |
| `maxRetriesExceeded` | All retries failed | Use cached data |

## ⚙️ Configuration

### Cache Durations

```dart
// In cric_api_service.dart
static const Duration _cacheValidDuration = Duration(minutes: 2);  // Fresh cache
static const Duration _cacheFallbackDuration = Duration(minutes: 30);  // Stale cache
```

### Retry Configuration

```dart
static const int _maxRetries = 3;  // Number of retry attempts
static const Duration _retryDelay = Duration(seconds: 2);  // Initial delay
// Exponential backoff: 2s, 4s, 8s
```

### Rate Limiting

```dart
static const Duration _minTimeBetweenRequests = Duration(seconds: 1);
```

### Request Timeout

```dart
final response = await http.get(Uri.parse(url)).timeout(
  const Duration(seconds: 10),  // 10-second timeout
);
```

## 🧪 Testing

Run the test script to verify everything works:

```bash
dart test_scripts/test_enhanced_cricapi.dart
```

**Tests include:**
1. Normal fetch
2. Cache statistics
3. Health status
4. Cache hit verification
5. Score extraction
6. Force refresh
7. Final statistics

## 📈 Performance Benefits

### Before Enhancement:
- ❌ No caching (every call hits API)
- ❌ No retry on failures
- ❌ No error categorization
- ❌ No health monitoring
- ❌ Basic error handling

### After Enhancement:
- ✅ Smart caching (reduces API calls by ~80%)
- ✅ Automatic retry (improves reliability)
- ✅ Detailed error types (better debugging)
- ✅ Health monitoring (proactive alerts)
- ✅ Comprehensive error handling (graceful degradation)

## 🎯 Best Practices

### 1. **Don't Force Refresh Unless Necessary**
```dart
// ❌ Bad: Forces API call every time
final matches = await apiService.fetchCurrentMatches(forceRefresh: true);

// ✅ Good: Uses cache when available
final matches = await apiService.fetchCurrentMatches();
```

### 2. **Monitor Health in Production**
```dart
// Periodically check health
final health = apiService.getHealthStatus();

if (health == CricApiHealthStatus.critical) {
  // Alert admin or show user notification
  showNotification('Cricket data service is experiencing issues');
}
```

### 3. **Handle Errors Gracefully**
```dart
try {
  final matches = await apiService.fetchCurrentMatches();
  // Process matches
} on CricApiException catch (e) {
  // Specific CricAPI error
  debugPrint('CricAPI Error: ${e.type} - ${e.message}');
  
  if (e.type == CricApiErrorType.authentication) {
    // Handle auth error
  } else if (e.type == CricApiErrorType.rateLimited) {
    // Show rate limit message
  }
} catch (e) {
  // General error
  debugPrint('Unexpected error: $e');
}
```

### 4. **Use Cache Stats for Debugging**
```dart
final stats = apiService.getCacheStats();

if (stats['consecutiveErrors'] > 3) {
  // Service is having issues
  debugPrint('⚠️ CricAPI has ${stats['consecutiveErrors']} consecutive errors');
  debugPrint('Last error: ${stats['lastError']}');
}
```

## 🔍 Troubleshooting

### Problem: No matches returned

**Check:**
1. API key is valid in `app_constants.dart`
2. Network connectivity
3. Cache stats: `apiService.getCacheStats()`
4. Health status: `apiService.getHealthStatus()`

**Solution:**
```dart
// Clear cache and force refresh
apiService.clearCache();
final matches = await apiService.fetchCurrentMatches(forceRefresh: true);
```

### Problem: Stale data

**Check:**
- Cache age in stats
- Last successful fetch time

**Solution:**
```dart
// Force refresh to get latest data
final matches = await apiService.fetchCurrentMatches(forceRefresh: true);
```

### Problem: Rate limiting errors

**Check:**
- Consecutive errors count
- Request frequency

**Solution:**
- Increase cache duration
- Reduce sync frequency
- Let automatic retry handle it

## 📞 Support

If you encounter issues:

1. **Check health monitor**: Add `CricApiHealthMonitor` widget
2. **Review logs**: Look for `CricAPI:` prefixed messages
3. **Test connection**: Use test script
4. **Check API status**: Visit https://www.cricapi.com/

## 🚀 Future Enhancements

Potential improvements:
- [ ] Persistent cache (save to disk)
- [ ] Webhook support for live updates
- [ ] Match-specific caching
- [ ] Predictive prefetching
- [ ] Analytics and metrics
- [ ] Custom retry strategies
- [ ] Circuit breaker pattern

---

**Version:** 2.0  
**Last Updated:** 2026-02-09  
**Author:** Winniko Development Team
