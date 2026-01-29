import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time script to update all draft competitions to active status
/// Run this from a button in the app or via Firebase console
Future<void> updateDraftCompetitionsToActive(String organizerId) async {
  final firestore = FirebaseFirestore.instance;

  // Get all competitions by this organizer with status 'draft'
  final querySnapshot = await firestore
      .collection('competitions')
      .where('organizerId', isEqualTo: organizerId)
      .where('status', isEqualTo: 'draft')
      .get();

  print('Found ${querySnapshot.docs.length} draft competitions to update');

  // Update each one to 'active'
  final batch = firestore.batch();
  for (var doc in querySnapshot.docs) {
    batch.update(doc.reference, {'status': 'active'});
    print('Updating: ${doc.data()['name']}');
  }

  await batch.commit();
  print('✅ All competitions updated to active status!');
}
