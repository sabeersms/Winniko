# AllSportsApi Tournament Discovery Guide

## 🎯 How to Find Specific Tournaments

### Method 1: Use the Tournament Discovery Screen (Recommended)

1. **Navigate to the screen:**
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => const TournamentDiscoveryScreen(),
     ),
   );
   ```

2. **Browse by Sport:**
   - Select a sport from the left panel (e.g., Cricket, Football)
   - View all tournaments for that sport in the middle panel
   - Select a tournament to see available seasons in the right panel

3. **Search Directly:**
   - Use the search bar at the top
   - Type tournament name (e.g., "Premier League", "IPL", "World Cup")
   - Results show tournament ID and type
   - Click the copy icon to copy the ID

4. **Get Code Snippet:**
   - After selecting a tournament and season
   - Click the code icon (</>) next to a season
   - Get ready-to-use code with the correct IDs

### Method 2: Use the API Service Directly

```dart
import 'package:winniko/services/allsports_api_service.dart';

final apiService = AllSportsApiService();

// 1. Get all sports
final sports = await apiService.getSports();
// Returns: [{ id: 1, name: "Football" }, { id: 3, name: "Cricket" }, ...]

// 2. Get tournaments for a sport
final tournaments = await apiService.getTournamentsBySport(3); // Cricket
// Returns: [{ id: 234, name: "IPL" }, { id: 132, name: "T20 World Cup" }, ...]

// 3. Search for a specific tournament
final results = await apiService.searchTournaments("Premier League");
// Returns: [{ type: "uniqueTournament", entity: { id: 17, name: "Premier League" } }, ...]

// 4. Get seasons for a tournament
final seasons = await apiService.getTournamentSeasons("234"); // IPL
// Returns: [{ id: 58766, name: "IPL 2024" }, { id: 52760, name: "IPL 2023" }, ...]
```

### Method 3: Run the Test Script

```bash
# From your project directory
dart test_scripts/test_allsports_discovery.dart
```

This will print:
- All available sports with IDs
- Sample cricket tournaments
- Search results for "Premier League"
- IPL seasons
- Example code snippets

## 📊 Common Sport IDs

| Sport       | ID |
|-------------|-----|
| Football    | 1   |
| Basketball  | 2   |
| Cricket     | 3   |
| Tennis      | 4   |
| Rugby       | 5   |
| Handball    | 6   |
| Ice Hockey  | 7   |
| Baseball    | 8   |

## 🏆 Popular Tournament IDs

### Cricket (Sport ID: 3)
| Tournament          | ID  | Notes                    |
|---------------------|-----|--------------------------|
| IPL                 | 234 | Indian Premier League    |
| T20 World Cup       | 132 | ICC T20 World Cup        |
| Cricket World Cup   | 20  | ICC ODI World Cup        |
| The Hundred         | 717 | England's The Hundred    |
| Big Bash League     | 138 | Australia's BBL          |
| Pakistan Super League| 237 | PSL                     |

### Football (Sport ID: 1)
| Tournament          | ID  | Notes                    |
|---------------------|-----|--------------------------|
| Premier League      | 17  | English Premier League   |
| La Liga             | 8   | Spanish La Liga          |
| Serie A             | 23  | Italian Serie A          |
| Bundesliga          | 35  | German Bundesliga        |
| Champions League    | 7   | UEFA Champions League    |
| World Cup           | 16  | FIFA World Cup           |

## 💡 Usage Examples

### Example 1: Get Premier League 2025/2026 Matches
```dart
final events = await apiService.getSeasonTeamEventsAway(
  tournamentId: '17',    // Premier League
  seasonId: '61627',     // 2025/2026 season
);

for (var event in events) {
  print('${event['homeTeam']['name']} vs ${event['awayTeam']['name']}');
}
```

### Example 2: Get IPL 2024 Matches
```dart
final iplMatches = await apiService.getSeasonTeamEventsAway(
  tournamentId: '234',   // IPL
  seasonId: '58766',     // 2024 season
);
```

### Example 3: Get Live Cricket Matches
```dart
final liveMatches = await apiService.getLiveMatches(3); // 3 = Cricket

for (var match in liveMatches) {
  final status = match['status']['description'];
  print('LIVE: ${match['homeTeam']['name']} vs ${match['awayTeam']['name']} - $status');
}
```

### Example 4: Get Tournament Standings
```dart
final standings = await apiService.getTournamentStandings(
  tournamentId: '17',    // Premier League
  seasonId: '61627',     // 2025/2026
);

// standings contains team rankings, points, wins, losses, etc.
```

### Example 5: Search for Any Tournament
```dart
final results = await apiService.searchTournaments('World Cup');

for (var result in results) {
  final entity = result['entity'];
  if (entity != null && result['type'] == 'uniqueTournament') {
    print('${entity['name']} - ID: ${entity['id']}');
  }
}
```

## 🔧 Integration with Your App

### Step 1: Add to Your Competition Creation
```dart
// In your competition create screen, add a button to discover tournaments
ElevatedButton(
  onPressed: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TournamentDiscoveryScreen(),
      ),
    );
    
    if (result != null) {
      // Use the selected tournament ID and season ID
      setState(() {
        _tournamentId = result['tournamentId'];
        _seasonId = result['seasonId'];
      });
    }
  },
  child: const Text('Find Tournament'),
)
```

### Step 2: Sync Matches Automatically
```dart
// In your tournament_data_service.dart
static Future<void> syncFromAllSportsApi({
  required String competitionId,
  required String tournamentId,
  required String seasonId,
}) async {
  final apiService = AllSportsApiService();
  
  // Fetch matches
  final events = await apiService.getSeasonTeamEventsAway(
    tournamentId: tournamentId,
    seasonId: seasonId,
  );
  
  // Convert to your MatchModel format
  final matches = events.map((event) {
    return MatchModel(
      id: event['id'].toString(),
      competitionId: competitionId,
      team1Name: event['homeTeam']['name'],
      team2Name: event['awayTeam']['name'],
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(
        event['startTimestamp'] * 1000,
      ),
      status: _convertStatus(event['status']),
      // ... map other fields
    );
  }).toList();
  
  // Save to Firestore
  await firestore.saveBatchMatches(competitionId, matches);
}
```

## 🎓 Tips

1. **Finding Season IDs:**
   - Seasons are usually sorted by year (most recent first)
   - Look for the current year or upcoming season
   - Season IDs change every year

2. **Tournament Names:**
   - Search is case-insensitive
   - Try variations: "Premier League", "EPL", "English Premier League"
   - Use partial names: "World Cup" will find all World Cups

3. **API Limits:**
   - RapidAPI has rate limits (check your plan)
   - Cache results when possible
   - Use the discovery screen during development, not in production

4. **Testing:**
   - Use the test script to verify IDs work
   - Check if the tournament has current season data
   - Some tournaments may not have live data available

## 📞 Need Help?

If you can't find a specific tournament:
1. Try searching with different keywords
2. Browse by sport to see all available tournaments
3. Check if the tournament is active/current
4. Some tournaments may use different names (e.g., "UEFA Champions League" vs "Champions League")

## 🚀 Next Steps

1. Open the Tournament Discovery Screen in your app
2. Search for your desired tournament
3. Copy the tournament ID and season ID
4. Use the code snippet provided
5. Integrate into your sync service

Happy discovering! 🎉
