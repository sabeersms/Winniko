
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final id = 'mc';
  final doc = await FirebaseFirestore.instance.collection('discovered_tournaments').doc(id).get();
  
  if (doc.exists) {
    print('Tournament Found: ${doc.data()}');
  } else {
    print('Tournament NOT FOUND in discovered_tournaments');
  }
}
