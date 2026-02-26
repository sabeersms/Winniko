import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:winniko/services/firestore_service.dart';

/// One-off script to purge ALL hard copy matches from ALL official leagues.
/// Run this within the app or as a test if initialized.
Future<void> purgeAllHardCopies(BuildContext context) async {
  final firestore = Provider.of<FirestoreService>(context, listen: false);
  final db = FirebaseFirestore.instance;

  debugPrint('🧹 Starting global hard copy purge...');

  try {
    final leaguesSnap = await db.collection('official_leagues').get();
    debugPrint('Found ${leaguesSnap.docs.length} leagues.');

    for (var doc in leaguesSnap.docs) {
      final name = doc.data()['name'] ?? doc.id;
      debugPrint('Cleaning matches for: $name (${doc.id})...');
      await firestore.cleanHardCopy(doc.id);
    }

    debugPrint('✅ Global purge complete!');
  } catch (e) {
    debugPrint('❌ Purge failed: $e');
  }
}
