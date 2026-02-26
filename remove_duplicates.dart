import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final leagueId = 'mens-t20-world-cup-2026';
  final matchesRef = FirebaseFirestore.instance
      .collection('official_leagues')
      .doc(leagueId)
      .collection('matches');

  final snap = await matchesRef.get();
  print('--- Hard Copy Matches in $leagueId ---');
  print('Found ${snap.docs.length} matches.');

  final Map<String, List<String>> seen = {};
  int duplicatesCount = 0;

  for (var doc in snap.docs) {
    final data = doc.data();
    final t1 = data['team1Name'] ?? '';
    final t2 = data['team2Name'] ?? '';
    final timeStr = data['scheduledTime'] != null
        ? (data['scheduledTime'] as Timestamp).toDate().toString()
        : '';

    // Create a key from sorted teams and time
    final teams = [t1.toString(), t2.toString()]..sort();
    final key = '${teams[0]}_${teams[1]}_$timeStr';

    if (!seen.containsKey(key)) {
      seen[key] = [];
    }
    seen[key]!.add(doc.id);
  }

  for (var entry in seen.entries) {
    if (entry.value.length > 1) {
      duplicatesCount++;
      print('DUPLICATE FOUND: ${entry.key}');
      for (var id in entry.value) {
        print('  - Doc ID: $id');
      }

      // Delete duplicates, keep the first one
      for (int i = 1; i < entry.value.length; i++) {
        print('  Deleting duplicate doc: ${entry.value[i]}');
        await matchesRef.doc(entry.value[i]).delete();
        print('  Deleted!');
      }
    }
  }

  if (duplicatesCount == 0) {
    print('No obvious duplicates found by Team Pair + Time.');
  } else {
    print('Cleaned up $duplicatesCount sets of duplicates.');
  }

  print('Done.');
}
