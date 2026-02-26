import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> checkMatches() async {
  final db = FirebaseFirestore.instance;

  print('--- OFFICIAL LEAGUE MATCHES ---');
  final officialSnap = await db
      .collection('official_leagues')
      .doc('mens-t20-world-cup-2026')
      .collection('matches')
      .get();

  for (var doc in officialSnap.docs) {
    print(
      'ID: ${doc.id} | ${doc.data()['team1Name']} vs ${doc.data()['team2Name']} | Verified: ${doc.data()['actualScore']?['verified']}',
    );
  }

  print('\n--- CONTEST MATCHES (T20 CONTEST) ---');
  final contestSnap = await db
      .collection('competitions')
      .doc('f7b5c908-a118-44b0-b78a-b2d23627f2be')
      .collection('matches')
      .get();

  for (var doc in contestSnap.docs) {
    print(
      'ID: ${doc.id} | ${doc.data()['team1Name']} vs ${doc.data()['team2Name']} | Status: ${doc.data()['status']}',
    );
  }
}
