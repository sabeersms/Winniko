import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore.collection('discovered_tournaments').get();

  print('Total discovered tournaments: ${snapshot.size}');
  for (var doc in snapshot.docs) {
    print('Tournament: ${doc.id}');
    print('  isMajor: ${doc.data()['isMajor']}');
    print('  sport: ${doc.data()['sport']}');
    print('  status: ${doc.data()['status']}');
  }
}
