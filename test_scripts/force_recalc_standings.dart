import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:winniko/services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final fs = FirestoreService();
  final db = FirebaseFirestore.instance;
  final leagueId = 'mens-t20-world-cup-2026';

  print('Recalculating standings for all T20 World Cup competitions...');

  final compsSnap = await db
      .collection('competitions')
      .where('leagueId', isEqualTo: leagueId)
      .get();

  for (var doc in compsSnap.docs) {
    try {
      print('Updating competition: \${doc.id}');
      await fs.recalculateStandings(doc.id);
      print('✅ Done');
    } catch (e) {
      print('❌ Error on \${doc.id}: \$e');
    }
  }

  print('All done.');
}
