import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  
  final snapshot = await firestore.collectionGroup('matches').where('team1Name', isEqualTo: 'Afghanistan').get();
  for (var doc in snapshot.docs) {
    print('Match ID: ${doc.id}');
    print('Team 1: ${doc.data()['team1Name']} (ID: ${doc.data()['team1Id']})');
    print('Team 2: ${doc.data()['team2Name']} (ID: ${doc.data()['team2Id']})');
    print('Score: ${doc.data()['actualScore']}');
    print('---');
  }
}
