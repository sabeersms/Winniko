import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// This script recovers predictions that became orphaned after matches were
/// cleaned and re-published (new match IDs). It:
/// 1. Finds all predictions for the target competition
/// 2. Identifies orphaned predictions (matchId not in current matches)
/// 3. Looks up the OLD match data to get team names
/// 4. Finds the NEW match with matching team names
/// 5. Updates the prediction's matchId to the new match ID
/// 6. Recalculates standings
///
/// SAFE: Only updates prediction matchIds. Does NOT touch competition settings,
/// match data, teams, or participant data.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────
  // STEP 1: Find the T20 contest competition
  // ──────────────────────────────────────────────────
  print('🔍 Looking for T20 contest competitions...');
  final compsSnap = await db
      .collection('competitions')
      .where('leagueId', isEqualTo: 'mens-t20-world-cup-2026')
      .get();

  if (compsSnap.docs.isEmpty) {
    print('❌ No T20 World Cup competitions found.');
    return;
  }

  for (var compDoc in compsSnap.docs) {
    final compId = compDoc.id;
    final compName = compDoc.data()['name'] ?? 'Unknown';
    print('\n════════════════════════════════════════');
    print('📋 Competition: $compName ($compId)');
    print('════════════════════════════════════════');

    // ──────────────────────────────────────────────────
    // STEP 2: Get all CURRENT matches in this competition
    // ──────────────────────────────────────────────────
    final matchesSnap = await db
        .collection('competitions')
        .doc(compId)
        .collection('matches')
        .get();

    final currentMatches = <String, Map<String, dynamic>>{};
    for (var mDoc in matchesSnap.docs) {
      currentMatches[mDoc.id] = mDoc.data();
    }
    print('📦 Current matches: ${currentMatches.length}');

    // Build a lookup: "team1Name_vs_team2Name" -> matchId (bidirectional)
    final teamMatchLookup = <String, String>{};
    for (var entry in currentMatches.entries) {
      final mid = entry.key;
      final data = entry.value;
      final t1 = (data['team1Name'] ?? '').toString().toLowerCase().trim();
      final t2 = (data['team2Name'] ?? '').toString().toLowerCase().trim();
      if (t1.isNotEmpty && t2.isNotEmpty) {
        teamMatchLookup['${t1}_vs_$t2'] = mid;
        teamMatchLookup['${t2}_vs_$t1'] = mid; // reversed
      }
    }

    // ──────────────────────────────────────────────────
    // STEP 3: Get all predictions for this competition
    // ──────────────────────────────────────────────────
    final predictionsSnap = await db
        .collection('predictions')
        .where('competitionId', isEqualTo: compId)
        .get();

    print('🔮 Total predictions: ${predictionsSnap.docs.length}');

    // Identify orphaned predictions (matchId not in current matches)
    final orphanedPredictions = <QueryDocumentSnapshot>[];
    int alreadyValid = 0;
    for (var pDoc in predictionsSnap.docs) {
      final pData = pDoc.data() as Map<String, dynamic>;
      final matchId = pData['matchId'] ?? '';
      if (currentMatches.containsKey(matchId)) {
        alreadyValid++;
      } else {
        orphanedPredictions.add(pDoc);
      }
    }

    print('✅ Valid predictions: $alreadyValid');
    print('⚠️  Orphaned predictions: ${orphanedPredictions.length}');

    if (orphanedPredictions.isEmpty) {
      print('   No orphaned predictions to recover.');
      continue;
    }

    // ──────────────────────────────────────────────────
    // STEP 4: Try to recover each orphaned prediction
    // ──────────────────────────────────────────────────
    // Collect unique old match IDs to look up
    final oldMatchIds = orphanedPredictions
        .map((p) => (p.data() as Map<String, dynamic>)['matchId'] as String)
        .toSet();

    print('🔎 Looking up ${oldMatchIds.length} old match IDs...');

    // Try to find old match data. Check ALL competitions with this leagueId,
    // and also check if the match doc still exists (it might have been deleted).
    final oldMatchTeams = <String, Map<String, String>>{};

    for (var oldMid in oldMatchIds) {
      // Try each competition's matches subcollection
      for (var cDoc in compsSnap.docs) {
        final mSnap = await db
            .collection('competitions')
            .doc(cDoc.id)
            .collection('matches')
            .doc(oldMid)
            .get();

        if (mSnap.exists) {
          final mData = mSnap.data()!;
          oldMatchTeams[oldMid] = {
            'team1Name': (mData['team1Name'] ?? '')
                .toString()
                .toLowerCase()
                .trim(),
            'team2Name': (mData['team2Name'] ?? '')
                .toString()
                .toLowerCase()
                .trim(),
          };
          break;
        }
      }
    }

    // Also try to extract team names from the matchId format (date_Team1_v_Team2)
    for (var oldMid in oldMatchIds) {
      if (oldMatchTeams.containsKey(oldMid)) continue;

      // Try parsing from match doc ID format: "2026-02-15_TeamA_v_TeamB" or "match_XX"
      if (oldMid.contains('_v_')) {
        final parts = oldMid.split('_v_');
        if (parts.length == 2) {
          // Remove date prefix if present
          var t1Part = parts[0];
          if (t1Part.contains('_')) {
            t1Part = t1Part.substring(t1Part.lastIndexOf('_') + 1);
          }
          oldMatchTeams[oldMid] = {
            'team1Name': t1Part.toLowerCase(),
            'team2Name': parts[1].toLowerCase(),
          };
          print('   📝 Parsed from ID: $oldMid → $t1Part vs ${parts[1]}');
        }
      }
    }

    print(
      '   Found team names for ${oldMatchTeams.length}/${oldMatchIds.length} old matches',
    );

    // ──────────────────────────────────────────────────
    // STEP 5: Re-map predictions to new match IDs
    // ──────────────────────────────────────────────────
    int recovered = 0;
    int failed = 0;
    final batch = db.batch();
    int batchCount = 0;

    for (var pDoc in orphanedPredictions) {
      final pData = pDoc.data() as Map<String, dynamic>;
      final oldMatchId = pData['matchId'] as String;
      final userId = pData['userId'] ?? 'unknown';

      if (!oldMatchTeams.containsKey(oldMatchId)) {
        print(
          '   ❌ Cannot find team data for old match: $oldMatchId (user: $userId)',
        );
        failed++;
        continue;
      }

      final teams = oldMatchTeams[oldMatchId]!;
      final lookupKey = '${teams['team1Name']}_vs_${teams['team2Name']}';
      final newMatchId = teamMatchLookup[lookupKey];

      if (newMatchId == null) {
        print(
          '   ❌ No new match found for: ${teams['team1Name']} vs ${teams['team2Name']} (user: $userId)',
        );
        failed++;
        continue;
      }

      print(
        '   🔄 Remapping: $oldMatchId → $newMatchId (${teams['team1Name']} vs ${teams['team2Name']}, user: $userId)',
      );

      // Reset scoring fields so they can be re-processed
      batch.update(pDoc.reference, {
        'matchId': newMatchId,
        'isScored': false,
        'points': null,
        'wasPerfectScore': false,
        'wasCorrectOutcome': false,
      });

      recovered++;
      batchCount++;

      // Firestore batches max 500 operations
      if (batchCount >= 450) {
        print('   💾 Committing batch of $batchCount...');
        await batch.commit();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      print('   💾 Committing final batch of $batchCount...');
      await batch.commit();
    }

    print('\n📊 Recovery Summary for "$compName":');
    print('   ✅ Recovered: $recovered');
    print('   ❌ Failed: $failed');
    print('   📌 Already valid: $alreadyValid');

    // ──────────────────────────────────────────────────
    // STEP 6: Recalculate standings (re-process predictions)
    // ──────────────────────────────────────────────────
    if (recovered > 0) {
      print('\n🔄 To recalculate points, run force_recalc_standings.dart');
    }
  }

  print('\n🏁 Done!');
}
