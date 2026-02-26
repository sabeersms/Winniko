import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;

  print('--- OFFICIAL MATCHES ---');
  final snap = await db
      .collection('official_leagues')
      .doc('mens-t20-world-cup-2026')
      .collection('matches')
      .get();

  for (var doc in snap.docs) {
    print(
      'OFFICIAL: ${doc.data()['team1Name']} vs ${doc.data()['team2Name']} | Time: ${doc.data()['scheduledTime']}',
    );
  }
}
