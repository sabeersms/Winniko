import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final snapshot = await FirebaseFirestore.instance
      .collection('competitions')
      .where('leagueId', isNull: false)
      .get();

  print('Found ${snapshot.docs.length} competitions with leagueId');
  for (var doc in snapshot.docs) {
    print(
      'ID: ${doc.id}, Name: ${doc.get('name')}, LeagueId: ${doc.get('leagueId')}, Status: ${doc.get('status')}',
    );
  }
}
