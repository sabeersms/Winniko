import 'package:http/http.dart' as http;
import 'dart:convert';

/// Simple test to check AllSportsApi endpoint availability
///
/// This tests which endpoints work with your current subscription
void main() async {
  const apiKey = '04a2aaf5d7msh17a87f735bae4c66p1c2dbjsned2c6683a1s59';
  const apiHost = 'allsportsapi2.p.rapidapi.com';
  const baseUrl = 'https://allsportsapi2.p.rapidapi.com';

  print('🔍 Testing AllSportsApi Endpoint Availability');
  print('=' * 70);
  print('API Key: ${apiKey.substring(0, 10)}...');
  print('Host: $apiHost');
  print('=' * 70);

  // Test different endpoints to see which ones work
  final endpoints = [
    {
      'name': 'Get Tournament Events (T20 WC 2026)',
      'url': '$baseUrl/api/tournament/132/season/61627/events/next/0',
      'description': 'Fetch upcoming matches for T20 World Cup 2026',
    },
    {
      'name': 'Get Tournament Seasons',
      'url': '$baseUrl/api/tournament/132/seasons',
      'description': 'Get all seasons for T20 World Cup',
    },
    {
      'name': 'Get Live Cricket Matches',
      'url': '$baseUrl/api/sport/3/events/live',
      'description': 'Get currently live cricket matches',
    },
    {
      'name': 'Search Tournaments',
      'url': '$baseUrl/api/search/IPL',
      'description': 'Search for tournaments by name',
    },
    {
      'name': 'Get Tournament Standings',
      'url': '$baseUrl/api/tournament/234/season/58766/standings/total',
      'description': 'Get IPL 2024 standings',
    },
  ];

  for (var i = 0; i < endpoints.length; i++) {
    final endpoint = endpoints[i];
    print('\n📍 Test ${i + 1}: ${endpoint['name']}');
    print('   ${endpoint['description']}');
    print('   URL: ${endpoint['url']}');

    await Future.delayed(Duration(seconds: 2)); // Rate limit protection

    try {
      final response = await http.get(
        Uri.parse(endpoint['url']!),
        headers: {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost},
      );

      if (response.statusCode == 200) {
        print('   ✅ SUCCESS! Status: ${response.statusCode}');

        // Parse and show sample data
        try {
          final data = json.decode(response.body);
          final dataStr = json.encode(data);
          if (dataStr.length > 200) {
            print('   📊 Response preview: ${dataStr.substring(0, 200)}...');
          } else {
            print('   📊 Response: $dataStr');
          }
        } catch (e) {
          print('   📊 Response received (could not parse JSON)');
        }
      } else if (response.statusCode == 403) {
        print('   ❌ FAILED: 403 - Not subscribed to this endpoint');
        print('   💡 This endpoint requires a different subscription plan');
      } else if (response.statusCode == 429) {
        print('   ⚠️  RATE LIMITED: 429 - Too many requests');
        print('   💡 Wait a moment before trying again');
      } else {
        print('   ❌ FAILED: ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e) {
      print('   ❌ ERROR: $e');
    }
  }

  print('\n${'=' * 70}');
  print('📋 Summary & Recommendations:');
  print('=' * 70);
  print('''
Based on the test results above:

1. ✅ Working Endpoints:
   - Use these endpoints in your app
   - They are included in your current subscription

2. ❌ 403 Errors (Not Subscribed):
   - These endpoints require upgrading your RapidAPI plan
   - Check https://rapidapi.com/fluis.lacasse/api/allsportsapi2/pricing

3. ⚠️  429 Errors (Rate Limited):
   - You're making too many requests
   - Add delays between API calls
   - Cache results to reduce API calls

4. 💡 Alternative Solutions:
   - Continue using CricAPI for cricket (already working)
   - Use AllSportsApi only for sports not covered by CricAPI
   - Consider upgrading RapidAPI plan if you need more endpoints

5. 🔧 Next Steps:
   - If endpoints work: Integrate them into your app
   - If 403 errors: Check your RapidAPI subscription
   - If 429 errors: Add caching and rate limiting
''');
}
