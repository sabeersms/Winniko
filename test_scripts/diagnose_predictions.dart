import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// DRY RUN: Shows what the recovery script would do without making any changes.
/// Run this FIRST to verify the mapping is correct.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;

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

    // Get current matches
    final matchesSnap = await db
        .collection('competitions')
        .doc(compId)
        .collection('matches')
        .get();

    print('📦 Current matches: ${matchesSnap.docs.length}');
    for (var mDoc in matchesSnap.docs) {
      final d = mDoc.data();
      print(
        '   Match: ${mDoc.id} → ${d['team1Name']} vs ${d['team2Name']} (${d['status']})',
      );
    }

    // Get predictions
    final predictionsSnap = await db
        .collection('predictions')
        .where('competitionId', isEqualTo: compId)
        .get();

    print('\n🔮 Total predictions: ${predictionsSnap.docs.length}');

    final currentMatchIds = matchesSnap.docs.map((d) => d.id).toSet();
    int valid = 0;
    int orphaned = 0;
    final orphanedMatchIds = <String>{};

    for (var pDoc in predictionsSnap.docs) {
      final pData = pDoc.data();
      final matchId = pData['matchId'] ?? '';
      if (currentMatchIds.contains(matchId)) {
        valid++;
      } else {
        orphaned++;
        orphanedMatchIds.add(matchId);
      }
    }

    print('   ✅ Valid (matchId exists): $valid');
    print('   ⚠️  Orphaned (matchId missing): $orphaned');
    print('   📝 Unique orphaned matchIds: ${orphanedMatchIds.length}');
    for (var oid in orphanedMatchIds) {
      print('      - $oid');
    }

    // Check participant standings
    final participantsSnap = await db
        .collection('competitions')
        .doc(compId)
        .collection('participants')
        .get();
    print('\n👥 Participants: ${participantsSnap.docs.length}');
    for (var pDoc in participantsSnap.docs) {
      final d = pDoc.data();
      print(
        '   ${d['userName'] ?? pDoc.id}: points=${d['totalPoints'] ?? 0}, predictions=${d['totalPredictions'] ?? 0}',
      );
    }
  }

  print('\n🏁 Dry run complete. No changes made.');
}
