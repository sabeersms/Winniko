# Manual Score Protection Implementation

## Overview
This document describes the implementation of **global protection** for manually scored matches in official tournaments. When any organizer manually scores a match in an official tournament (e.g., IPL, Premier League), that score is protected across **ALL competitions** using the same tournament.

## Problem Statement
Previously, when a master admin manually entered a score for a match, subsequent API refreshes could potentially overwrite or modify:
- The actual score
- The match status
- The winner ID

Additionally, the protection was **per-competition only**. If Organizer A manually scored "India vs Pakistan" in their IPL competition, and Organizer B also had an IPL competition, Organizer B's match could still be overwritten by API refreshes.

This was problematic because:
1. Master admins need the ability to fix incorrect scores globally
2. Manual corrections should apply to all instances of the same official match
3. Different organizers shouldn't have conflicting scores for the same official match

## Solution

### 1. Global Protection via `official_leagues` Collection
**Files**: 
- `lib/services/firestore_service.dart` (new functions: `_saveManualScoreToOfficialLeagues`, `_removeManualScoreFromOfficialLeagues`)
- `lib/services/tournament_data_service.dart` (existing sync logic)

When a match is manually scored in an **official tournament** (one with a `leagueId`):

1. **Save to Competition**: The score is saved to the specific competition's match (as before)
2. **Save to Global Database**: The score is ALSO saved to `official_leagues/{leagueId}/matches/{matchId}`
3. **Global Sync**: When ANY competition syncs from `official_leagues`, it receives the manually scored data
4. **Protection**: The existing protection logic skips ALL updates for manually scored matches

**Key Implementation** (`firestore_service.dart`, lines 1315-1322):
```dart
// 🌍 GLOBAL PROTECTION: If manually scored, save to official_leagues
if (score.isNotEmpty && score['manuallyScored'] == true) {
  await _saveManualScoreToOfficialLeagues(
    competitionId,
    matchId,
    score,
    status,
  );
}
```

The function intelligently matches the competition match to the official match by:
- Team names (both forward and reversed order)
- Scheduled time (within 12-hour tolerance)

### 2. Complete Protection Logic
**File**: `lib/services/tournament_data_service.dart`

When the sync process runs (in `refreshCompetitionScores`), it now checks if a match has the `manuallyScored` flag set to `true`. If it does, the entire match is skipped from any API updates.

**Key Changes** (lines 1114-1124):
```dart
final bool isManuallyScored = internal.actualScore?['manuallyScored'] == true;

// 🛡️ COMPLETE PROTECTION: If manually scored by master admin, skip ALL updates
if (isManuallyScored) {
  debugPrint(
    '🛡️ FULLY PROTECTED: Skipping ALL API updates for ${internal.team1Name} vs ${internal.team2Name} (manually scored by master admin)',
  );
  continue; // Skip this match entirely
}
```

This ensures that:
- ✅ Score cannot be overwritten
- ✅ Status cannot be changed
- ✅ Winner ID cannot be modified
- ✅ Scheduled time cannot be updated
- ✅ Any other match data remains unchanged

### 2. Visual Indicator
**File**: `lib/screens/match_score_screen.dart`

Added a visual banner at the top of the match score screen to indicate when a match is protected:

```dart
if (widget.match.actualScore?['manuallyScored'] == true)
  Container(
    // Green banner with lock icon
    child: Row(
      children: [
        Icon(Icons.lock, color: AppColors.accentGreen),
        Text('This match has been manually scored and is protected from API updates'),
      ],
    ),
  )
```

This provides clear visual feedback to the master admin that:
- The match has been manually scored
- It is protected from API updates
- The data is locked and won't change on refresh

### 3. Automatic Flag Setting
**File**: `lib/screens/match_score_screen.dart` (already implemented)

When a master admin saves a score (lines 172-173 for cricket, 178 for other sports):
```dart
actualScore = {
  // ... score data ...
  'manuallyScored': true,  // ← Automatically set
};
```

## How It Works

