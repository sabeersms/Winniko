import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;
  final leagueId = 'mens-t20-world-cup-2026';

  final hardDocs = await db
      .collection('official_leagues')
      .doc(leagueId)
      .collection('matches')
      .get();

  print('Total hard copy matches: \${hardDocs.docs.length}');
  int countFinished = 0;
  for (var doc in hardDocs.docs) {
    final data = doc.data();
    if (data['status'] != 'upcoming' && data['status'] != 'scheduled') {
      countFinished++;
    }
  }
  print('Finished/Live hard copy matches: \$countFinished');

  // also check competition
  final compsSnap = await db
      .collection('competitions')
      .where('leagueId', isEqualTo: leagueId)
      .get();
  for (var comp in compsSnap.docs) {
    if (comp.id == 'f7b5c908-a118-44b0-b78a-b2d23627f2be') {
      final matches = await db
          .collection('competitions')
          .doc(comp.id)
          .collection('matches')
          .get();
      int count = 0;
      for (var doc in matches.docs) {
        final data = doc.data();
        if (data['status'] != 'upcoming' && data['status'] != 'scheduled') {
          count++;
        }
      }
      print('Competition \${comp.id} non-upcoming matches: \$count');
    }
  }
  print('Done');
}
