import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;

  final contestId = 'f7b5c908-a118-44b0-b78a-b2d23627f2be';
  final leagueId = 'mens-t20-world-cup-2026';

  print('--- CLEANING CONTEST $contestId ---');

  // 1. Get Official Matches (Truth)
  final hardSnap = await db
      .collection('official_leagues')
      .doc(leagueId)
      .collection('matches')
      .get();

  final List<Map<String, dynamic>> officialMatchWindows = hardSnap.docs.map((
    doc,
  ) {
    final data = doc.data();
    final time = (data['scheduledTime'] as Timestamp).toDate();
    return {'t1': data['team1Name'], 't2': data['team2Name'], 'time': time};
  }).toList();

  // 2. Get Contest Matches
  final contestSnap = await db
      .collection('competitions')
      .doc(contestId)
      .collection('matches')
      .get();

  int deleteCount = 0;
  for (var doc in contestSnap.docs) {
    final data = doc.data();
    final t1 = data['team1Name'];
    final t2 = data['team2Name'];
    final time = (data['scheduledTime'] as Timestamp).toDate();

    // Check if this match exists in the official list (within 24h window)
    bool foundInOfficial = officialMatchWindows.any((off) {
      bool namesMatch =
          (off['t1'] == t1 && off['t2'] == t2) ||
          (off['t1'] == t2 && off['t2'] == t1);
      if (!namesMatch) return false;

      return off['time'].difference(time).inHours.abs() < 24;
    });

    if (!foundInOfficial) {
      print('🗑️ Deleting wrong match: $t1 vs $t2 at $time (ID: ${doc.id})');
      await doc.reference.delete();
      deleteCount++;
    }
  }

  print('\n✅ Done. Deleted $deleteCount wrong/stale matches.');
}
