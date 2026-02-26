# API Usage Tracking Guide

## Overview

Your Winniko app now has comprehensive API usage tracking to help you monitor and manage your API call limits for both **CricAPI** and **RapidAPI**.

## 🎯 Features

- ✅ **Automatic tracking** of all API calls
- ✅ **Rate limit monitoring** from API response headers
- ✅ **Daily usage counters** with automatic reset
- ✅ **Warning alerts** when approaching limits
- ✅ **Detailed usage reports** in console and UI
- ✅ **Real-time remaining calls** tracking

## 📊 How It Works

### Automatic Tracking

Every time your app makes an API call to CricAPI or RapidAPI, the system automatically:

1. **Records the call** in the daily counter
2. **Extracts rate limit headers** from the response
3. **Logs usage statistics** to the console
4. **Warns you** if approaching limits

### Rate Limit Headers

The tracker monitors these standard headers:

**CricAPI:**
- `x-ratelimit-limit` - Total daily limit
- `x-ratelimit-remaining` - Calls remaining
- `x-ratelimit-reset` - When the limit resets

**RapidAPI:**
- `x-ratelimit-requests-limit` - Total daily limit
- `x-ratelimit-requests-remaining` - Calls remaining

## 🚀 Usage

### Method 1: Console Monitoring (Automatic)

Every API call automatically logs usage to the console:

```
📊 CricAPI Usage: 15 calls today
   Remaining: 485 / 500 (3.0% used)
```

### Method 2: Quick Console Check

Run this command to get a detailed report:

```bash
dart run test_scripts/check_api_limits.dart
```

This will:
- Make test calls to both APIs
- Display comprehensive usage report
- Show warnings if approaching limits

### Method 3: Visual UI Monitor

Run the visual API usage monitor:

```bash
flutter run test_scripts/test_api_usage.dart
```

This provides:
- Real-time usage dashboard
- Visual progress bars
- Color-coded warnings
- Refresh capability

### Method 4: Programmatic Access

In your code, you can access the tracker:

```dart
import 'package:winniko/services/api_usage_tracker.dart';

// Get the tracker instance
final tracker = ApiUsageTracker();

// Get comprehensive report
final report = tracker.getUsageReport();
print('CricAPI calls today: ${report['cricApi']['callsToday']}');
print('RapidAPI remaining: ${report['rapidApi']['remaining']}');

// Print detailed report to console
tracker.printUsageReport();

// Check if approaching limits (80% threshold)
if (tracker.isApproachingLimit()) {
  print('⚠️ Warning: Approaching API limits!');
}

// Get remaining calls for specific API
final cricRemaining = tracker.getRemainingCalls('cric');
if (cricRemaining != null && cricRemaining < 100) {
  print('⚡ Only $cricRemaining CricAPI calls left!');
}
```

## 📈 Understanding Your Limits

### CricAPI Limits

**Free Tier:**
- 100 calls/day
- Resets at midnight UTC

**Paid Tiers:**
- Basic: 500 calls/day
- Pro: 2,500 calls/day
- Enterprise: Custom

### RapidAPI Limits

Depends on your subscription plan. Common limits:
- Free: 100-500 calls/month
- Basic: 10,000 calls/month
- Pro: 100,000 calls/month

## ⚠️ Warning Thresholds

The system warns you at these usage levels:

- **25% used** - ⚡ ALERT message
- **10% remaining** - ⚠️ WARNING message
- **80% used** - `isApproachingLimit()` returns true

## 🔧 Troubleshooting

### "No rate limit info available yet"

This means:
- No API calls have been made yet, OR
- The API doesn't return rate limit headers

**Solution:** Make an API call, then check again.

### Counters seem wrong

The tracker resets daily counters at midnight (local time). If you see unexpected numbers:
1. Check the last reset time in the report
2. Verify your system clock is correct
3. Remember: The tracker only counts calls made AFTER it was integrated

### API returns 429 (Too Many Requests)

You've exceeded your rate limit. Options:
1. **Wait** for the reset time (shown in the report)
2. **Upgrade** your API plan
3. **Reduce** refresh frequency in your app
4. **Implement caching** (already done in CricAPI service)

## 💡 Best Practices

### 1. Monitor Regularly

Check your usage at least once a day:
```bash
dart run test_scripts/check_api_limits.dart
```

### 2. Set Up Alerts

Add this to your app initialization:

```dart
void checkApiLimits() {
  final tracker = ApiUsageTracker();
  if (tracker.isApproachingLimit(threshold: 0.75)) {
    // Show user notification
    // Or reduce refresh frequency
    debugPrint('⚠️ Reducing API calls due to high usage');
  }
}
```

### 3. Use Caching

The CricAPI service already has smart caching:
- 2-minute cache for fresh data
- 30-minute fallback cache on errors
- Automatic retry with backoff

### 4. Optimize Refresh Frequency

Current app settings:
- **2-minute throttle** between tournament refreshes
- **5 matches max** per detailed score fetch cycle

Adjust these in `tournament_data_service.dart` if needed.

### 5. Plan Upgrades

If you consistently hit limits:
- **CricAPI**: Upgrade at https://www.cricapi.com/pricing
- **RapidAPI**: Upgrade at https://rapidapi.com/pricing

## 📝 Example Output

### Console Report

```
============================================================
📊 API USAGE REPORT
============================================================

🏏 CricAPI:
   Calls Today: 47
   Limit: 500
   Remaining: 453
   Usage: 9.4%
   Resets: 2026-02-17T00:00:00.000Z

⚡ RapidAPI:
   Calls Today: 23
   Limit: 10000
   Remaining: 9977
   Usage: 0.2%

============================================================
```

### Visual UI

The UI shows:
- 📊 **Usage cards** for each API
- 📈 **Progress bars** with color coding:
  - 🟢 Green: < 50% used
  - 🟡 Yellow: 50-75% used
  - 🟠 Orange: 75-90% used
  - 🔴 Red: > 90% used
- ⏰ **Reset countdown** timer
- ⚠️ **Warning banner** when approaching limits

## 🎓 Advanced Usage

### Custom Threshold Alerts

```dart
// Check at 60% usage
if (tracker.isApproachingLimit(threshold: 0.6)) {
  // Take action earlier
}
```

### Integration with Analytics

```dart
final report = tracker.getUsageReport();
// Send to your analytics service
analytics.logEvent('api_usage', parameters: report);
```

### Scheduled Monitoring

```dart
// Check every hour
Timer.periodic(Duration(hours: 1), (_) {
  ApiUsageTracker().printUsageReport();
});
```

## 📞 Support

If you have questions about:
- **API limits**: Contact your API provider
- **Tracker issues**: Check the code in `lib/services/api_usage_tracker.dart`
- **Integration**: Review this guide

## 🔄 Updates

The tracker automatically:
- ✅ Resets counters daily
- ✅ Updates limits from headers
- ✅ Logs all activity
- ✅ Persists across app sessions (in memory)

**Note:** Usage data is stored in memory only. It resets when the app restarts.

---

**Last Updated:** 2026-02-16
**Version:** 1.0.0
