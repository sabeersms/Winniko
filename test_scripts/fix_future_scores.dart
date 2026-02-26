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
  print('Checking upcoming and future matches in hard copy...');
  final now = DateTime.now();

  for (var doc in snap.docs) {
    final data = doc.data();
    final timeStr = data['scheduledTime'] != null 
        ? (data['scheduledTime'] as Timestamp).toDate() 
        : null;

    if (timeStr != null && timeStr.isAfter(now)) {
      if (data['actualScore'] != null || (data['status'] != 'upcoming' && data['status'] != 'scheduled')) {
        print('GHOST MATCH DETECTED IN HARD COPY!');
        print('Match ID: \${doc.id}');
        print('Teams: \${data['team1Name']} vs \${data['team2Name']}');
        print('Time: \$timeStr');
        print('Status: \${data['status']}');
        print('Score: \${data['actualScore']}');

        // Delete the dummy scores and status from Hard Copy
        await matchesRef.doc(doc.id).update({
          'actualScore': null,
          'status': 'upcoming',
          'winnerId': null,
        });
        print('FIXED!');
        print('---');
      }
    }
  }

  // Next, apply the same fix to competitions so they follow suit immediately
  final compsSnap = await FirebaseFirestore.instance.collection('competitions').where('leagueId', isEqualTo: leagueId).get();
  for (var comp in compsSnap.docs) {
    print('Checking competition \${comp.id}...');
    final compMatchesRef = FirebaseFirestore.instance.collection('competitions').doc(comp.id).collection('matches');
    final compMatchesSnap = await compMatchesRef.get();
    
    for (var doc in compMatchesSnap.docs) {
      final data = doc.data();
      final timeStr = data['scheduledTime'] != null 
          ? (data['scheduledTime'] as Timestamp).toDate() 
          : null;

      if (timeStr != null && timeStr.isAfter(now)) {
        if (data['actualScore'] != null || (data['status'] != 'upcoming' && data['status'] != 'scheduled')) {
          print('GHOST MATCH DETECTED IN COMPETITION \${comp.id}!');
          print('Match ID: \${doc.id}');
          print('Teams: \${data['team1Name']} vs \${data['team2Name']}');
          
          await compMatchesRef.doc(doc.id).update({
            'actualScore': null,
            'status': 'upcoming',
            'winnerId': null,
          });
          print('FIXED!');
        }
      }
    }
  }

  print('Done checking future matches.');
}
