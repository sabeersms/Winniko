import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;
  final leagueId = 'mens-t20-world-cup-2026';

  print('--- CHECKING HARD COPY ---');
  final hardSnap = await db
      .collection('official_leagues')
      .doc(leagueId)
      .collection('matches')
      .get();

  print('Found ${hardSnap.docs.length} matches in Hard Copy.');
  for (var doc in hardSnap.docs) {
    print(
      'HARD: ${doc.data()['team1Name']} vs ${doc.data()['team2Name']} | ID: ${doc.id}',
    );
  }

  print('\n--- CHECKING SOFT COPY ---');
  final softSnap = await db
      .collection('official_leagues')
      .doc(leagueId)
      .collection('soft_matches')
      .get();

  print('Found ${softSnap.docs.length} matches in Soft Copy.');
  for (var doc in softSnap.docs) {
    print(
      'SOFT: ${doc.data()['team1Name']} vs ${doc.data()['team2Name']} | ID: ${doc.id}',
    );
  }
}
