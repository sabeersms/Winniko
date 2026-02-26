import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart'; // For WidgetsFlutterBinding
import 'lib/firebase_options.dart'; // Assuming standard options file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Checking Official Leagues in Firestore...');

  final snapshot = await FirebaseFirestore.instance
      .collection('official_leagues')
      .get();
  print('Found ${snapshot.docs.length} Official Leagues.');

  for (var doc in snapshot.docs) {
    print('League ID: ${doc.id}');
    // Check matches count
    final mSnapshot = await doc.reference.collection('matches').count().get();
    print('  Matches: ${mSnapshot.count}');

    // If T20 related, check sample
    if (doc.id.contains('t20') || doc.id.contains('wc')) {
      final matches = await doc.reference.collection('matches').limit(5).get();
      for (var m in matches.docs) {
        final data = m.data();
        print('    -> ${data['homeTeamName']} vs ${data['awayTeamName']}');
        print(
          '       Status: ${data['status']} | Score: ${data['actualScore']}',
        );
      }
    }
  }
}
