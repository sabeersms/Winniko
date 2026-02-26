import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:winniko/services/firestore_service.dart';

/// One-off script to purge ALL matches from ALL competitions using the T20 league.
/// This also clears the global hard and soft copies for the T20 league.
Future<void> purgeT20Matches(BuildContext context) async {
  final firestore = Provider.of<FirestoreService>(context, listen: false);
  final db = FirebaseFirestore.instance;
  final t20LeagueId = 'mens-t20-world-cup-2026';

  debugPrint('🧹 Starting deep T20 cleanup...');

  try {
    // 1. Clean Global Hard Copy
    debugPrint('Cleaning global hard copies for $t20LeagueId...');
    await firestore.cleanHardCopy(t20LeagueId);

    // 2. Clean Global Soft Copy
    debugPrint('Cleaning global soft copies for $t20LeagueId...');
    await firestore.cleanSoftCopy(t20LeagueId);

    // 3. Find all competitions using this league
    debugPrint('Searching for competitions using $t20LeagueId...');
    final compsSnap = await db
        .collection('competitions')
        .where('leagueId', isEqualTo: t20LeagueId)
        .get();

    debugPrint('Found ${compsSnap.docs.length} competitions to clean.');

    for (var doc in compsSnap.docs) {
      final name = doc.data()['name'] ?? doc.id;
      debugPrint('Cleaning matches for competition: $name (${doc.id})...');
      await firestore.deleteCompetitionMatches(doc.id);
    }

    debugPrint('✅ Deep T20 cleanup complete!');
  } catch (e) {
    debugPrint('❌ deep cleanup failed: $e');
  }
}