### Flow Diagram: Global Protection
```
Scenario: Organizer A and Organizer B both have IPL 2024 competitions

1. Organizer A opens Match Score Screen for "MI vs CSK"
   ↓
2. Enters/Updates score manually
   ↓
3. Saves score → `manuallyScored: true` flag is set
   ↓
4a. Match is stored in Competition A's matches with protection flag
4b. Match is ALSO stored in official_leagues/ipl-2024/matches with protection flag 🌍
   ↓
5. API Refresh runs (periodic or manual) for Competition A
   ↓
6. Sync reads from official_leagues/ipl-2024/matches
   ↓
7. Finds `manuallyScored == true` → SKIP entirely
   ↓
8. Competition A's match data remains unchanged ✅
   
   --- MEANWHILE ---
   
9. API Refresh runs for Competition B (different organizer)
   ↓
10. Sync reads from official_leagues/ipl-2024/matches
   ↓
11. Finds `manuallyScored == true` for "MI vs CSK"
   ↓
12. Competition B's match is ALSO protected ✅
   ↓
13. ALL competitions using IPL 2024 now have the same protected score 🌍
```

### Flow Diagram: Local Protection (Non-Official Tournaments)
```
For custom tournaments without a leagueId:

1. Master Admin opens Match Score Screen
   ↓
2. Enters/Updates score manually
   ↓
3. Saves score → `manuallyScored: true` flag is set
   ↓
4. Match is stored in Competition's matches with protection flag
   (NOT saved to official_leagues - no leagueId)
   ↓
5. API Refresh runs (if applicable)
   ↓
6. Sync checks: if `manuallyScored == true` → SKIP entirely
   ↓
7. Match data remains unchanged ✅
```

### Reset Functionality
If a master admin wants to allow API updates again, they can:
1. Use the "Reset to Scheduled" button in the Match Score Screen
2. This clears the `actualScore` (including the `manuallyScored` flag)
3. The match becomes eligible for API updates again

## Testing Recommendations

### Test Case 1: Manual Score Protection
1. Create a competition with matches
2. Manually score a match as master admin
3. Trigger an API refresh
4. Verify the score remains unchanged
5. Check logs for "🛡️ FULLY PROTECTED" message

### Test Case 2: Visual Indicator
1. Open a manually scored match in the Match Score Screen
2. Verify the green lock banner appears at the top
3. Open a non-manually scored match
4. Verify no banner appears

### Test Case 3: Reset and Re-sync
1. Manually score a match
2. Reset it to "Scheduled"
3. Trigger an API refresh
4. Verify the match now gets updated from API

## Benefits

### Global Protection Benefits
1. **Consistency Across Organizers**: All competitions using the same official tournament have identical scores
2. **Single Source of Truth**: One manual correction fixes the score for everyone
3. **Reduced Admin Burden**: Organizers don't need to individually fix scores in their competitions
4. **Data Integrity**: Master admin changes are never lost, even across different competitions
5. **Scalability**: Works automatically for any number of competitions using the same tournament

### Local Protection Benefits
1. **Data Integrity**: Master admin changes are never lost
2. **Predictability**: Once scored manually, the data is fixed
3. **Transparency**: Visual indicator shows protection status
4. **Flexibility**: Reset option allows re-enabling API updates if needed
5. **Performance**: Protected matches are skipped early, reducing processing time

### User Experience Benefits
1. **No Conflicts**: Different organizers can't have conflicting scores for official matches
2. **Trust**: Users see consistent scores regardless of which competition they join
3. **Reliability**: Manual corrections by trusted admins override potentially incorrect API data

## Migration Notes

- **Backward Compatible**: Existing matches without the `manuallyScored` flag will continue to receive API updates
- **No Database Migration Required**: The flag is checked dynamically
- **Existing Manual Scores**: If you have existing manually scored matches, they may need to be re-saved to get the protection flag (or you can add it manually in Firestore)

## Related Files

- `lib/services/tournament_data_service.dart` - Sync logic with protection
- `lib/screens/match_score_screen.dart` - Manual scoring UI with flag setting and visual indicator
- `lib/models/match_model.dart` - Match data model (no changes needed)
- `lib/services/firestore_service.dart` - Database operations (no changes needed)
