import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../models/standing_model.dart';
import '../models/team_model.dart';
import '../models/prediction_model.dart';
import '../models/participant_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/official_tournament_model.dart';
import '../constants/app_constants.dart';
import 'fixture_generator.dart';
import 'teams_data_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Public getter for batch operations
  FirebaseFirestore get firestore => _firestore;

  FirestoreService() {
    _initializeSettings();
  }

  void _initializeSettings() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ========== CHAT ==========

  // Send message
  Future<void> sendMessage(String competitionId, MessageModel message) async {
    try {
      final batch = _firestore.batch();

      // 1. Add Message
      final messageRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('messages')
          .doc(); // Generate ID

      // Use the generated ID for the message model
      final messageWithId = message.copyWith(id: messageRef.id);

      batch.set(messageRef, messageWithId.toMap());

      // 2. Increment Message Count
      final competitionRef = _firestore
          .collection('competitions')
          .doc(competitionId);
      batch.update(competitionRef, {'messageCount': FieldValue.increment(1)});

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Get messages
  Stream<List<MessageModel>> getMessages(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50) // Optimize: Load only last 50 messages
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Mark competition message as read
  Future<void> markMessageAsRead(
    String competitionId,
    String messageId,
    String userId,
  ) async {
    // Legacy support: We still mark individual messages as read for now
    // but primary mechanism is now the participant counter.
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('messages')
          .doc(messageId)
          .update({
            'readBy': FieldValue.arrayUnion([userId]),
          });
    } catch (e) {
      debugPrint('Error marking message read: $e');
    }
  }

  // Mark all competition messages as read for a user
  Future<void> markCompetitionChatRead(
    String competitionId,
    String userId,
  ) async {
    try {
      // 1. Get current competition message count
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (!compDoc.exists) return;

      final messageCount = compDoc.data()?['messageCount'] ?? 0;

      // 2. Update participant's last read count
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .update({'lastReadMessageCount': messageCount});
    } catch (e) {
      debugPrint('Error marking competition chat read: $e');
    }
  }

  // Typing Indicators
  Future<void> setTypingStatus(
    String competitionId,
    String userId,
    String userName,
    bool isTyping,
  ) async {
    try {
      final docRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('typing')
          .doc(userId);

      if (isTyping) {
        await docRef.set({
          'userName': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.delete();
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  Stream<List<String>> getTypingUsers(
    String competitionId,
    String currentUserId,
  ) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('typing')
        .where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(seconds: 10)),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.id != currentUserId)
              .map((doc) => doc.data()['userName'] as String)
              .toList(),
        );
  }

  // Pin Competition Message
  Future<void> pinCompetitionMessage({
    required String competitionId,
    required String messageId,
    required bool isPinned,
  }) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': isPinned});
    } catch (e) {
      throw Exception('Failed to pin message: ${e.toString()}');
    }
  }

  // Delete Competition Message
  Future<void> deleteCompetitionMessage(
    String competitionId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  // ========== DIRECT MESSAGING ==========

  // Send Direct Message
  Future<void> sendDirectMessage({
    required String competitionId,
    required String participantId,
    required MessageModel message,
    required String participantName, // Need name for creating chat ref
  }) async {
    try {
      final chatRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId);

      // 1. Add Message to Subcollection
      await chatRef.collection('messages').add(message.toMap());

      // 2. Update Chat Metadata (Create if not exists)
      final bool isOrganizerSender = message.isOrganizer;

      // Use set with merge to handle creation or update
      await chatRef.set({
        'competitionId': competitionId,
        'participantId': participantId,
        'participantName': participantName, // Update name in case changed
        'lastMessage': message.imageUrl != null ? '📷 Photo' : message.text,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
        'participantUnreadCount': FieldValue.increment(
          isOrganizerSender ? 1 : 0,
        ),
        'organizerUnreadCount': FieldValue.increment(isOrganizerSender ? 0 : 1),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send direct message: ${e.toString()}');
    }
  }

  // Pin Direct Message
  Future<void> pinDirectMessage({
    required String competitionId,
    required String participantId,
    required String messageId,
    required bool isPinned,
  }) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId)
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': isPinned});
    } catch (e) {
      throw Exception('Failed to pin message: ${e.toString()}');
    }
  }

  // Delete Direct Message
  Future<void> deleteDirectMessage({
    required String competitionId,
    required String participantId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  // Delete Direct Chat
  Future<void> deleteDirectChat({
    required String competitionId,
    required String participantId,
  }) async {
    try {
      final chatRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId);

      // 1. Delete all messages first (Firestore requires manual deletion of subcollections)
      final messages = await chatRef.collection('messages').get();
      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // 2. Delete the chat metadata
      batch.delete(chatRef);

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete chat: ${e.toString()}');
    }
  }

  // Get Direct Messages Stream
  Stream<List<MessageModel>> getDirectMessages(
    String competitionId,
    String participantId,
  ) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('direct_chats')
        .doc(participantId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Mark direct message as read
  Future<void> markDirectMessageAsRead(
    String competitionId,
    String participantId,
    String messageId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId)
          .collection('messages')
          .doc(messageId)
          .update({
            'readBy': FieldValue.arrayUnion([userId]),
          });
    } catch (e) {
      debugPrint('Error marking direct message read: $e');
    }
  }

  // Direct Typing Status
  Future<void> setDirectTypingStatus(
    String competitionId,
    String participantId,
    String userId,
    String userName,
    bool isTyping,
  ) async {
    try {
      final docRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId)
          .collection('typing')
          .doc(userId);

      if (isTyping) {
        await docRef.set({
          'userName': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.delete();
      }
    } catch (e) {
      debugPrint('Error setting direct typing status: $e');
    }
  }

  Stream<List<String>> getDirectTypingUsers(
    String competitionId,
    String participantId,
    String currentUserId,
  ) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('direct_chats')
        .doc(participantId)
        .collection('typing')
        .where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(seconds: 10)),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.id != currentUserId)
              .map((doc) => doc.data()['userName'] as String)
              .toList(),
        );
  }

  // Get All Direct Chats (For Organizer)

  Stream<List<ChatModel>> getOrganizerChats(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('direct_chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ChatModel.fromSnapshot(doc)).toList(),
        );
  }

  // Get Single Chat metadata (For Participant)
  Stream<ChatModel?> getMyChat(String competitionId, String myUserId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('direct_chats')
        .doc(myUserId)
        .snapshots()
        .map((doc) {
          if (doc.exists) return ChatModel.fromSnapshot(doc);
          return null;
        });
  }

  // Mark as Read
  Future<void> markChatRead({
    required String competitionId,
    required String participantId,
    required bool isOrganizerReading,
  }) async {
    try {
      final chatRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('direct_chats')
          .doc(participantId);

      Map<String, dynamic> updateData = {};

      if (isOrganizerReading) {
        updateData['organizerUnreadCount'] = 0;
      } else {
        updateData['participantUnreadCount'] = 0;
      }

      await chatRef.update(updateData);
    } catch (e) {
      // Ignore if document doesn't exist yet (no chat started)
      debugPrint('Error marking read: $e');
    }
  }

  // Get total unread count for organizer across all chats in a competition
  Stream<int> getOrganizerUnreadCount(String competitionId) {
    return getOrganizerChats(competitionId).map((chats) {
      return chats.fold(0, (total, chat) => total + chat.organizerUnreadCount);
    });
  }

  // ========== COMPETITIONS ==========

  // Leave competition
  Future<void> leaveCompetition(String competitionId, String userId) async {
    try {
      // 1. Delete participant document
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .delete();

      // 2. Decrement participant count
      // NOTE: This often fails in official tournaments due to restricted update rules
      // (only organizers or master admins can update the main doc).
      // We wrap this in a separate try-catch so leaving still succeeds even if count update is denied.
      try {
        await _firestore.collection('competitions').doc(competitionId).update({
          'participantCount': FieldValue.increment(-1),
          'participantsCount': FieldValue.increment(-1),
        });
        debugPrint('✅ participantCount decremented successfully.');
      } catch (e) {
        debugPrint(
          '🛡️ Permission Warning: Could not decrement participantCount for $competitionId: $e',
        );
        debugPrint(
          'This is expected for some restricted competitions. The participant record has been removed successfully.',
        );
      }
    } catch (e) {
      throw Exception('Failed to leave competition: ${e.toString()}');
    }
  }

  // Get participant
  Future<ParticipantModel?> getParticipant(
    String competitionId,
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .get();

      if (doc.exists) {
        return ParticipantModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get participant: ${e.toString()}');
    }
  }

  // Create competition
  Future<String> createCompetition(
    CompetitionModel competition, {
    String? organizerPhotoUrl,
  }) async {
    try {
      String joinCode = '';
      bool isUnique = false;
      int attempts = 0;

      // Retry up to 5 times to generate a unique code
      while (!isUnique && attempts < 5) {
        joinCode = _generateJoinCode();

        final existing = await _firestore
            .collection('competitions')
            .where('joinCode', isEqualTo: joinCode)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) {
          isUnique = true;
        }
        attempts++;
      }

      if (!isUnique) {
        throw Exception(
          'Failed to generate unique join code. Please try again.',
        );
      }

      // Create a new map with the joinCode
      final competitionData = competition.toMap();
      competitionData['joinCode'] = joinCode;

      await _firestore
          .collection('competitions')
          .doc(competition.id)
          .set(competitionData);

      // Auto-join organizer as participant
      final participant = ParticipantModel(
        userId: competition.organizerId,
        userName: competition.organizerName,
        phoneNumber: null, // Optional, can be updated later
        photoUrl: organizerPhotoUrl,
        competitionId: competition.id,
        joinedAt: DateTime.now(),
      );
      await joinCompetition(competition.id, participant);

      return competition.id;
    } catch (e) {
      throw Exception('Failed to create competition: ${e.toString()}');
    }
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Get competition by ID
  Future<CompetitionModel?> getCompetition(String competitionId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (doc.exists) {
        return CompetitionModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get competition: ${e.toString()}');
    }
  }

  // Get competition by Join Code (for templates)
  Future<CompetitionModel?> getCompetitionByJoinCode(String joinCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('competitions')
          .where('joinCode', isEqualTo: joinCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return CompetitionModel.fromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find competition definition: ${e.toString()}');
    }
  }

  // Ensure competition has a join code (Backfill for old data)
  Future<String> ensureJoinCode(String competitionId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();

      if (!doc.exists) throw Exception('Competition not found');

      final data = doc.data() as Map<String, dynamic>;
      if (data['joinCode'] != null && (data['joinCode'] as String).isNotEmpty) {
        return data['joinCode'];
      }

      // Generate and update
      String newCode = _generateJoinCode();
      await _firestore.collection('competitions').doc(competitionId).update({
        'joinCode': newCode,
      });

      return newCode;
    } catch (e) {
      throw Exception('Failed to ensure join code: ${e.toString()}');
    }
  }

  // Get all competitions
  Stream<List<CompetitionModel>> getAllCompetitions() {
    debugPrint('🏠 Setting up HOME stream for all competitions');
    return _firestore
        .collection('competitions')
        .where('status', isEqualTo: 'active')
        .orderBy('participantCount', descending: true)
        .limit(50) // Increased limit to ensure new/smaller competitions show up
        .snapshots()
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getAllCompetitions: $e');
          }
        })
        .map((snapshot) {
          debugPrint(
            '🏠 HOME: Firestore snapshot received: ${snapshot.docs.length} docs',
          );
          final allComps = snapshot.docs
              .map((doc) => CompetitionModel.fromSnapshot(doc))
              .toList();
          debugPrint(
            '🏠 HOME: All competitions: ${allComps.map((c) => '${c.name} (deleted: ${c.deletedAt != null}, status: ${c.status})').join(", ")}',
          );

          final filtered = allComps
              .where((comp) => comp.deletedAt == null)
              .toList();
          debugPrint(
            '🏠 HOME: Filtered (active, non-deleted): ${filtered.map((c) => c.name).join(", ")}',
          );
          return filtered;
        });
  }

  // Get competitions by organizer (Excluding deleted)
  Stream<List<CompetitionModel>> getCompetitionsByOrganizer(
    String organizerId,
  ) {
    debugPrint('🔍 Setting up stream for organizerId: $organizerId');
    return _firestore
        .collection('competitions')
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getCompetitionsByOrganizer: $e');
          }
        })
        .map((snapshot) {
          debugPrint(
            '📦 Firestore snapshot received: ${snapshot.docs.length} docs',
          );
          final allComps = snapshot.docs
              .map((doc) => CompetitionModel.fromSnapshot(doc))
              .toList();
          debugPrint(
            '📋 All competitions: ${allComps.map((c) => '${c.name} (deleted: ${c.deletedAt != null})').join(", ")}',
          );

          final filtered = allComps
              .where((comp) => comp.deletedAt == null)
              .toList();
          debugPrint(
            '✅ Filtered (non-deleted): ${filtered.map((c) => c.name).join(", ")}',
          );
          return filtered;
        });
  }

  // Get DELETED competitions by organizer
  Stream<List<CompetitionModel>> getDeletedCompetitions(String organizerId) {
    return _firestore
        .collection('competitions')
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getDeletedCompetitions: $e');
          }
        })
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CompetitionModel.fromSnapshot(doc))
                  .where((comp) => comp.deletedAt != null)
                  .toList()
                ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!)),
        );
  }

  // Update competition
  Future<void> updateCompetition(CompetitionModel competition) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competition.id)
          .update(competition.toMap());
    } catch (e) {
      throw Exception('Failed to update competition: ${e.toString()}');
    }
  }

  /// Recalculates the actual number of participants in a competition
  /// and updates the counter on the main document.
  Future<int> recountParticipants(String competitionId) async {
    try {
      final participantsSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .get();

      int actualCount = participantsSnapshot.docs.length;

      await _firestore.collection('competitions').doc(competitionId).update({
        'participantCount': actualCount,
        'participantsCount': actualCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Recounted participants for $competitionId: $actualCount');
      return actualCount;
    } catch (e) {
      debugPrint('❌ Error recounting participants: $e');
      return -1;
    }
  }

  /// Syncs scores for official tournaments (e.g. PL, World Cup)
  Future<void> syncOfficialTournamentScores({
    required String competitionId,
    required String leagueId,
  }) async {
    try {
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (!compDoc.exists) return;

      // Validate League ID from DB (Source of Truth) to prevent stale UI syncs
      // If Reset cleaned the leagueId, we must stop sync immediately.
      final dbLeagueId = compDoc.data()?['leagueId'] as String?;
      if (dbLeagueId == null || dbLeagueId.isEmpty) {
        debugPrint(
          'Sync aborted: Competition $competitionId has no leagueId (Disconnected)',
        );
        return;
      }

      // Throttling: Max once every 15 minutes (User only wants finished scores)
      final lastSync = compDoc.data()?['lastSyncTime'] as Timestamp?;
      if (lastSync != null) {
        final now = DateTime.now();
        if (now.difference(lastSync.toDate()).inMinutes < 15) {
          debugPrint(
            'Sync throttled for $competitionId (Next sync in ${15 - now.difference(lastSync.toDate()).inMinutes} mins)',
          );
          return;
        }
      }

      // Fetch teams (needed for mapping in getLatestScores)
      final teams = await getTeams(competitionId).first;

      // Fetch latest scores from the VERIFIED HARD COPY in Firebase
      // (Strict rule: No API calls outside of master verification)
      final hardCopySnap = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .get();

      final externalMatches = hardCopySnap.docs
          .map((doc) => MatchModel.fromSnapshot(doc))
          .toList();

      // Fetch internal matches
      final internalMatches = await getMatches(competitionId).first;

      bool anyUpdate = false;
      final batch = _firestore.batch();

      // 🧹 PRE-SYNC DEDUPLICATION: Remove duplicates within the competition matches
      final Set<String> seenMatchKeys = {};
      final List<MatchModel> uniqueInternalMatches = [];
      for (var m in internalMatches) {
        final key = _generateMatchKey(m);
        if (seenMatchKeys.contains(key)) {
          debugPrint(
            '🧹 SYNC: Found duplicate internal match ${m.id} ($key), cleaning up...',
          );
          batch.delete(
            _firestore
                .collection('competitions')
                .doc(competitionId)
                .collection('matches')
                .doc(m.id),
          );
          anyUpdate = true;
        } else {
          seenMatchKeys.add(key);
          uniqueInternalMatches.add(m);
        }
      }

      if (externalMatches.isEmpty) {
        // 🧹 SYNC CLEANUP: If official source is empty, and it was globally cleaned
        final leagueDoc = await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .get();
        final leagueLastCleanedAt =
            (leagueDoc.data()?['lastCleanedAt'] as Timestamp?)?.toDate();

        if (leagueLastCleanedAt != null && internalMatches.isNotEmpty) {
          debugPrint(
            '🧹 SYNC: Official source for $leagueId was cleaned at $leagueLastCleanedAt. Cleaning competition $competitionId.',
          );
          await deleteCompetitionMatches(competitionId);
        }
        return;
      }

      debugPrint(
        'Sync: Fetched ${externalMatches.length} external matches, ${internalMatches.length} internal matches.',
      );

      final Map<String, String> teamNameToId = {};
      for (var t in teams) {
        final aliases = TeamsDataService.getTeamAliases(t.name);
        for (var alias in aliases) {
          teamNameToId[alias.toLowerCase().trim()] = t.id;
        }
      }

      // Track processed internal match IDs to prevent double-matching
      final Set<String> processedInternalIds = {};

      for (var ext in externalMatches) {
        // Find internal match
        int intMatchIndex = -1;
        bool isReverse = false;

        // PRIORITY 1: Match by Match Number (Strongest Link)
        if (ext.matchNumber != null) {
          intMatchIndex = uniqueInternalMatches.indexWhere(
            (m) =>
                m.matchNumber == ext.matchNumber &&
                !processedInternalIds.contains(m.id),
          );
        }

        // PRIORITY 2: Match by Teams (Unique Pairing) - Bidirectional
        if (intMatchIndex == -1) {
          intMatchIndex = uniqueInternalMatches.indexWhere((m) {
            return !processedInternalIds.contains(m.id) &&
                (m.team1Id == ext.team1Id && m.team2Id == ext.team2Id);
          });
        }

        if (intMatchIndex == -1) {
          intMatchIndex = uniqueInternalMatches.indexWhere((m) {
            return !processedInternalIds.contains(m.id) &&
                (m.team1Id == ext.team2Id && m.team2Id == ext.team1Id);
          });
          if (intMatchIndex != -1) {
            isReverse = true;
          }
        }

        // PRIORITY 3: Match by Team Names + Date (Fallback for cross-ID matching)
        if (intMatchIndex == -1) {
          intMatchIndex = uniqueInternalMatches.indexWhere((m) {
            if (processedInternalIds.contains(m.id)) return false;

            final teamsMatch =
                TeamsDataService.areTeamNamesEquivalent(
                      m.team1Name,
                      ext.team1Name,
                    ) &&
                    TeamsDataService.areTeamNamesEquivalent(
                      m.team2Name,
                      ext.team2Name,
                    ) ||
                TeamsDataService.areTeamNamesEquivalent(
                      m.team1Name,
                      ext.team2Name,
                    ) &&
                    TeamsDataService.areTeamNamesEquivalent(
                      m.team2Name,
                      ext.team1Name,
                    );

            if (!teamsMatch) return false;
            return m.scheduledTime.difference(ext.scheduledTime).inHours.abs() <
                24;
          });
          if (intMatchIndex != -1) {
            // Check if teams are reversed
            final m = uniqueInternalMatches[intMatchIndex];
            isReverse = !TeamsDataService.areTeamNamesEquivalent(
              m.team1Name,
              ext.team1Name,
            );
          }
        }

        if (intMatchIndex == -1) {
          // ➕ RE-POPULATION LOGIC: If match is missing but VERIFIED in source, add it back.
          final bool isExtVerified = ext.actualScore?['verified'] == true;
          if (isExtVerified) {
            final t1Id =
                teamNameToId[ext.team1Name.toLowerCase().trim()] ?? ext.team1Id;
            final t2Id =
                teamNameToId[ext.team2Name.toLowerCase().trim()] ?? ext.team2Id;

            // 🧹 DELETE any existing duplicates by name + date before adding
            final dupes = uniqueInternalMatches.where((m) {
              if (processedInternalIds.contains(m.id)) return false;

              final teamsMatch =
                  TeamsDataService.areTeamNamesEquivalent(
                        m.team1Name,
                        ext.team1Name,
                      ) &&
                      TeamsDataService.areTeamNamesEquivalent(
                        m.team2Name,
                        ext.team2Name,
                      ) ||
                  TeamsDataService.areTeamNamesEquivalent(
                        m.team1Name,
                        ext.team2Name,
                      ) &&
                      TeamsDataService.areTeamNamesEquivalent(
                        m.team2Name,
                        ext.team1Name,
                      );

              if (!teamsMatch) return false;
              return m.scheduledTime
                      .difference(ext.scheduledTime)
                      .inHours
                      .abs() <
                  48;
            }).toList();

            for (final dupe in dupes) {
              debugPrint(
                '🧹 DEDUP: Deleting duplicate ${dupe.team1Name} vs ${dupe.team2Name} (${dupe.id}) before re-population',
              );
              batch.delete(
                _firestore
                    .collection('competitions')
                    .doc(competitionId)
                    .collection('matches')
                    .doc(dupe.id),
              );
              processedInternalIds.add(dupe.id);
            }

            final newMatchId = _firestore
                .collection('competitions')
                .doc(competitionId)
                .collection('matches')
                .doc()
                .id;

            final matchToAdd = ext.copyWith(
              id: newMatchId,
              competitionId: competitionId,
              team1Id: t1Id,
              team2Id: t2Id,
            );

            batch.set(
              _firestore
                  .collection('competitions')
                  .doc(competitionId)
                  .collection('matches')
                  .doc(newMatchId),
              matchToAdd.toMap(),
            );
            anyUpdate = true;
          }
          continue;
        }

        final intMatch = uniqueInternalMatches[intMatchIndex];
        processedInternalIds.add(intMatch.id);

        // 🛡️ PROTECTION: Skip verified or manually scored matches entirely
        final bool isIntVerified =
            intMatch.actualScore?['verified'] == true ||
            intMatch.actualScore?['manuallyScored'] == true;
        if (isIntVerified) {
          debugPrint(
            '🛡️ SYNC LOOP 1 PROTECTED: Skipping ${intMatch.team1Name} vs ${intMatch.team2Name} (verified/manually scored)',
          );
          continue;
        }

        // Prepare correct external score based on direction
        Map<String, dynamic>? extScore = ext.actualScore;
        if (isReverse && extScore != null) {
          extScore = {
            'team1': extScore['team2'],
            'team2': extScore['team1'],
            'winnerId': extScore['winnerId'],
          };
        }

        bool needsUpdate = false;
        Map<String, dynamic> updates = {};

        // 1. Check Score/Status Changes
        bool statusChanged = intMatch.status != ext.status;
        bool scoreChanged = false;

        if (extScore != null) {
          if (intMatch.actualScore == null) {
            scoreChanged = true;
          } else {
            final m1 = intMatch.actualScore!;
            final m2 = extScore;
            if (m1.toString() != m2.toString()) {
              scoreChanged = true;
            }
          }
        }

        if (statusChanged || scoreChanged) {
          // 🛡️ PROTECTION: Do NOT update status/score in a batch update (Loop 1).
          // Leave it to Loop 2 which calls updateMatchScore (Last line of defense).
          needsUpdate = false;
        }

        // 2. Check Schedule Time Changes
        // Allow for small differences (e.g. seconds)
        if (intMatch.scheduledTime
                .difference(ext.scheduledTime)
                .inMinutes
                .abs() >
            5) {
          updates['scheduledTime'] = Timestamp.fromDate(ext.scheduledTime);
          needsUpdate = true;
        }

        // 3. Apply Update
        if (needsUpdate) {
          anyUpdate = true;
          final docRef = _firestore
              .collection('competitions')
              .doc(competitionId)
              .collection('matches')
              .doc(intMatch.id);

          batch.update(docRef, updates);
        }
      }

      if (anyUpdate) {
        await batch.commit();
      }

      // Re-loop for critical updates (Score/Status)
      for (var ext in externalMatches) {
        // Find match again using improved logic
        MatchModel? intMatch;
        bool isReverse = false;

        // Try Match Number
        if (ext.matchNumber != null) {
          try {
            intMatch = uniqueInternalMatches.firstWhere(
              (m) => m.matchNumber == ext.matchNumber,
            );
          } catch (_) {}
        }

        // Try Team IDs
        if (intMatch == null) {
          try {
            intMatch = uniqueInternalMatches.firstWhere(
              (m) => m.team1Id == ext.team1Id && m.team2Id == ext.team2Id,
            );
          } catch (_) {
            try {
              intMatch = uniqueInternalMatches.firstWhere(
                (m) => m.team1Id == ext.team2Id && m.team2Id == ext.team1Id,
              );
              isReverse = true;
            } catch (_) {}
          }
        }

        // Try Team Names + Date
        if (intMatch == null) {
          try {
            intMatch = uniqueInternalMatches.firstWhere((m) {
              final teamsMatch =
                  TeamsDataService.areTeamNamesEquivalent(
                        m.team1Name,
                        ext.team1Name,
                      ) &&
                      TeamsDataService.areTeamNamesEquivalent(
                        m.team2Name,
                        ext.team2Name,
                      ) ||
                  TeamsDataService.areTeamNamesEquivalent(
                        m.team1Name,
                        ext.team2Name,
                      ) &&
                      TeamsDataService.areTeamNamesEquivalent(
                        m.team2Name,
                        ext.team1Name,
                      );

              if (!teamsMatch) return false;
              return m.scheduledTime
                      .difference(ext.scheduledTime)
                      .inHours
                      .abs() <
                  24;
            });
            isReverse = !TeamsDataService.areTeamNamesEquivalent(
              intMatch.team1Name,
              ext.team1Name,
            );
          } catch (_) {}
        }

        if (intMatch == null) continue;

        // 🛡️ PROTECTION: Skip verified or manually scored matches entirely
        final bool isIntVerified =
            intMatch.actualScore?['verified'] == true ||
            intMatch.actualScore?['manuallyScored'] == true;
        if (isIntVerified) {
          debugPrint(
            '🛡️ SYNC LOOP 2 PROTECTED: Skipping ${intMatch.team1Name} vs ${intMatch.team2Name} (verified/manually scored)',
          );
          continue;
        }

        // Prevent Simulation from overwriting Manual/Real data
        final isExtSim = ext.actualScore?['isSimulated'] == true;
        final isIntSim = intMatch.actualScore?['isSimulated'] == true;
        // If we have data, and it's NOT simulated, assume it's Manual/Real
        final isIntManual = intMatch.actualScore != null && !isIntSim;

        if (isExtSim && isIntManual) {
          continue;
        }

        // Prepare correct external score
        Map<String, dynamic>? extScore = ext.actualScore;
        if (isReverse && extScore != null) {
          extScore = {
            'team1': extScore['team2'],
            'team2': extScore['team1'],
            'winnerId': extScore['winnerId'],
          };
        }

        // Check Status/Score
        bool statusChanged = intMatch.status != ext.status;
        bool scoreChanged = false;
        if (extScore != null) {
          if (intMatch.actualScore == null) {
            scoreChanged = true;
          } else {
            // Generic check for any score change (handling cricket keys too)
            if (intMatch.actualScore.toString() != extScore.toString()) {
              scoreChanged = true;
            }
          }
        } else if (intMatch.actualScore != null) {
          // 🛡️ ZOMBIE SCORE FIX: Only clear internal score if it is NOT verified/manually scored.
          // (Already guarded above, but double-check for safety)
          scoreChanged = true;
          extScore = {};
        }

        if (statusChanged || scoreChanged) {
          await updateMatchScore(
            competitionId,
            intMatch.id,
            extScore ?? {'team1': 0, 'team2': 0},
            ext.status,
            oldScore: intMatch.actualScore,
          );
          debugPrint(
            'SYNC SUCCESS: ✅ Update Committed for ${intMatch.team1Name} vs ${intMatch.team2Name} (Status: ${ext.status})',
          );
        }
      }
      // Update lastSyncTime
      await _firestore.collection('competitions').doc(competitionId).update({
        'lastSyncTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Sync error for $competitionId: $e');
    }
  }

  // Helper to get service (to avoid direct import cycle if any, though likely fine)
  // Actually, I'll just import it at the top.

  // Soft Delete competition (Move to Recycle Bin)
  Future<void> softDeleteCompetition(String competitionId) async {
    try {
      await _firestore.collection('competitions').doc(competitionId).update({
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to delete competition: ${e.toString()}');
    }
  }

  // Restore competition from Recycle Bin
  Future<void> restoreCompetition(String competitionId) async {
    try {
      await _firestore.collection('competitions').doc(competitionId).update({
        'deletedAt': null,
      });
    } catch (e) {
      throw Exception('Failed to restore competition: ${e.toString()}');
    }
  }

  // Permanently Delete competition
  Future<void> permanentDeleteCompetition(String competitionId) async {
    try {
      final compRef = _firestore.collection('competitions').doc(competitionId);

      // 1. Delete standard subcollections
      await _deleteCollection(compRef.collection('teams'));
      await _deleteCollection(compRef.collection('matches'));
      await _deleteCollection(compRef.collection('participants'));
      await _deleteCollection(compRef.collection('messages'));
      await _deleteCollection(compRef.collection('typing'));

      // 2. Delete direct_chats (which have their own subcollections)
      final directChats = await compRef.collection('direct_chats').get();
      for (var chatDoc in directChats.docs) {
        await _deleteCollection(chatDoc.reference.collection('messages'));
        await _deleteCollection(chatDoc.reference.collection('typing'));
        await chatDoc.reference.delete();
      }

      // 3. Delete the main document
      await compRef.delete();
    } catch (e) {
      throw Exception(
        'Failed to permanently delete competition: ${e.toString()}',
      );
    }
  }

  // Helper to delete all documents in a collection/subcollection
  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshots = await collection.get();
    if (snapshots.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ========== MATCHES ==========

  // Add match to competition
  Future<String> addMatch(MatchModel match) async {
    try {
      // Check if competition is draft and activate it
      await _checkAndActivateCompetition(match.competitionId);

      DocumentReference docRef = await _firestore
          .collection('competitions')
          .doc(match.competitionId)
          .collection('matches')
          .add(match.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add match: ${e.toString()}');
    }
  }

  // Activate competition if it is in draft mode
  Future<void> _checkAndActivateCompetition(String competitionId) async {
    try {
      final doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (doc.exists && doc.data()?['status'] == 'draft') {
        await _firestore.collection('competitions').doc(competitionId).update({
          'status': 'active',
        });
      }
    } catch (e) {
      debugPrint('Error activating competition: $e');
    }
  }

  // Create matches in batch
  Future<void> createBatchMatches(List<MatchModel> matches) async {
    try {
      final batch = _firestore.batch();

      if (matches.isNotEmpty) {
        await _checkAndActivateCompetition(matches.first.competitionId);
      }

      for (var match in matches) {
        final docRef = _firestore
            .collection('competitions')
            .doc(match.competitionId)
            .collection('matches')
            .doc(match.id);
        batch.set(docRef, match.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create matches in batch: ${e.toString()}');
    }
  }

  // Generate Next Round
  Future<void> generateNextRound(
    String competitionId,
    List<MatchModel> finishedMatches,
  ) async {
    try {
      // 1. Get max match number
      int startMatchNumber = 1;
      final matchQuery = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .orderBy('matchNumber', descending: true)
          .limit(1)
          .get();

      if (matchQuery.docs.isNotEmpty) {
        final data = matchQuery.docs.first.data();
        if (data['matchNumber'] != null) {
          startMatchNumber = (data['matchNumber'] as int) + 1;
        } else {
          // Fallback: if existing matches have no numbers, we might want to count them?
          // Or just start from 1. If we start from 1, we might duplicate logical numbers if user manually added 1.
          // But existing ones are null, so no collision on valid numbers.
          // Ideally we should count how many matches exist.
          final countQuery = await _firestore
              .collection('competitions')
              .doc(competitionId)
              .collection('matches')
              .count()
              .get();
          startMatchNumber = (countQuery.count ?? 0) + 1;
        }
      }

      final nextRoundMatches = FixtureGenerator.generateNextKnockoutRound(
        competitionId: competitionId,
        previousRoundMatches: finishedMatches,
        startMatchNumber: startMatchNumber,
      );
      if (nextRoundMatches.isNotEmpty) {
        await createBatchMatches(nextRoundMatches);
      }
    } catch (e) {
      throw Exception('Failed to generate next round: ${e.toString()}');
    }
  }

  // Delete match
  Future<void> deleteMatch(String competitionId, String matchId) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete match: ${e.toString()}');
    }
  }

  // Get matches for competition
  Stream<List<MatchModel>> getMatches(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('matches')
        .orderBy('scheduledTime')
        .snapshots()
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getMatches: $e');
          }
        })
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MatchModel.fromSnapshot(doc)).toList(),
        );
  }

  // Get single match
  Future<MatchModel?> getMatch(String competitionId, String matchId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .get();
      if (doc.exists) {
        return MatchModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get match: ${e.toString()}');
    }
  }

  // Update match (for results)
  Future<void> updateMatch(MatchModel match) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(match.competitionId)
          .collection('matches')
          .doc(match.id)
          .update(match.toMap());
    } catch (e) {
      throw Exception('Failed to update match: ${e.toString()}');
    }
  }

  // Update match score and status
  Future<void> updateMatchScore(
    String competitionId,
    String matchId,
    Map<String, dynamic> score,
    String status, {
    Map<String, dynamic>? oldScore,
  }) async {
    try {
      // 🛡️ LAST-LINE-OF-DEFENSE: Read current Firestore doc before writing.
      // If the existing score is verified or manuallyScored, and the incoming
      // score is NOT (i.e., it's an API/automated update), block the write.
      final bool incomingIsProtected =
          score['verified'] == true || score['manuallyScored'] == true;
      if (!incomingIsProtected) {
        final currentDoc = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('matches')
            .doc(matchId)
            .get();
        if (currentDoc.exists) {
          final currentData = currentDoc.data();
          final currentScore =
              currentData?['actualScore'] as Map<String, dynamic>?;
          final bool currentIsProtected =
              currentScore?['verified'] == true ||
              currentScore?['manuallyScored'] == true;
          if (currentIsProtected) {
            debugPrint(
              '🛡️ updateMatchScore BLOCKED: Match $matchId has a verified/manually scored score. Refusing API overwrite.',
            );
            return; // Do NOT overwrite
          }
        }
      }

      // Update the match in the competition
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .update({
            'actualScore': score.isEmpty ? null : score,
            'status': status,
          });

      // 🌍 GLOBAL PROTECTION: If manually scored OR verified, save to official_leagues
      if (score.isNotEmpty &&
          (score['manuallyScored'] == true || score['verified'] == true)) {
        await _saveManualScoreToOfficialLeagues(
          competitionId,
          matchId,
          score,
          status,
        );
      }

      final bool isVerified =
          score['verified'] == true || score['manuallyScored'] == true;
      if (_isMatchFinished(status) ||
          status == AppConstants.matchStatusLive ||
          status == AppConstants.matchStatusProgressing ||
          isVerified) {
        await recalculateStandings(competitionId);
        // Only process predictions when the match is actually done or verified
        // (not just progressing/live, unless it is also verified)
        if (_isMatchFinished(status) || isVerified) {
          await _processPredictions(
            competitionId,
            matchId,
            score,
            oldScore: oldScore,
          );
        }
      } else if (status == AppConstants.matchStatusScheduled ||
          status == AppConstants.matchStatusUpcoming) {
        // REVERT points if match was previously completed/live
        if (oldScore != null) {
          await _revertPredictions(competitionId, matchId);
          await recalculateStandings(competitionId);
        }

        // 🌍 GLOBAL PROTECTION: Remove from official_leagues if reset
        await _removeManualScoreFromOfficialLeagues(competitionId, matchId);
      }
    } catch (e) {
      throw Exception('Failed to update match score: ${e.toString()}');
    }
  }

  /// Updates multiple match scores in one process with protection checks
  Future<int> updateMatchScoreBulk(
    String competitionId,
    List<MatchModel> matchUpdates,
  ) async {
    try {
      final batch = _firestore.batch();
      int updateCount = 0;
      final Set<String> processedMatchIds = {};

      for (var update in matchUpdates) {
        if (processedMatchIds.contains(update.id)) continue;
        processedMatchIds.add(update.id);

        final docRef = _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('matches')
            .doc(update.id);

        // 🛡️ LAST-LINE-OF-DEFENSE: Fetch doc for protection check
        final currentDoc = await docRef.get();
        if (currentDoc.exists) {
          final currentData = currentDoc.data();
          final currentScore =
              currentData?['actualScore'] as Map<String, dynamic>?;
          final bool currentIsProtected =
              currentScore?['verified'] == true ||
              currentScore?['manuallyScored'] == true;

          // If the incoming update is NOT protected but the current one IS, skip it.
          final bool incomingIsProtected =
              update.actualScore?['verified'] == true ||
              update.actualScore?['manuallyScored'] == true;

          if (currentIsProtected && !incomingIsProtected) {
            debugPrint(
              '🛡️ Bulk update BLOCKED: Match ${update.id} is verified. Refusing API overwrite.',
            );
            continue;
          }
        }

        batch.update(docRef, {
          'actualScore': (update.actualScore?.isEmpty ?? true)
              ? null
              : update.actualScore,
          'status': update.status,
          'winnerId': update.winnerId,
          'scheduledTime': Timestamp.fromDate(update.scheduledTime),
        });
        updateCount++;
      }

      if (updateCount > 0) {
        await batch.commit();
        await recalculateStandings(competitionId);

        // Process predictions for each match that was successfully updated in this batch
        for (var update in matchUpdates) {
          if (update.actualScore != null &&
              (_isMatchFinished(update.status) ||
                  update.status == AppConstants.matchStatusLive)) {
            await processPredictionsPublic(
              competitionId,
              update.id,
              update.actualScore!,
            );
          }
        }
      }
      return updateCount;
    } catch (e) {
      throw Exception('Failed to update batch scores: ${e.toString()}');
    }
  }

  /// Saves a manually scored match to the official_leagues collection for global protection
  Future<void> _saveManualScoreToOfficialLeagues(
    String competitionId,
    String matchId,
    Map<String, dynamic> score,
    String status,
  ) async {
    try {
      // 1. Get the competition to find the leagueId
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();

      if (!compDoc.exists) return;

      final leagueId = compDoc.data()?['leagueId'] as String?;
      if (leagueId == null || leagueId.isEmpty) {
        debugPrint(
          '⚠️ Cannot save to official_leagues: No leagueId for competition $competitionId',
        );
        return;
      }

      // 2. Get the match details
      final matchDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) return;

      final matchData = matchDoc.data()!;
      final team1Name = matchData['team1Name'] as String;
      final team2Name = matchData['team2Name'] as String;
      final scheduledTime = matchData['scheduledTime'] as Timestamp;

      // 3. Find or create the match in official_leagues
      // We need to match by team names and scheduled time (within a tolerance)
      final officialMatchesQuery = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .where('homeTeamName', isEqualTo: team1Name)
          .where('awayTeamName', isEqualTo: team2Name)
          .get();

      String? officialMatchId;

      // Find the match with the closest scheduled time
      for (var doc in officialMatchesQuery.docs) {
        final docTime = doc.data()['scheduledTime'] as Timestamp;
        final timeDiff = scheduledTime
            .toDate()
            .difference(docTime.toDate())
            .inHours
            .abs();

        if (timeDiff < 12) {
          // Within 12 hours
          officialMatchId = doc.id;
          break;
        }
      }

      // If not found by team1/team2, try reversed
      if (officialMatchId == null) {
        final reversedQuery = await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .collection('matches')
            .where('homeTeamName', isEqualTo: team2Name)
            .where('awayTeamName', isEqualTo: team1Name)
            .get();

        for (var doc in reversedQuery.docs) {
          final docTime = doc.data()['scheduledTime'] as Timestamp;
          final timeDiff = scheduledTime
              .toDate()
              .difference(docTime.toDate())
              .inHours
              .abs();

          if (timeDiff < 12) {
            officialMatchId = doc.id;
            break;
          }
        }
      }

      if (officialMatchId != null) {
        // Enrich score with names for cross-comp compatibility
        final enrichedScore = Map<String, dynamic>.from(score);
        final winnerId = score['winnerId'];
        if (winnerId != null) {
          if (winnerId == matchData['team1Id']) {
            enrichedScore['winnerName'] = team1Name;
          } else if (winnerId == matchData['team2Id']) {
            enrichedScore['winnerName'] = team2Name;
          } else if (winnerId == 'tied') {
            enrichedScore['winnerName'] = 'tied';
          }
        }
        final batFirstId = score['battingFirstId'];
        if (batFirstId != null) {
          if (batFirstId == matchData['team1Id']) {
            enrichedScore['battingFirstName'] = team1Name;
          } else if (batFirstId == matchData['team2Id']) {
            enrichedScore['battingFirstName'] = team2Name;
          }
        }

        // Update the official match with the manual score
        await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .collection('matches')
            .doc(officialMatchId)
            .update({
              'actualScore': enrichedScore,
              'status': status,
              'lastVerifiedTime': FieldValue.serverTimestamp(),
            });

        // Also update league metadata to trigger auto-sync listener in other competitions
        await _firestore.collection('official_leagues').doc(leagueId).set({
          'lastVerifiedTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '🌍 GLOBAL PROTECTION: Saved manual score to official_leagues/$leagueId/matches/$officialMatchId',
        );
      } else {
        // 🆕 CREATE THE MATCH if it doesn't exist in official_leagues
        // This ensures shared scores even for custom tournaments or unsynced official ones.
        final datePart = scheduledTime
            .toDate()
            .toIso8601String()
            .split('T')
            .first;
        final t1S = team1Name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final t2S = team2Name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final newDocId = '${datePart}_${t1S}_v_$t2S';

        final Map<String, dynamic> officialData = Map<String, dynamic>.from(
          matchData,
        );
        officialData['id'] = newDocId;
        officialData['homeTeamName'] = team1Name;
        officialData['awayTeamName'] = team2Name;
        officialData['actualScore'] = score;
        officialData['status'] = status;
        officialData['lastVerifiedTime'] = FieldValue.serverTimestamp();

        // Add Name-based winner/battingFirst for reliable cross-competition matching
        final winnerId = score['winnerId'];
        if (winnerId != null) {
          if (winnerId == matchData['team1Id']) {
            officialData['actualScore']['winnerName'] = team1Name;
          } else if (winnerId == matchData['team2Id']) {
            officialData['actualScore']['winnerName'] = team2Name;
          } else if (winnerId == 'tied') {
            officialData['actualScore']['winnerName'] = 'tied';
          }
        }

        final batFirstId = score['battingFirstId'];
        if (batFirstId != null) {
          if (batFirstId == matchData['team1Id']) {
            officialData['actualScore']['battingFirstName'] = team1Name;
          } else if (batFirstId == matchData['team2Id']) {
            officialData['actualScore']['battingFirstName'] = team2Name;
          }
        }

        await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .collection('matches')
            .doc(newDocId)
            .set(officialData, SetOptions(merge: true));

        // Also update league metadata to trigger auto-sync listener in other competitions
        await _firestore.collection('official_leagues').doc(leagueId).set({
          'lastVerifiedTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '🌍 GLOBAL PROTECTION: Created new official match record in official_leagues/$leagueId/matches/$newDocId',
        );
      }
    } catch (e) {
      debugPrint('Error saving manual score to official_leagues: $e');
      // Don't throw - this is a bonus feature, shouldn't break the main flow
    }
  }

  /// Removes a manually scored match from the official_leagues collection
  Future<void> _removeManualScoreFromOfficialLeagues(
    String competitionId,
    String matchId,
  ) async {
    try {
      // 1. Get the competition to find the leagueId
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();

      if (!compDoc.exists) return;

      final leagueId = compDoc.data()?['leagueId'] as String?;
      if (leagueId == null || leagueId.isEmpty) return;

      // 2. Get the match details
      final matchDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) return;

      final matchData = matchDoc.data()!;
      final team1Name = matchData['team1Name'] as String;
      final team2Name = matchData['team2Name'] as String;
      final scheduledTime = matchData['scheduledTime'] as Timestamp;

      // 3. Find the match in official_leagues
      final officialMatchesQuery = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .where('homeTeamName', isEqualTo: team1Name)
          .where('awayTeamName', isEqualTo: team2Name)
          .get();

      String? officialMatchId;

      for (var doc in officialMatchesQuery.docs) {
        final docTime = doc.data()['scheduledTime'] as Timestamp;
        final timeDiff = scheduledTime
            .toDate()
            .difference(docTime.toDate())
            .inHours
            .abs();

        if (timeDiff < 12) {
          officialMatchId = doc.id;
          break;
        }
      }

      if (officialMatchId == null) {
        final reversedQuery = await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .collection('matches')
            .where('homeTeamName', isEqualTo: team2Name)
            .where('awayTeamName', isEqualTo: team1Name)
            .get();

        for (var doc in reversedQuery.docs) {
          final docTime = doc.data()['scheduledTime'] as Timestamp;
          final timeDiff = scheduledTime
              .toDate()
              .difference(docTime.toDate())
              .inHours
              .abs();

          if (timeDiff < 12) {
            officialMatchId = doc.id;
            break;
          }
        }
      }

      if (officialMatchId != null) {
        // Only remove the manuallyScored flag, keep other data
        final officialDoc = await _firestore
            .collection('official_leagues')
            .doc(leagueId)
            .collection('matches')
            .doc(officialMatchId)
            .get();

        if (officialDoc.exists) {
          final actualScore =
              officialDoc.data()?['actualScore'] as Map<String, dynamic>?;
          if (actualScore != null && actualScore['manuallyScored'] == true) {
            // Remove the entire actualScore since it was manually set
            await _firestore
                .collection('official_leagues')
                .doc(leagueId)
                .collection('matches')
                .doc(officialMatchId)
                .update({'actualScore': null, 'status': 'upcoming'});

            debugPrint(
              '🌍 GLOBAL PROTECTION: Removed manual score from official_leagues/$leagueId/matches/$officialMatchId',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error removing manual score from official_leagues: $e');
    }
  }

  // ========== MASTER ADMIN WORKFLOW (Soft Copy -> Hard Copy) ==========

  /// 1. Save SOFT COPY (From API)
  Future<void> saveSoftMatches(
    String leagueId,
    List<MatchModel> matches,
  ) async {
    try {
      final softCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches');

      // 1. Get Existing Soft Matches
      final existingSoftSnap = await softCollection.get();
      final Map<String, MatchModel> existingSoftMap = {};
      for (var doc in existingSoftSnap.docs) {
        final m = MatchModel.fromSnapshot(doc);
        // Key: T1_v_T2_Date (Sanitized)
        final key = _generateMatchKey(m);
        existingSoftMap[key] = m;
      }

      // 2. Get Existing Hard Copy (Official) matches for this league
      // This ensures if a match was promoted/verified, we pull that back into Soft Copy view.
      final hardCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');
      final existingHardSnap = await hardCollection.get();
      final Map<String, MatchModel> existingHardMap = {};
      for (var doc in existingHardSnap.docs) {
        final m = MatchModel.fromSnapshot(doc);
        final key = _generateMatchKey(m);
        existingHardMap[key] = m;
      }

      final batch = _firestore.batch();
      final Set<String> incomingKeys = {};

      for (var match in matches) {
        final key = _generateMatchKey(match);
        if (incomingKeys.contains(key))
          continue; // SKIP exact duplicate incoming matches
        incomingKeys.add(key);

        // --- BULLETPROOF PROTECTION LOGIC ---
        // We look for any existing match (Soft or Hard) that is already VERIFIED.
        // If it exists, we strictly PRESERVE it and discard the incoming API data.

        MatchModel? existingSoft = existingSoftMap[key];
        MatchModel? existingHard = existingHardMap[key];

        // 2. Fallback: Fuzzy Match (Robust)
        // Helps with timezone shifts (midnight boundary) and slight date variations
        if (existingSoft == null || existingHard == null) {
          for (var sm in existingSoftMap.values) {
            if (existingSoft == null && _isSameMatchFuzzy(sm, match)) {
              existingSoft = sm;
            }
          }
          for (var hm in existingHardMap.values) {
            if (existingHard == null && _isSameMatchFuzzy(hm, match)) {
              existingHard = hm;
            }
          }
        }

        // PROTECTION ENFORCEMENT
        MatchModel finalMatch = match;

        // 👻 GHOST PURGE: Prevent future matches from having scores (Intercepted API drafts)
        // We permit a small 5-minute buffer for matches that are just kicking off.
        if (finalMatch.scheduledTime.isAfter(
          DateTime.now().add(const Duration(minutes: 5)),
        )) {
          if (finalMatch.actualScore != null ||
              (finalMatch.status != 'upcoming' &&
                  finalMatch.status != 'scheduled')) {
            finalMatch = finalMatch.copyWith(
              status: 'upcoming',
              actualScore: null,
              winnerId: null,
            );
            debugPrint(
              '👻 GHOST PURGE: Stripped fake scores/status from future match: ${finalMatch.team1Name} vs ${finalMatch.team2Name}',
            );
          }
        }

        // 🛡️ Priority 1: If it's verified in Hard Copy, use that!
        if (existingHard != null && existingHard.isVerified) {
          finalMatch = existingHard;
          debugPrint(
            '🛡️ PROTECTED (Hard Verified): ${match.team1Name} vs ${match.team2Name}',
          );
        }
        // 🛡️ Priority 2: If it's verified in existing Soft Copy, keep it!
        else if (existingSoft != null && existingSoft.isVerified) {
          finalMatch = existingSoft;
          debugPrint(
            '🛡️ PROTECTED (Soft Verified): ${match.team1Name} vs ${match.team2Name}',
          );
        }

        if (existingSoft != null) {
          // Update existing doc
          batch.set(
            softCollection.doc(existingSoft.id),
            finalMatch.toMap(),
            SetOptions(merge: true),
          );
        } else {
          // Create new doc
          batch.set(softCollection.doc(), finalMatch.toMap());
        }
      }

      // 3. Cleanup: Delete soft matches that are NOT in the feed AND NOT verified
      for (var entry in existingSoftMap.entries) {
        if (!incomingKeys.contains(entry.key) && !entry.value.isVerified) {
          batch.delete(softCollection.doc(entry.value.id));
        }
      }

      // Update Metadata
      batch.set(
        _firestore.collection('official_leagues').doc(leagueId),
        {'lastSoftCopyTime': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('✅ Soft Copy saved (Smart Merge) for $leagueId');
    } catch (e) {
      throw Exception('Failed to save soft matches: ${e.toString()}');
    }
  }

  String _generateMatchKey(MatchModel m) {
    // Use Primary Name to ensure "SC East Bengal" and "East Bengal FC" produce the same key
    final p1 = TeamsDataService.getPrimaryName(m.team1Name);
    final p2 = TeamsDataService.getPrimaryName(m.team2Name);

    // Helper to normalize names for keys (e.g., "South Africa" -> "southafrica")
    String norm(String name) =>
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final t1 = norm(p1);
    final t2 = norm(p2);

    // Use UTC date for key stability
    final date = m.scheduledTime.toUtc().toIso8601String().split('T').first;

    // Sort teams to ensure key is the same regardless of home/away order
    final teams = [t1, t2]..sort();

    return '${teams[0]}_v_${teams[1]}_$date';
  }

  bool _isSameMatchFuzzy(MatchModel m1, MatchModel m2) {
    // Helper to normalize names for comparison (e.g., "South Africa" -> "southafrica")
    String norm(String name) =>
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final n1t1 = norm(m1.team1Name);
    final n1t2 = norm(m1.team2Name);
    final n2t1 = norm(m2.team1Name);
    final n2t2 = norm(m2.team2Name);

    // 1. Team Match (Any Order) with normalization
    final bool teamsMatch =
        (n1t1 == n2t1 && n1t2 == n2t2) || (n1t1 == n2t2 && n1t2 == n2t1);

    if (!teamsMatch) return false;

    // 2. Time Match (Within 12 hours) - handles most timezone/day shifts
    final diff = m1.scheduledTime.difference(m2.scheduledTime).inHours.abs();
    if (diff < 12) return true;

    // 3. Fallback: Match Number (if both have one and they match)
    if (m1.matchNumber != null &&
        m1.matchNumber! > 0 &&
        m1.matchNumber == m2.matchNumber) {
      return true;
    }

    return false;
  }

  /// 2. Get SOFT COPY (For Verification)
  Future<List<MatchModel>> getSoftMatches(String leagueId) async {
    try {
      final snapshot = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches')
          .get();

      return snapshot.docs.map((doc) => MatchModel.fromSnapshot(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get soft matches: ${e.toString()}');
    }
  }

  /// 2b. Update a specific SOFT MATCH (score / status / date / etc)
  Future<void> updateSoftMatch(
    String leagueId,
    String docId, {
    Map<String, dynamic>? actualScore,
    String? status,
    DateTime? scheduledTime,
    MatchModel? fullMatch,
  }) async {
    try {
      final docRef = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches')
          .doc(docId);

      if (fullMatch != null) {
        await docRef.update(fullMatch.toMap());
      } else {
        final updates = <String, dynamic>{};
        if (actualScore != null) updates['actualScore'] = actualScore;
        if (status != null) updates['status'] = status;
        if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
        await docRef.update(updates);
      }
      debugPrint('✅ Soft match $docId updated for $leagueId');
    } catch (e) {
      throw Exception('Failed to update soft match: ${e.toString()}');
    }
  }

  /// 2c. Delete SOFT MATCH
  Future<void> deleteSoftMatch(String leagueId, String matchId) async {
    try {
      await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches')
          .doc(matchId)
          .delete();
      debugPrint('✅ Soft match $matchId deleted from $leagueId');
    } catch (e) {
      throw Exception('Failed to delete soft match: ${e.toString()}');
    }
  }

  /// 2d. Add SOFT MATCH
  Future<void> addSoftMatch(String leagueId, MatchModel match) async {
    try {
      final collection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches');

      String docId = match.id.isEmpty ? collection.doc().id : match.id;
      final matchToSave = match.copyWith(id: docId);

      await collection.doc(docId).set(matchToSave.toMap());
      debugPrint('✅ Soft match $docId added to $leagueId');
    } catch (e) {
      throw Exception('Failed to add soft match: ${e.toString()}');
    }
  }

  /// 3. Promote to HARD COPY (After Verification)
  Future<void> promoteSoftToHardCopy(String leagueId) async {
    try {
      final softMatches = await getSoftMatches(leagueId);
      if (softMatches.isEmpty) return;

      final batch = _firestore.batch();
      final hardCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');

      // 1. Get existing Hard Copy to match against
      final existingSnap = await hardCollection.get();
      final List<MatchModel> rawExistingMatches = existingSnap.docs
          .map((doc) => MatchModel.fromSnapshot(doc))
          .toList();

      // 🧹 PRE-PROMOTION DEDUPLICATION: Remove any existing duplicates in hard copy
      final Set<String> seenExistingKeys = {};
      final List<MatchModel> existingHardMatches = [];
      for (var m in rawExistingMatches) {
        final key = _generateMatchKey(m);
        if (seenExistingKeys.contains(key)) {
          debugPrint(
            '🧹 PROMO: Found duplicate hard match ${m.id} ($key), cleaning up...',
          );
          await hardCollection.doc(m.id).delete();
        } else {
          seenExistingKeys.add(key);
          existingHardMatches.add(m);
        }
      }

      final Set<String> processedKeys = {};

      for (var soft in softMatches) {
        final key = _generateMatchKey(soft);
        if (processedKeys.contains(key))
          continue; // SKIP exact duplicate soft match
        processedKeys.add(key);

        String? targetId;

        // Try to find matching existing match using alias-aware logic
        final matchIndex = existingHardMatches.indexWhere((hard) {
          bool teamsMatch =
              (TeamsDataService.areTeamNamesEquivalent(
                    hard.team1Name,
                    soft.team1Name,
                  ) &&
                  TeamsDataService.areTeamNamesEquivalent(
                    hard.team2Name,
                    soft.team2Name,
                  )) ||
              (TeamsDataService.areTeamNamesEquivalent(
                    hard.team1Name,
                    soft.team2Name,
                  ) &&
                  TeamsDataService.areTeamNamesEquivalent(
                    hard.team2Name,
                    soft.team1Name,
                  ));

          if (!teamsMatch) return false;

          final hourDiff = hard.scheduledTime
              .difference(soft.scheduledTime)
              .inHours
              .abs();
          return hourDiff < 48; // Expanded window for master verification
        });

        if (matchIndex != -1) {
          targetId = existingHardMatches[matchIndex].id;
        } else {
          targetId = hardCollection.doc().id;
        }

        final docRef = hardCollection.doc(targetId);

        // Write Soft Copy data to Hard Copy AND Mark as Verified
        final data = soft.toMap();

        // Add compatibility fields for MasterSync/Follower mapping
        data['homeTeamName'] = soft.team1Name;
        data['awayTeamName'] = soft.team2Name;
        data['homeTeamCode'] = soft.team1Id.length <= 10
            ? soft.team1Id
            : ''; // Use ID as code if short, else skip
        data['awayTeamCode'] = soft.team2Id.length <= 10 ? soft.team2Id : '';

        if (data['actualScore'] != null) {
          data['actualScore'] = Map<String, dynamic>.from(data['actualScore']);
          data['actualScore']['verified'] = true;

          // Add Name-based winner/battingFirst for reliable cross-competition matching
          if (soft.winnerId != null) {
            if (soft.winnerId == soft.team1Id) {
              data['actualScore']['winnerName'] = soft.team1Name;
            } else if (soft.winnerId == soft.team2Id) {
              data['actualScore']['winnerName'] = soft.team2Name;
            } else if (soft.winnerId == 'tied') {
              data['actualScore']['winnerName'] = 'tied';
            }
          }

          final batFirstId = data['actualScore']['battingFirstId'];
          if (batFirstId != null) {
            if (batFirstId == soft.team1Id) {
              data['actualScore']['battingFirstName'] = soft.team1Name;
            } else if (batFirstId == soft.team2Id) {
              data['actualScore']['battingFirstName'] = soft.team2Name;
            }
          }
        }

        batch.set(docRef, data);
      }

      // Update Metadata: Verification Complete
      batch.set(
        _firestore.collection('official_leagues').doc(leagueId),
        {
          'lastVerifiedTime': FieldValue.serverTimestamp(),
          'verifiedMatchCount': softMatches.length,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Auto-clean any historical duplicates
      await _cleanupHardCopyDuplicates(leagueId);

      debugPrint('✅ Hard Copy promoted for $leagueId');
    } catch (e) {
      throw Exception('Failed to promote soft copy: ${e.toString()}');
    }
  }

  Future<void> _cleanupHardCopyDuplicates(String leagueId) async {
    try {
      final hardCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');

      final snap = await hardCollection.get();
      final Map<String, List<String>> seen = {};

      for (var doc in snap.docs) {
        final m = MatchModel.fromSnapshot(doc);
        final key = _generateMatchKey(m);

        if (!seen.containsKey(key)) {
          seen[key] = [];
        }
        seen[key]!.add(doc.id);
      }

      for (var entry in seen.entries) {
        if (entry.value.length > 1) {
          // Keep the first one, delete the rest
          for (int i = 1; i < entry.value.length; i++) {
            await hardCollection.doc(entry.value[i]).delete();
            debugPrint(
              '🗑️ Cleaned up duplicate hard copy match: ${entry.value[i]}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up hard copy duplicates: $e');
    }
  }

  /// 3b. Verify & Push SINGLE Match Score
  // Clean Hard Copy matches for a league
  Future<void> cleanHardCopy(String leagueId) async {
    try {
      final matchesCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');
      await _deleteCollection(matchesCollection);

      // Also update the league status: Set a tombstone to prevent re-fetch of old data
      await _firestore.collection('official_leagues').doc(leagueId).update({
        'lastCleanedAt': FieldValue.serverTimestamp(),
        // We REMOVE setting lastMasterSync to null, as it causes immediate re-population of garbage.
        // Instead, the next scheduled sync will honor lastCleanedAt.
      });
    } catch (e) {
      throw Exception('Failed to clean hard copy matches: $e');
    }
  }

  /// Clean Soft Copy matches for a league
  Future<void> cleanSoftCopy(String leagueId) async {
    try {
      final softCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches');
      await _deleteCollection(softCollection);

      await _firestore.collection('official_leagues').doc(leagueId).update({
        'lastSoftCopyTime': null,
      });
      debugPrint('✅ Soft matches cleaned for $leagueId');
    } catch (e) {
      throw Exception('Failed to clean soft matches: $e');
    }
  }

  /// Delete ALL matches from a specific competition
  Future<void> deleteCompetitionMatches(String competitionId) async {
    try {
      final matchesCollection = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches');
      await _deleteCollection(matchesCollection);

      // Recalculate standings (will reset everyone to 0)
      await recalculateStandings(competitionId);

      // Set a tombstone to prevent immediate re-population by followers
      await _firestore.collection('competitions').doc(competitionId).update({
        'lastCleanedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ All matches deleted for competition $competitionId');
    } catch (e) {
      throw Exception('Failed to delete competition matches: $e');
    }
  }

  Future<void> verifyAndPushMatch(String leagueId, MatchModel match) async {
    try {
      final batch = _firestore.batch();

      // 1. Update Soft Copy
      final softCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('soft_matches');

      final DocumentReference softDoc;
      if (match.id.isEmpty) {
        softDoc = softCollection.doc();
      } else {
        softDoc = softCollection.doc(match.id);
      }

      final data = match.toMap();
      if (match.id.isEmpty) {
        data['id'] = softDoc.id;
      }

      if (data['actualScore'] != null) {
        data['actualScore']['verified'] = true;
      }

      if (match.id.isEmpty) {
        batch.set(softDoc, data);
      } else {
        batch.update(softDoc, data);
      }

      // 2. Update Hard Copy (Find or Create)
      final hardCollection = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');

      final existingSnap = await hardCollection.get();
      final existingHardMatches = existingSnap.docs
          .map((doc) => MatchModel.fromSnapshot(doc))
          .toList();

      String? targetId;
      final matchIndex = existingHardMatches.indexWhere((hard) {
        bool teamsMatch =
            (hard.team1Name == match.team1Name &&
                hard.team2Name == match.team2Name) ||
            (hard.team1Name == match.team2Name &&
                hard.team2Name == match.team1Name);
        if (!teamsMatch) return false;
        return hard.scheduledTime
                .difference(match.scheduledTime)
                .inHours
                .abs() <
            24;
      });

      if (matchIndex != -1) {
        targetId = existingHardMatches[matchIndex].id;
      } else {
        targetId = hardCollection.doc().id;
      }

      // Ensure root-level winnerId is set from actualScore if missing
      final scoreWinnerId = match.actualScore?['winnerId']?.toString();
      if ((data['winnerId'] == null || data['winnerId'] == '') &&
          scoreWinnerId != null &&
          scoreWinnerId.isNotEmpty) {
        data['winnerId'] = scoreWinnerId;
      }

      // Prepare data for Hard Copy
      final hardData = Map<String, dynamic>.from(data);
      hardData['homeTeamName'] = match.team1Name;
      hardData['awayTeamName'] = match.team2Name;
      if (hardData['actualScore'] != null) {
        final resolvedWinner = data['winnerId']?.toString() ?? scoreWinnerId;
        if (resolvedWinner == match.team1Id) {
          hardData['actualScore']['winnerName'] = match.team1Name;
        } else if (resolvedWinner == match.team2Id) {
          hardData['actualScore']['winnerName'] = match.team2Name;
        } else if (resolvedWinner == 'draw') {
          hardData['actualScore']['winnerName'] = 'draw';
        } else if (resolvedWinner == 'tied') {
          hardData['actualScore']['winnerName'] = 'tied';
        }
      }

      batch.set(hardCollection.doc(targetId), hardData);

      // 3. Update League Metadata to Trigger Auto-Sync
      batch.set(
        _firestore.collection('official_leagues').doc(leagueId),
        {'lastVerifiedTime': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('✅ Individual match verified and pushed for $leagueId');

      // 4. Directly push this single match's score to ALL competitions linked to this league
      try {
        final competitionsSnap = await _firestore
            .collection('competitions')
            .where('leagueId', isEqualTo: leagueId)
            .get();

        debugPrint(
          '🔄 Found ${competitionsSnap.docs.length} competitions linked to $leagueId — pushing match score...',
        );

        final matchT1 = match.team1Name.toLowerCase().trim();
        final matchT2 = match.team2Name.toLowerCase().trim();

        for (final compDoc in competitionsSnap.docs) {
          final compId = compDoc.id;
          try {
            // Fetch all matches in this competition
            final matchesSnap = await _firestore
                .collection('competitions')
                .doc(compId)
                .collection('matches')
                .get();

            // Find matching match(es) by team names + date
            final matchingDocs = matchesSnap.docs.where((doc) {
              final d = doc.data();
              final t1 = (d['team1Name'] ?? '').toString().toLowerCase().trim();
              final t2 = (d['team2Name'] ?? '').toString().toLowerCase().trim();
              final teamsMatch =
                  (t1 == matchT1 && t2 == matchT2) ||
                  (t1 == matchT2 && t2 == matchT1);
              if (!teamsMatch) return false;
              final scheduledTime = (d['scheduledTime'] as Timestamp?)
                  ?.toDate();
              if (scheduledTime == null) return false;
              return scheduledTime
                      .difference(match.scheduledTime)
                      .inHours
                      .abs() <
                  48;
            }).toList();

            if (matchingDocs.isEmpty) {
              debugPrint(
                '  ⚠️ No match found in competition $compId for ${match.team1Name} vs ${match.team2Name}',
              );
              continue;
            }

            // If multiple duplicates found, keep the first and delete the rest
            final primaryDoc = matchingDocs.first;
            if (matchingDocs.length > 1) {
              debugPrint(
                '  🧹 Found ${matchingDocs.length} duplicates for ${match.team1Name} vs ${match.team2Name} in $compId — cleaning up...',
              );
              final dupesBatch = _firestore.batch();
              for (int i = 1; i < matchingDocs.length; i++) {
                dupesBatch.delete(matchingDocs[i].reference);
              }
              await dupesBatch.commit();
            }

            // Determine if teams are reversed in the competition
            final compT1 = (primaryDoc.data()['team1Name'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            final isReversed = (compT1 != matchT1);

            // Build the update data
            final Map<String, dynamic> updateData = {};

            // Update actualScore
            if (data['actualScore'] != null) {
              final Map<String, dynamic> scoreToApply =
                  Map<String, dynamic>.from(data['actualScore']);

              if (isReversed) {
                // Swap team1/team2 scores
                if (scoreToApply.containsKey('team1') &&
                    scoreToApply.containsKey('team2')) {
                  final temp = scoreToApply['team1'];
                  scoreToApply['team1'] = scoreToApply['team2'];
                  scoreToApply['team2'] = temp;
                }
                // Swap t1/t2 cricket fields
                if (scoreToApply.containsKey('t1Runs')) {
                  final tempRuns = scoreToApply['t1Runs'];
                  final tempWickets = scoreToApply['t1Wickets'];
                  final tempOvers = scoreToApply['t1Overs'];
                  scoreToApply['t1Runs'] = scoreToApply['t2Runs'];
                  scoreToApply['t1Wickets'] = scoreToApply['t2Wickets'];
                  scoreToApply['t1Overs'] = scoreToApply['t2Overs'];
                  scoreToApply['t2Runs'] = tempRuns;
                  scoreToApply['t2Wickets'] = tempWickets;
                  scoreToApply['t2Overs'] = tempOvers;
                }
                // Map winnerId to competition's team IDs
                final compData = primaryDoc.data();
                final compTeam1Id = compData['team1Id']?.toString();
                final compTeam2Id = compData['team2Id']?.toString();
                if (scoreToApply['winnerId'] == match.team1Id) {
                  scoreToApply['winnerId'] = compTeam2Id;
                } else if (scoreToApply['winnerId'] == match.team2Id) {
                  scoreToApply['winnerId'] = compTeam1Id;
                }
              } else {
                // Same direction — map winnerId
                final compData = primaryDoc.data();
                final compTeam1Id = compData['team1Id']?.toString();
                final compTeam2Id = compData['team2Id']?.toString();
                if (scoreToApply['winnerId'] == match.team1Id) {
                  scoreToApply['winnerId'] = compTeam1Id;
                } else if (scoreToApply['winnerId'] == match.team2Id) {
                  scoreToApply['winnerId'] = compTeam2Id;
                }
                // 'draw', 'tied', 'no_result' pass through unchanged
              }

              updateData['actualScore'] = scoreToApply;
            }

            // Update status
            updateData['status'] = data['status'] ?? match.status;

            // Update winnerId at root level
            if (data['winnerId'] != null) {
              String resolvedWinner = data['winnerId'].toString();
              if (resolvedWinner != 'draw' &&
                  resolvedWinner != 'tied' &&
                  resolvedWinner != 'no_result') {
                final compData = primaryDoc.data();
                final compTeam1Id = compData['team1Id']?.toString();
                final compTeam2Id = compData['team2Id']?.toString();
                if (isReversed) {
                  if (resolvedWinner == match.team1Id) {
                    resolvedWinner = compTeam2Id ?? resolvedWinner;
                  } else if (resolvedWinner == match.team2Id) {
                    resolvedWinner = compTeam1Id ?? resolvedWinner;
                  }
                } else {
                  if (resolvedWinner == match.team1Id) {
                    resolvedWinner = compTeam1Id ?? resolvedWinner;
                  } else if (resolvedWinner == match.team2Id) {
                    resolvedWinner = compTeam2Id ?? resolvedWinner;
                  }
                }
              }
              updateData['winnerId'] = resolvedWinner;
            }

            await primaryDoc.reference.update(updateData);
            debugPrint(
              '  ✅ Updated ${match.team1Name} vs ${match.team2Name} in competition $compId',
            );
          } catch (syncError) {
            debugPrint(
              '  ⚠️ Failed to sync match in competition $compId: $syncError',
            );
          }
        }

        debugPrint(
          '🔄 All competitions synced for ${match.team1Name} vs ${match.team2Name}',
        );
      } catch (e) {
        debugPrint('⚠️ Error syncing competitions for $leagueId: $e');
        // Don't throw — the verification itself succeeded
      }
    } catch (e) {
      throw Exception('Failed to verify single match: ${e.toString()}');
    }
  }

  /// 4. Stream Verification Status (For App Refresh)
  Stream<Timestamp?> streamLeagueVerificationStatus(String leagueId) {
    return _firestore
        .collection('official_leagues')
        .doc(leagueId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final v = doc.data()?['lastVerifiedTime'] as Timestamp?;
          final c = doc.data()?['lastCleanedAt'] as Timestamp?;
          if (v == null) return c;
          if (c == null) return v;
          return v.compareTo(c) > 0 ? v : c;
        });
  }

  /// 5. Auto-Sync Trigger (Call this from UI)
  /// Listens to verification updates and triggers sync automatically.
  StreamSubscription<Timestamp?> startAutoSync(
    String competitionId,
    String leagueId,
  ) {
    return streamLeagueVerificationStatus(leagueId).listen((timestamp) {
      if (timestamp != null) {
        debugPrint(
          '🔔 VERIFICATION DETECTED for $leagueId at $timestamp - Syncing Competition $competitionId',
        );
        syncOfficialTournamentScores(
          competitionId: competitionId,
          leagueId: leagueId,
        );
      }
    });
  }

  // Private method to revert predictions
  Future<void> _revertPredictions(String competitionId, String matchId) async {
    try {
      final predictionsSnapshot = await _firestore
          .collection('predictions')
          .where('matchId', isEqualTo: matchId)
          .where('isScored', isEqualTo: true)
          .get();

      if (predictionsSnapshot.docs.isEmpty) return;

      final allDocs = predictionsSnapshot.docs;
      final int batchSize = 400;

      for (int i = 0; i < allDocs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < allDocs.length)
            ? i + batchSize
            : allDocs.length;
        final currentChunk = allDocs.sublist(i, end);

        final participantsRef = _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('participants');

        for (var doc in currentChunk) {
          final prediction = PredictionModel.fromSnapshot(doc);
          final points = prediction.points ?? 0;
          final perfectScores = prediction.wasPerfectScore ? 1 : 0;
          final correctOutcomes = prediction.wasCorrectOutcome ? 1 : 0;

          // Subtract points and stats
          batch.update(participantsRef.doc(prediction.userId), {
            'totalPoints': FieldValue.increment(-points),
            'perfectScores': FieldValue.increment(-perfectScores),
            'correctOutcomes': FieldValue.increment(-correctOutcomes),
          });

          // Reset Prediction Status
          batch.update(doc.reference, {
            'points': 0,
            'isScored': false,
            'wasPerfectScore': false,
            'wasCorrectOutcome': false,
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error reverting predictions: $e');
    }
  }

  // Private method to process predictions
  /// Public wrapper for processing predictions (used by TournamentDataService auto-refresh)
  Future<void> processPredictionsPublic(
    String competitionId,
    String matchId,
    Map<String, dynamic> actualScore,
  ) => _processPredictions(competitionId, matchId, actualScore);

  Future<void> _processPredictions(
    String competitionId,
    String matchId,
    Map<String, dynamic> actualScore, {
    Map<String, dynamic>? oldScore,
  }) async {
    try {
      // 1. Get competition rules
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (!compDoc.exists) return;
      final competition = CompetitionModel.fromSnapshot(compDoc);
      final rules = competition.rules;
      final pointsForWinner = rules['correctWinner'] ?? 3;
      final pointsForScore = rules['correctScore'] ?? 2;

      // 2. Get all predictions for this match
      // 2. Get all predictions for this match
      final predictionsSnapshot = await _firestore
          .collection('predictions')
          .where('matchId', isEqualTo: matchId)
          .get();

      final allDocs = predictionsSnapshot.docs;
      if (allDocs.isEmpty) return;

      final int batchSize = 400; // Limit is 500, keeping safety margin

      // 3. Fetch the match to resolve team IDs (needed for slug→UUID resolution)
      MatchModel? matchDoc;
      try {
        final matchSnap = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('matches')
            .doc(matchId)
            .get();
        if (matchSnap.exists) {
          matchDoc = MatchModel.fromSnapshot(matchSnap);
        }
      } catch (_) {}

      final participantsRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants');

      for (int i = 0; i < allDocs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < allDocs.length)
            ? i + batchSize
            : allDocs.length;
        final currentChunk = allDocs.sublist(i, end);

        for (var doc in currentChunk) {
          final prediction = PredictionModel.fromSnapshot(doc);
          final predScore = prediction.prediction;
          // Calculate points and stats
          int points = 0;
          bool isPerfectScore = false;
          bool isCorrectOutcome = false;

          // ... (Logic remains mostly same, just ensuring variables are scoped correctly)
          if (competition.sport == AppConstants.sportCricket) {
            // Cricket Logic
            String? actualWinnerId = actualScore['winnerId'];
            final String? predWinnerId = predScore['winnerId'];
            String? startMarginType = actualScore['marginType'];
            final String? actualMarginValue = actualScore['marginValue']
                ?.toString();

            // 1. Resolve winner ID: API stores slugs (e.g., "south_africa"),
            //    but predictions store UUIDs. Map slug → UUID using team names.
            if (actualWinnerId != null &&
                actualWinnerId != 'tied' &&
                actualWinnerId != 'no_result' &&
                !actualWinnerId.contains('-') &&
                matchDoc != null) {
              // Normalize: "south_africa" → "south africa"
              final slug = actualWinnerId.toLowerCase().replaceAll('_', '');
              final t1n = matchDoc.team1Name
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .replaceAll('_', '');
              final t2n = matchDoc.team2Name
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .replaceAll('_', '');
              if (t1n.contains(slug) || slug.contains(t1n)) {
                actualWinnerId = matchDoc.team1Id;
              } else if (t2n.contains(slug) || slug.contains(t2n)) {
                actualWinnerId = matchDoc.team2Id;
              }
            }

            // 2. Infer Winner if still missing (tied check from run scores)
            if (actualWinnerId == null && actualScore['t1Runs'] != null) {
              final t1 =
                  int.tryParse(actualScore['t1Runs']?.toString() ?? '0') ?? 0;
              final t2 =
                  int.tryParse(actualScore['t2Runs']?.toString() ?? '0') ?? 0;
              if (t1 == t2) {
                actualWinnerId = 'tied';
              }
            }

            // 3. Check Winner Points
            if (actualWinnerId != null &&
                predWinnerId != null &&
                actualWinnerId == predWinnerId) {
              points = pointsForWinner;
              isCorrectOutcome = true;
            }

            // 3. Infer Margin Type if missing (Fix for 'null' marginType issue)
            if (startMarginType == null && actualMarginValue != null) {
              final val = int.tryParse(actualMarginValue) ?? -1;
              final t1 =
                  int.tryParse(actualScore['t1Runs']?.toString() ?? '0') ?? 0;
              final t2 =
                  int.tryParse(actualScore['t2Runs']?.toString() ?? '0') ?? 0;
              final diffRuns = (t1 - t2).abs();

              // Use Batting First to determine margin type (Standard Cricket Rules)
              final String? battingFirstId = actualScore['battingFirstId'];
              if (battingFirstId != null && actualWinnerId != null) {
                if (battingFirstId == actualWinnerId) {
                  startMarginType = 'runs';
                } else {
                  startMarginType = 'wickets';
                }
              } else if (val == diffRuns) {
                startMarginType = 'runs';
              }
            }

            // 4. Prepare for Margin Check
            final String? predRuns = predScore['runs']?.toString();
            final String? predWickets = predScore['wickets']?.toString();
            bool marginCorrect = false;

            if (startMarginType != null && actualMarginValue != null) {
              String cleanMarginType = startMarginType.toLowerCase();
              if (cleanMarginType == 'runs' && predRuns != null) {
                marginCorrect = _checkMargin(
                  actualMarginValue,
                  predRuns,
                  'runs',
                );
              } else if (cleanMarginType == 'wickets' && predWickets != null) {
                marginCorrect = _checkMargin(
                  actualMarginValue,
                  predWickets,
                  'wickets',
                );
              }
            }
            // Treat super over as a tie for scoring purposes
            final String? actualMarginType = actualScore['marginType'];
            final bool isSuperOver =
                actualMarginType?.toLowerCase() == 'super_over';

            if (actualWinnerId == 'tied' && predWinnerId == 'tied') {
              marginCorrect = true;
            } else if (isSuperOver && predWinnerId == 'tied') {
              // Super over match: user predicted tie, award full points
              marginCorrect = true;
              isCorrectOutcome = true;
              points =
                  pointsForWinner; // Award winner points for predicting tie
            }

            if (marginCorrect &&
                (isCorrectOutcome || actualWinnerId == 'tied' || isSuperOver)) {
              points += pointsForScore;
              if (isCorrectOutcome) isPerfectScore = true;
            }
          } else {
            // Football / Default Logic
            final bool predictedTie = prediction.prediction['isTie'] == true;
            final bool actualTie = actualScore['marginType'] == 'tie';

            if (predictedTie) {
              if (actualTie) {
                points += pointsForWinner; // 3
                isCorrectOutcome = true;
                points += pointsForScore; // +2
                isPerfectScore = true;
              }
            } else if (actualTie) {
              // predicted winner but was tie -> 0
            } else {
              // Normal Winner Logic
              final actualHome = actualScore['team1'] is num
                  ? (actualScore['team1'] as num).toInt()
                  : -1;
              final actualAway = actualScore['team2'] is num
                  ? (actualScore['team2'] as num).toInt()
                  : -1;
              final predHome = predScore['team1'] is num
                  ? (predScore['team1'] as num).toInt()
                  : -1;
              final predAway = predScore['team2'] is num
                  ? (predScore['team2'] as num).toInt()
                  : -1;

              if (actualHome != -1 &&
                  actualAway != -1 &&
                  predHome != -1 &&
                  predAway != -1) {
                bool outcomeMatches = false;
                if (actualHome > actualAway && predHome > predAway) {
                  outcomeMatches = true;
                } else if (actualHome < actualAway && predHome < predAway) {
                  outcomeMatches = true;
                } else if (actualHome == actualAway && predHome == predAway) {
                  outcomeMatches = true;
                }

                final bool scoreMatches =
                    actualHome == predHome && actualAway == predAway;

                if (outcomeMatches) {
                  points += pointsForWinner;
                  isCorrectOutcome = true;
                }
                if (scoreMatches && outcomeMatches) {
                  points += pointsForScore;
                }
                if (outcomeMatches && scoreMatches) {
                  isPerfectScore = true;
                }
              } else {
                // Fallback for incomplete scores (e.g. Cricket without detailed stats but with winnerId)
                final String? actualWinnerId = actualScore['winnerId'];
                final String? predWinnerId = prediction.prediction['winnerId'];
                if (actualWinnerId != null &&
                    predWinnerId != null &&
                    actualWinnerId == predWinnerId) {
                  points += pointsForWinner;
                  isCorrectOutcome = true;
                }
              }
            }
          }

          // Update Logic
          int pointsDiff = points;
          int perfectScoresDiff = isPerfectScore ? 1 : 0;
          int correctOutcomesDiff = isCorrectOutcome ? 1 : 0;

          if (prediction.isScored) {
            pointsDiff = points - (prediction.points ?? 0);
            perfectScoresDiff =
                (isPerfectScore ? 1 : 0) - (prediction.wasPerfectScore ? 1 : 0);
            correctOutcomesDiff =
                (isCorrectOutcome ? 1 : 0) -
                (prediction.wasCorrectOutcome ? 1 : 0);
          }

          if (pointsDiff != 0 ||
              perfectScoresDiff != 0 ||
              correctOutcomesDiff != 0) {
            batch.update(participantsRef.doc(prediction.userId), {
              'totalPoints': FieldValue.increment(pointsDiff),
              'perfectScores': FieldValue.increment(perfectScoresDiff),
              'correctOutcomes': FieldValue.increment(correctOutcomesDiff),
            });
          }

          batch.update(doc.reference, {
            'points': points,
            'isScored': true,
            'wasPerfectScore': isPerfectScore,
            'wasCorrectOutcome': isCorrectOutcome,
          });
        }

        // Commit this chunk
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error processing predictions: $e');
      // Don't throw, as we don't want to fail the match update if predictions fail
      // but maybe log it properly
    }
  }

  // Get Standings
  Stream<List<StandingModel>> getStandings(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('standings')
        .orderBy('points', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => StandingModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Private method to update standings
  // Recalculate Standings Logic
  Future<void> recalculateStandings(String competitionId) async {
    try {
      debugPrint('Recalculating standings for $competitionId');

      // 1. Fetch Competition Rules
      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (!compDoc.exists) {
        debugPrint('Competition doc not found');
        return;
      }
      final competition = CompetitionModel.fromSnapshot(compDoc);

      // 2. Fetch All Teams (to initialize empty rows)
      final teamsSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('teams')
          .get();

      debugPrint('Found ${teamsSnapshot.docs.length} teams');

      final Map<String, StandingModel> teamStats = {};
      for (var doc in teamsSnapshot.docs) {
        final data = doc.data();
        final teamId = doc.id;
        teamStats[teamId] = StandingModel(
          teamId: teamId,
          teamName: data['name'] ?? 'Unknown',
          teamLogoUrl: data['logoUrl'],
          played: 0,
          won: 0,
          drawn: 0,
          lost: 0,
          goalsFor: 0,
          goalsAgainst: 0,
          points: 0,
          group: data['group'],
        );
      }

      // 3. Fetch All Matches (Completed OR Live)
      // Only include matches that BELONG to a group for standings table in Group format
      final matchesSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .get();

      debugPrint('Found ${matchesSnapshot.docs.length} total matches');

      final matches = matchesSnapshot.docs
          .map((doc) => MatchModel.fromSnapshot(doc))
          .where((m) {
            final status = m.status.trim().toLowerCase();
            return m.isFinished ||
                status == AppConstants.matchStatusLive ||
                status == 'final'; // Legacy support
          })
          .toList();

      debugPrint('Processing ${matches.length} matches for standings');

      // Secondary pass to assign groups to all teams even if no matches played yet
      // This helps show empty groups in the leaderboard
      final allMatches = matchesSnapshot.docs
          .map((doc) => MatchModel.fromSnapshot(doc))
          .toList();
      for (var m in allMatches) {
        if (m.group != null && m.group!.isNotEmpty) {
          if (teamStats.containsKey(m.team1Id) &&
              teamStats[m.team1Id]!.group == null) {
            final t = teamStats[m.team1Id]!;
            teamStats[m.team1Id] = StandingModel(
              teamId: t.teamId,
              teamName: t.teamName,
              teamLogoUrl: t.teamLogoUrl,
              played: t.played,
              won: t.won,
              drawn: t.drawn,
              lost: t.lost,
              goalsFor: t.goalsFor,
              goalsAgainst: t.goalsAgainst,
              points: t.points,
              group: m.group,
            );
          }
          if (teamStats.containsKey(m.team2Id) &&
              teamStats[m.team2Id]!.group == null) {
            final t = teamStats[m.team2Id]!;
            teamStats[m.team2Id] = StandingModel(
              teamId: t.teamId,
              teamName: t.teamName,
              teamLogoUrl: t.teamLogoUrl,
              played: t.played,
              won: t.won,
              drawn: t.drawn,
              lost: t.lost,
              goalsFor: t.goalsFor,
              goalsAgainst: t.goalsAgainst,
              points: t.points,
              group: m.group,
            );
          }
        }
      }

      debugPrint('Processing ${matches.length} matches for standings');

      // 4. Calculate Stats
      for (var match in matches) {
        if (match.actualScore == null) continue;

        // Robust parsing for scores (handle String or num)
        var t1ScoreRaw = match.actualScore!['team1'] ?? 0;
        var t2ScoreRaw = match.actualScore!['team2'] ?? 0;

        num t1Score = 0;
        num t2Score = 0;

        if (t1ScoreRaw is String) {
          t1Score = num.tryParse(t1ScoreRaw) ?? 0;
        } else if (t1ScoreRaw is num) {
          t1Score = t1ScoreRaw;
        } else {
          // Fallback for Cricket (t1Runs)
          var t1Runs = match.actualScore!['t1Runs'];
          if (t1Runs != null) {
            t1Score = t1Runs is String
                ? (num.tryParse(t1Runs) ?? 0)
                : (t1Runs as num);
          }
        }

        if (t2ScoreRaw is String) {
          t2Score = num.tryParse(t2ScoreRaw) ?? 0;
        } else if (t2ScoreRaw is num) {
          t2Score = t2ScoreRaw;
        } else {
          // Fallback for Cricket (t2Runs)
          var t2Runs = match.actualScore!['t2Runs'];
          if (t2Runs != null) {
            t2Score = t2Runs is String
                ? (num.tryParse(t2Runs) ?? 0)
                : (t2Runs as num);
          }
        }

        // Ensure teams exist (in case deleted or data mismatch)
        if (!teamStats.containsKey(match.team1Id)) {
          teamStats[match.team1Id] = StandingModel(
            teamId: match.team1Id,
            teamName: match.team1Name, // Fallback
            teamLogoUrl: null, // No logo from match
            played: 0,
            won: 0,
            drawn: 0,
            lost: 0,
            goalsFor: 0,
            goalsAgainst: 0,
            points: 0,
            group: match.group,
          );
        }
        if (!teamStats.containsKey(match.team2Id)) {
          teamStats[match.team2Id] = StandingModel(
            teamId: match.team2Id,
            teamName: match.team2Name, // Fallback
            teamLogoUrl: null, // No logo from match
            played: 0,
            won: 0,
            drawn: 0,
            lost: 0,
            goalsFor: 0,
            goalsAgainst: 0,
            points: 0,
            group: match.group,
          );
        }

        final t1 = teamStats[match.team1Id]!;
        final t2 = teamStats[match.team2Id]!;

        // Update Group (if not already set)
        final String? matchGroup = match.group;

        // Update Stats
        int t1Points = 0;
        int t2Points = 0;
        int t1Won = 0, t1Drawn = 0, t1Lost = 0, t1Tied = 0, t1NR = 0;
        int t2Won = 0, t2Drawn = 0, t2Lost = 0, t2Tied = 0, t2NR = 0;

        if (competition.sport == AppConstants.sportCricket) {
          final winnerId = match.resolvedWinnerId;
          if (winnerId == match.team1Id) {
            t1Points = competition.pointsForWin;
            t1Won = 1;
            t2Lost = 1;
          } else if (winnerId == match.team2Id) {
            t2Points = competition.pointsForWin;
            t2Won = 1;
            t1Lost = 1;
          } else if (winnerId == 'tied') {
            t1Points = competition.pointsForDraw;
            t2Points = competition.pointsForDraw;
            t1Tied = 1;
            t2Tied = 1;
          } else if (winnerId == 'no_result') {
            t1Points = 1; // Standard IPL point for NR
            t2Points = 1;
            t1NR = 1;
            t2NR = 1;
          } else if (match.actualScore != null &&
              match.actualScore!.isNotEmpty) {
            // Draw or No Result? For now assume Draw if score exists but no winner
            t1Points = competition.pointsForDraw;
            t2Points = competition.pointsForDraw;
            t1Drawn = 1;
            t2Drawn = 1;
          }
        } else {
          if (t1Score > t2Score) {
            t1Points = competition.pointsForWin;
            t2Points = competition.pointsForLoss;
            t1Won = 1;
            t2Lost = 1;
          } else if (t2Score > t1Score) {
            t2Points = competition.pointsForWin;
            t1Points = competition.pointsForLoss;
            t2Won = 1;
            t1Lost = 1;
          } else {
            t1Points = competition.pointsForDraw;
            t2Points = competition.pointsForDraw;
            t1Drawn = 1;
            t2Drawn = 1;
          }
        }

        // Parse Overs
        double t1OversRaw = 0.0;
        double t2OversRaw = 0.0;

        if (competition.sport == AppConstants.sportCricket) {
          t1OversRaw = (match.actualScore!['t1Overs'] is num)
              ? (match.actualScore!['t1Overs'] as num).toDouble()
              : (double.tryParse(
                      match.actualScore!['t1Overs']?.toString() ?? '0',
                    ) ??
                    0.0);

          t2OversRaw = (match.actualScore!['t2Overs'] is num)
              ? (match.actualScore!['t2Overs'] as num).toDouble()
              : (double.tryParse(
                      match.actualScore!['t2Overs']?.toString() ?? '0',
                    ) ??
                    0.0);
        }

        teamStats[match.team1Id] = StandingModel(
          teamId: t1.teamId,
          teamName: t1.teamName,
          teamLogoUrl: t1.teamLogoUrl,
          played: t1.played + 1,
          won: t1.won + t1Won,
          drawn: t1.drawn + t1Drawn,
          tied: t1.tied + t1Tied,
          noResult: t1.noResult + t1NR,
          lost: t1.lost + t1Lost,
          goalsFor: t1.goalsFor + t1Score.toInt(),
          goalsAgainst: t1.goalsAgainst + t2Score.toInt(),
          points: t1.points + t1Points,
          group: t1.group ?? matchGroup,
          oversFaced: _sumCricketOvers(t1.oversFaced, t1OversRaw),
          oversBowled: _sumCricketOvers(t1.oversBowled, t2OversRaw),
        );

        teamStats[match.team2Id] = StandingModel(
          teamId: t2.teamId,
          teamName: t2.teamName,
          teamLogoUrl: t2.teamLogoUrl,
          played: t2.played + 1,
          won: t2.won + t2Won,
          drawn: t2.drawn + t2Drawn,
          tied: t2.tied + t2Tied,
          noResult: t2.noResult + t2NR,
          lost: t2.lost + t2Lost,
          goalsFor: t2.goalsFor + t2Score.toInt(),
          goalsAgainst: t2.goalsAgainst + t1Score.toInt(),
          points: t2.points + t2Points,
          group: t2.group ?? matchGroup,
          oversFaced: _sumCricketOvers(t2.oversFaced, t2OversRaw),
          oversBowled: _sumCricketOvers(t2.oversBowled, t1OversRaw),
        );
      }

      // 5. Calculate Net Run Rate (NRR) for Cricket
      if (competition.sport == AppConstants.sportCricket) {
        for (var teamId in teamStats.keys) {
          final t = teamStats[teamId]!;
          double nrr = 0.0;

          // NRR = (Runs Scored / True Overs Faced) - (Runs Conceded / True Overs Bowled)
          double facedTrue = _cricketOversToTrueOvers(t.oversFaced);
          double bowledTrue = _cricketOversToTrueOvers(t.oversBowled);

          double forRate = (facedTrue > 0) ? (t.goalsFor / facedTrue) : 0.0;
          double againstRate = (bowledTrue > 0)
              ? (t.goalsAgainst / bowledTrue)
              : 0.0;

          nrr = forRate - againstRate;
          // Prevent NaN/Inf
          if (nrr.isNaN || nrr.isInfinite) nrr = 0.0;

          teamStats[teamId] = StandingModel(
            teamId: t.teamId,
            teamName: t.teamName,
            teamLogoUrl: t.teamLogoUrl,
            played: t.played,
            won: t.won,
            drawn: t.drawn,
            lost: t.lost,
            tied: t.tied,
            noResult: t.noResult,
            goalsFor: t.goalsFor,
            goalsAgainst: t.goalsAgainst,
            points: t.points,
            group: t.group,
            oversFaced: t.oversFaced,
            oversBowled: t.oversBowled,
            netRunRate: nrr,
          );
        }
      }

      // 6. Batch Write
      // 6. Batch Write
      final allTeams = teamStats.values.toList();
      final int batchSize = 400;

      for (int i = 0; i < allTeams.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < allTeams.length)
            ? i + batchSize
            : allTeams.length;
        final currentChunk = allTeams.sublist(i, end);

        final standingsRef = _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('standings');

        for (var team in currentChunk) {
          batch.set(standingsRef.doc(team.teamId), team.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to recalculate standings: $e');
    }
  }

  // ========== TEAMS ==========

  // ========== TEAMS ==========

  // Create a new team in the competition
  Future<void> createTeam(TeamModel team) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(team.competitionId)
          .collection('teams')
          .doc(team.id)
          .set(team.toMap());
    } catch (e) {
      throw Exception('Failed to create team: ${e.toString()}');
    }
  }

  // Update team
  Future<void> updateTeam(TeamModel team) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(team.competitionId)
          .collection('teams')
          .doc(team.id)
          .update(team.toMap());
    } catch (e) {
      throw Exception('Failed to update team: ${e.toString()}');
    }
  }

  // Get teams for competition
  Stream<List<TeamModel>> getTeams(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('teams')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TeamModel.fromSnapshot(doc)).toList(),
        );
  }

  // Delete team
  Future<void> deleteTeam(String competitionId, String teamId) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('teams')
          .doc(teamId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete team: ${e.toString()}');
    }
  }

  // ========== PREDICTIONS ==========

  // Submit prediction
  Future<String> submitPrediction(PredictionModel prediction) async {
    try {
      debugPrint(
        '🔮 Submitting prediction for Match: ${prediction.matchId}, User: ${prediction.userId}',
      );

      // 1. Check if prediction already exists
      QuerySnapshot existing = await _firestore
          .collection('predictions')
          .where('userId', isEqualTo: prediction.userId)
          .where('matchId', isEqualTo: prediction.matchId)
          .get();

      String predictionId;

      if (existing.docs.isNotEmpty) {
        predictionId = existing.docs.first.id;
        debugPrint('📝 Updating existing prediction: $predictionId');
        await _firestore
            .collection('predictions')
            .doc(predictionId)
            .update(prediction.toMap());
      } else {
        debugPrint('➕ Creating new prediction...');
        DocumentReference docRef = await _firestore
            .collection('predictions')
            .add(prediction.toMap());
        predictionId = docRef.id;

        // 2. Increment totalPredictions for participant
        // NOTE: This often fails in official tournaments due to restricted update rules
        // for subcollections under the competition document.
        // We wrap this in a separate try-catch so the prediction is still saved.
        try {
          debugPrint(
            '🔢 Incrementing stats for participant ${prediction.userId}...',
          );
          await _firestore
              .collection('competitions')
              .doc(prediction.competitionId)
              .collection('participants')
              .doc(prediction.userId)
              .update({'totalPredictions': FieldValue.increment(1)});
          debugPrint('✅ Stats incremented.');
        } catch (e) {
          debugPrint(
            '🛡️ Permission Warning: Could not increment totalPredictions for ${prediction.userId} in competition ${prediction.competitionId}. This is expected for some tournaments. Prediction remains saved.',
          );
        }
      }

      debugPrint('🎉 Prediction submitted successfully: $predictionId');
      return predictionId;
    } catch (e) {
      debugPrint('❌ Error in submitPrediction: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permission Denied: You do not have permission to submit predictions for this match. Please ensure you have joined the competition correctly.',
        );
      }
      throw Exception('Failed to submit prediction: ${e.toString()}');
    }
  }

  // Get user's predictions for a competition
  Stream<List<PredictionModel>> getUserPredictions(
    String userId,
    String competitionId,
  ) {
    return _firestore
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .where('competitionId', isEqualTo: competitionId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PredictionModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Get prediction for specific match (Single user)
  Future<PredictionModel?> getPredictionForMatch(
    String userId,
    String matchId,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('predictions')
          .where('userId', isEqualTo: userId)
          .where('matchId', isEqualTo: matchId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return PredictionModel.fromSnapshot(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get ALL predictions for a specific match (Admin)
  Future<List<PredictionModel>> getPredictionsForMatch(String matchId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('predictions')
          .where('matchId', isEqualTo: matchId)
          .get();

      return snapshot.docs
          .map((doc) => PredictionModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting predictions for match: $e');
      return [];
    }
  }

  // Update prediction points
  Future<void> updatePredictionPoints(String predictionId, int points) async {
    try {
      await _firestore.collection('predictions').doc(predictionId).update({
        'points': points,
        'isScored': true,
      });
    } catch (e) {
      throw Exception('Failed to update prediction points: ${e.toString()}');
    }
  }

  // ========== PARTICIPANTS ==========

  // Join competition
  Future<void> joinCompetition(
    String competitionId,
    ParticipantModel participant,
  ) async {
    if (competitionId.isEmpty || participant.userId.isEmpty) {
      throw Exception('Invalid competition or user ID');
    }

    try {
      // Ensure competitionId is correctly set in the participant record
      final participantData = participant.toMap();
      participantData['competitionId'] = competitionId;

      final compDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (compDoc.exists) {
        final competition = CompetitionModel.fromSnapshot(compDoc);
        if (competition.isFinished) {
          throw Exception('This competition has already finished.');
        }
      }

      final participantDocRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(participant.userId);

      // 1. Check if already joined (double-check for safety)
      final existingDoc = await participantDocRef.get();
      if (existingDoc.exists) {
        debugPrint(
          'ℹ️ User ${participant.userId} already joined $competitionId',
        );
        return;
      }

      // 2. Add participant to the subcollection
      debugPrint(
        '📝 Adding participant ${participant.userId} to $competitionId...',
      );
      await participantDocRef.set(participantData);
      debugPrint('✅ Participant added successfully.');

      // 3. Increment participant count on the main competition document
      // NOTE: This often fails in official tournaments due to restricted update rules
      // (only organizers or master admins can update the main doc).
      // We wrap this in a separate try-catch so joining still succeeds even if count update is denied.
      try {
        debugPrint('🔢 Incrementing participantCount for $competitionId...');
        await _firestore.collection('competitions').doc(competitionId).update({
          'participantCount': FieldValue.increment(1),
          'participantsCount': FieldValue.increment(
            1,
          ), // Added plural as fallback for some older data
        });
        debugPrint('✅ participantCount incremented successfully.');
      } catch (e) {
        debugPrint(
          '🛡️ Permission Warning: Could not increment participantCount for $competitionId: $e',
        );
        debugPrint(
          'This is expected for some restricted competitions where only admins can change the master document. The participant record itself has been created successfully.',
        );
      }
    } catch (e) {
      debugPrint('❌ Error in joinCompetition: $e');

      bool isPermissionDenied = false;
      if (e is FirebaseException && e.code == 'permission-denied') {
        isPermissionDenied = true;
      } else {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('permission-denied') ||
            errStr.contains('permission_denied')) {
          isPermissionDenied = true;
        }
      }

      if (isPermissionDenied) {
        throw Exception(
          'Permission Denied: You might not have permission to join this competition. If it is a restricted tournament, please contact the organizer.',
        );
      }
      throw Exception('Failed to join competition: ${e.toString()}');
    }
  }

  // Update participant photo
  Future<void> updateParticipantPhoto(
    String competitionId,
    String userId,
    String photoUrl,
  ) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .update({'photoUrl': photoUrl});
    } catch (e) {
      debugPrint('Error updating participant photo: $e');
    }
  }

  // Check if user has joined competition
  Future<bool> hasJoinedCompetition(String userId, String competitionId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get leaderboard for competition (Top 100)
  Stream<List<ParticipantModel>> getLeaderboard(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('participants')
        .orderBy('totalPoints', descending: true)
        .limit(100) // Optimization for large competitions
        .snapshots()
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getLeaderboard: $e');
          }
        })
        .map((snapshot) {
          List<ParticipantModel> participants = [];

          for (int i = 0; i < snapshot.docs.length; i++) {
            var doc = snapshot.docs[i];
            ParticipantModel participant = ParticipantModel.fromMap(doc.data());

            // Shared Ranking Logic (1, 2, 2, 4)
            int rank;
            if (i > 0 &&
                participant.totalPoints == participants[i - 1].totalPoints) {
              rank = participants[i - 1].rank;
            } else {
              rank = i + 1;
            }

            participants.add(participant.copyWith(rank: rank));
          }
          return participants;
        });
  }

  // Update participant points
  Future<void> updateParticipantPoints(
    String competitionId,
    String userId,
    int points,
  ) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(userId)
          .update({'totalPoints': FieldValue.increment(points)});
    } catch (e) {
      throw Exception('Failed to update participant points: ${e.toString()}');
    }
  }

  // Join competition by code
  Future<String?> joinCompetitionByCode(
    String joinCode,
    ParticipantModel participant,
  ) async {
    try {
      // Find competition by code
      final querySnapshot = await _firestore
          .collection('competitions')
          .where('joinCode', isEqualTo: joinCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid competition code');
      }

      final competitionDoc = querySnapshot.docs.first;
      final competitionId = competitionDoc.id;
      final competition = CompetitionModel.fromSnapshot(competitionDoc);

      if (competition.isFinished) {
        throw Exception('This competition has already finished.');
      }

      // organizers are now allowed to participate

      // Check if already joined
      final hasJoined = await hasJoinedCompetition(
        participant.userId,
        competitionId,
      );
      if (hasJoined) {
        return competitionId; // Already joined, just return ID
      }

      // Join
      await joinCompetition(competitionId, participant);

      return competitionId;
    } catch (e) {
      throw Exception(e.toString()); // Re-throw with clean message
    }
  }

  // Update user profile
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  // Delete User Account (Compliance)
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: ${e.toString()}');
    }
  }

  // ========== SEARCH & FILTER ==========

  // Search competitions by name
  Future<List<CompetitionModel>> searchCompetitions(String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('competitions')
          .where('status', isEqualTo: 'active')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20) // Limit search results to 20
          .get();

      return snapshot.docs
          .map((doc) => CompetitionModel.fromSnapshot(doc))
          .where((comp) => comp.deletedAt == null)
          .toList();
    } catch (e) {
      throw Exception('Failed to search competitions: ${e.toString()}');
    }
  }
  // ========== USER STATS ==========

  // Get all competitions a user has joined (and total stats)
  Future<Map<String, dynamic>> getUserCompetitionsAndStats(
    String userId,
  ) async {
    try {
      // Query all participant records for this user across all competitions
      final querySnapshot = await _firestore
          .collectionGroup('participants')
          .where('userId', isEqualTo: userId)
          .get();

      List<CompetitionModel> competitions = [];
      int totalPoints = 0;

      for (var doc in querySnapshot.docs) {
        // Get generic stats
        final data = doc.data();
        totalPoints += (data['totalPoints'] as int? ?? 0);

        // Get Competition Details
        // Parent is 'participants' collection, Parent.Parent is 'competitions' doc
        final competitionRef = doc.reference.parent.parent;
        if (competitionRef != null) {
          final compDoc = await competitionRef.get();
          if (compDoc.exists) {
            final competition = CompetitionModel.fromSnapshot(compDoc);
            if (competition.deletedAt == null) {
              competitions.add(competition);
            }
          }
        }
      }

      return {
        'competitions': competitions,
        'totalPoints': totalPoints,
        'competitionCount': competitions.length,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {'competitions': [], 'totalPoints': 0, 'competitionCount': 0};
    }
  }

  Stream<List<CompetitionModel>> getJoinedCompetitions(String userId) {
    // 1. Participant stream (can fail due to missing index)
    final participantStream = _firestore
        .collectionGroup('participants')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs)
        .onErrorReturnWith((e, s) {
          debugPrint('!!! ERROR: getJoinedCompetitions Participant Query: $e');
          return [];
        });

    // 2. Organized stream (reliable)
    final organizedStream = _firestore
        .collection('competitions')
        .where('organizerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs)
        .onErrorReturnWith((e, s) {
          debugPrint('!!! ERROR: getJoinedCompetitions Organized Query: $e');
          return [];
        });

    // Combine both
    return Rx.combineLatest2<
          List<QueryDocumentSnapshot>,
          List<QueryDocumentSnapshot>,
          List<List<QueryDocumentSnapshot>>
        >(participantStream, organizedStream, (a, b) => [a, b])
        .asyncMap((combinedDocs) async {
          final participantDocs = combinedDocs[0];
          final organizedDocs = combinedDocs[1];
          final Map<String, CompetitionModel> competitionsMap = {};

          // Process organized first (they are definitely valid)
          for (var doc in organizedDocs) {
            final comp = CompetitionModel.fromSnapshot(doc);
            if (comp.deletedAt == null) {
              competitionsMap[comp.id] = comp;
            }
          }

          // Process participants
          for (var doc in participantDocs) {
            final data = doc.data() as Map<String, dynamic>;
            String? compId = data['competitionId'];

            if (compId == null || compId.isEmpty) {
              final parts = doc.reference.path.split('/');
              if (parts.length >= 2) compId = parts[1];
            }

            if (compId != null &&
                compId.isNotEmpty &&
                !competitionsMap.containsKey(compId)) {
              final compDoc = await _firestore
                  .collection('competitions')
                  .doc(compId)
                  .get();
              if (compDoc.exists) {
                final comp = CompetitionModel.fromSnapshot(compDoc);
                if (comp.deletedAt == null) {
                  competitionsMap[compId] = comp;
                }
              }
            }
          }

          final sortedList = competitionsMap.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return sortedList;
        })
        .shareReplay(maxSize: 1);
  }

  // ========== GLOBAL TEAM LIBRARY ==========

  // Create Global Team
  Future<void> createGlobalTeam(String organizerId, TeamModel team) async {
    try {
      await _firestore
          .collection('organizers')
          .doc(organizerId)
          .collection('team_library')
          .doc(team.id)
          .set(team.toMap());
    } catch (e) {
      throw Exception('Failed to create global team: ${e.toString()}');
    }
  }

  // Update Global Team
  Future<void> updateGlobalTeam(String organizerId, TeamModel team) async {
    try {
      await _firestore
          .collection('organizers')
          .doc(organizerId)
          .collection('team_library')
          .doc(team.id)
          .update(team.toMap());
    } catch (e) {
      throw Exception('Failed to update global team: ${e.toString()}');
    }
  }

  // Delete Global Team
  Future<void> deleteGlobalTeam(String organizerId, String teamId) async {
    try {
      await _firestore
          .collection('organizers')
          .doc(organizerId)
          .collection('team_library')
          .doc(teamId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete global team: ${e.toString()}');
    }
  }

  // Get Global Teams
  Stream<List<TeamModel>> getGlobalTeams(String organizerId) {
    return _firestore
        .collection('organizers')
        .doc(organizerId)
        .collection('team_library')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TeamModel.fromSnapshot(doc)).toList(),
        );
  }

  // Copy Global Teams to Competition
  Future<void> copyGlobalTeamsToCompetition(
    String competitionId,
    List<TeamModel> teams, {
    String? group,
  }) async {
    try {
      final batch = _firestore.batch();
      final teamsRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('teams');

      for (var team in teams) {
        // Create a new ref for the competition instance of this team
        final newDocRef = teamsRef.doc();
        // Create a copy of the team with the new competitionId and new ID
        final newTeam = team.copyWith(
          id: newDocRef.id,
          competitionId: competitionId,
          group: group,
        );
        batch.set(newDocRef, newTeam.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to copy teams: ${e.toString()}');
    }
  }

  // Delete all teams from a specific tournament in the library
  Future<void> deleteGlobalTournament(
    String organizerId,
    String tournamentName,
  ) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(organizerId)
          .collection('team_library')
          .where('competitionName', isEqualTo: tournamentName)
          .get();

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete tournament teams: ${e.toString()}');
    }
  }

  // --- Automated Tournament Discovery ---

  Future<DateTime?> getLastTournamentSyncAt() async {
    final doc = await _firestore
        .collection('app_metadata')
        .doc('tournament_sync_lock')
        .get();
    if (doc.exists) {
      final ts = doc.data()?['lastSyncAt'] as Timestamp?;
      return ts?.toDate();
    }
    return null;
  }

  // --- CricAPI Cached Series Search ---
  Future<List<Map<String, dynamic>>?> getSeriesListCache() async {
    final doc = await _firestore
        .collection('app_metadata')
        .doc('cric_series_cache')
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      final ts = (data['cachedAt'] as Timestamp).toDate();
      // Cache valid for 12 hours
      if (DateTime.now().difference(ts).inHours < 12) {
        return List<Map<String, dynamic>>.from(data['series']);
      }
    }
    return null;
  }

  Future<void> saveSeriesListCache(List<Map<String, dynamic>> series) async {
    await _firestore.collection('app_metadata').doc('cric_series_cache').set({
      'cachedAt': FieldValue.serverTimestamp(),
      'series': series,
    });
  }

  Future<bool> isSeriesVerified(String seriesId) async {
    final doc = await _firestore
        .collection('verified_cricket_series')
        .doc(seriesId)
        .get();
    return doc.exists;
  }

  Future<void> markSeriesVerified(String seriesId) async {
    await _firestore.collection('verified_cricket_series').doc(seriesId).set({
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> tryAcquireScoreUpdateLock(
    String leagueId, {
    bool isLive = false,
  }) async {
    final lockRef = _firestore
        .collection('official_leagues')
        .doc(leagueId)
        .collection('meta')
        .doc('sync_lock');

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(lockRef);
        final now = DateTime.now();

        if (snapshot.exists) {
          final data = snapshot.data();
          final lockedAt = (data?['lockedAt'] as Timestamp?)?.toDate();
          final lastSyncAt = (data?['lastSyncAt'] as Timestamp?)?.toDate();

          // 1. Double-Lock Prevention (within 5 mins)
          if (lockedAt != null && now.difference(lockedAt).inMinutes < 5) {
            return false;
          }

          // 2. Smart Stale Window
          // If match is LIVE: 2-minute window (Fast updates)
          // If match is OFF: 5-minute window (Periodic Sync)
          final windowMinutes = isLive ? 2 : 5;

          if (lastSyncAt != null &&
              now.difference(lastSyncAt).inMinutes < windowMinutes) {
            return false;
          }
        }

        // 3. Acquire lock to be the "Volunteer Drone"
        transaction.set(lockRef, {
          'lockedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  Future<void> releaseScoreUpdateLock(
    String leagueId, {
    bool success = true,
  }) async {
    final lockRef = _firestore
        .collection('official_leagues')
        .doc(leagueId)
        .collection('meta')
        .doc('sync_lock');
    final data = <String, dynamic>{'lockedAt': null};
    if (success) {
      data['lastSyncAt'] = Timestamp.fromDate(DateTime.now());
    }
    await lockRef.set(data, SetOptions(merge: true));
  }

  Future<void> updateOfficialLeagueMatches(
    String leagueId,
    List<MatchModel> matches,
  ) async {
    final batch = _firestore.batch();
    final colRef = _firestore
        .collection('official_leagues')
        .doc(leagueId)
        .collection('matches');

    for (var m in matches) {
      // Use logical ID based on teams to ensure stable document IDs
      final docId = '${m.team1Id}_${m.team2Id}';
      batch.set(colRef.doc(docId), {
        'id': m.id,
        'team1Id': m.team1Id,
        'team2Id': m.team2Id,
        'team1Name': m.team1Name,
        'team2Name': m.team2Name,
        'scheduledTime': Timestamp.fromDate(m.scheduledTime),
        'status': m.status,
        'actualScore': m.actualScore,
        'round': m.round,
        'matchNumber': m.matchNumber,
        'group': m.group,
        'location': m.location,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<bool> tryAcquireTournamentSyncLock() async {
    final lockRef = _firestore
        .collection('app_metadata')
        .doc('tournament_sync_lock');

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(lockRef);
        final now = DateTime.now();

        if (snapshot.exists) {
          final data = snapshot.data();
          final lockedAt = (data?['lockedAt'] as Timestamp?)?.toDate();
          final lastSyncAt = (data?['lastSyncAt'] as Timestamp?)?.toDate();

          // 1. Check if a sync is currently "In Progress" (within last 10 mins)
          if (lockedAt != null && now.difference(lockedAt).inMinutes < 10) {
            return false; // Someone else is currently syncing
          }

          // 2. Check if the 30-day cooldown has passed
          if (lastSyncAt != null && now.difference(lastSyncAt).inDays < 30) {
            return false; // Too soon for a new sync
          }
        }

        // 3. Acquire lock
        transaction.set(lockRef, {
          'lockedAt': Timestamp.fromDate(now),
          'lockedBy': 'client_instance',
        }, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      debugPrint('Lock acquisition error: $e');
      return false;
    }
  }

  Future<void> releaseTournamentSyncLock({bool success = true}) async {
    final lockRef = _firestore
        .collection('app_metadata')
        .doc('tournament_sync_lock');
    final Map<String, dynamic> data = {'lockedAt': null, 'lockedBy': null};
    if (success) {
      data['lastSyncAt'] = Timestamp.fromDate(DateTime.now());
    }
    await lockRef.set(data, SetOptions(merge: true));
  }

  Future<void> updateTournamentSyncAt(DateTime time) async {
    // This is now handled by releaseTournamentSyncLock
  }

  Future<void> saveDiscoveredTournaments(
    List<OfficialTournamentModel> tournaments,
  ) async {
    final batch = _firestore.batch();
    final colRef = _firestore.collection('discovered_tournaments');

    for (var t in tournaments) {
      batch.set(colRef.doc(t.id), {
        'id': t.id,
        'name': t.name,
        'country': t.country,
        'sport': t.sport,
        'logoUrl': t.logoUrl,
        'source': t.source,
        'externalId': t.externalId,
        'status': t.status,
        'hasFixtures': t.hasFixtures,
        'discoveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<List<OfficialTournamentModel>> getDiscoveredTournaments() async {
    final query = await _firestore
        .collection('discovered_tournaments')
        .where('hasFixtures', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      return OfficialTournamentModel(
        id: data['id'],
        name: data['name'],
        country: data['country'],
        sport: data['sport'],
        logoUrl: data['logoUrl'],
        source: data['source'] ?? 'fixturedownload',
        externalId: data['externalId'],
        status: data['status'] ?? 'active',
        hasFixtures: data['hasFixtures'] ?? false,
      );
    }).toList();
  }

  /// Master Delete: Removes a tournament from both registry and official data
  /// Also adds it to a blacklist to prevent it from reappearing if hardcoded or re-scraped
  Future<void> masterDeleteTournament(String tournamentId) async {
    try {
      final batch = _firestore.batch();

      // 1. Remove from Discovered Registry
      batch.delete(
        _firestore.collection('discovered_tournaments').doc(tournamentId),
      );

      // 2. Remove from Official Leagues matches subcollection (requires fetching first)
      final matchesQuery = await _firestore
          .collection('official_leagues')
          .doc(tournamentId)
          .collection('matches')
          .get();

      for (var doc in matchesQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Remove from Official Leagues root
      batch.delete(_firestore.collection('official_leagues').doc(tournamentId));

      // 4. Add to Blacklist (New)
      batch.set(
        _firestore.collection('blacklisted_tournaments').doc(tournamentId),
        {'blacklistedAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();
      debugPrint('Master deleted/blacklisted tournament: $tournamentId');
    } catch (e) {
      debugPrint('Error master deleting tournament: $e');
      throw Exception('Master delete failed: $e');
    }
  }

  // Get Blacklisted IDs
  Future<Set<String>> getBlacklistedTournamentIds() async {
    try {
      final snapshot = await _firestore
          .collection('blacklisted_tournaments')
          .get();
      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('Error fetching blacklist: $e');
      return {};
    }
  }

  // Update multiple matches (for sync/refresh)
  Future<void> updateBatchMatches(
    String competitionId,
    List<MatchModel> updates,
  ) async {
    final batch = _firestore.batch();
    final colRef = _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('matches');

    for (var match in updates) {
      batch.update(colRef.doc(match.id), match.toMap());
    }
    await batch.commit();
  }

  // Sum two cricket over values (e.g. 10.3 + 0.3 = 11.0)
  double _sumCricketOvers(double a, double b) {
    int balls = _getBallsFromOvers(a) + _getBallsFromOvers(b);
    return (balls ~/ 6) + (balls % 6) / 10.0;
  }

  Future<int> resetCompetitionScores(String competitionId) async {
    try {
      final query = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint('Found ${query.docs.length} matches to reset');

      var batch = _firestore.batch();
      int count = 0;
      int totalReset = 0;

      for (var doc in query.docs) {
        batch.update(doc.reference, {
          'actualScore': null,
          'status': 'scheduled',
        });
        count++;
        totalReset++;

        // Commit batches of 400 (limit is 500)
        if (count >= 400) {
          await batch.commit().timeout(const Duration(seconds: 10));
          batch = _firestore.batch();
          count = 0;
          debugPrint('Committed batch of 400');
        }
      }
      if (count > 0) {
        await batch.commit().timeout(const Duration(seconds: 10));
        debugPrint('Committed final batch of $count');
      }

      // Also reset Standings
      await recalculateStandings(competitionId);

      // Disconnect from official league/schedule to prevent auto-sync overwriting our reset
      // This effectively converts it to a Custom Competition where the organizer manages scores manually.
      await _firestore.collection('competitions').doc(competitionId).update({
        'leagueId': null,
      });

      debugPrint(
        'Reset scores, standings, and disconnected league for $competitionId',
      );
      return totalReset;
    } catch (e) {
      debugPrint('Error resetting scores: $e');
      rethrow;
    }
  }

  // Get all predictions for a competition (For PDF Generation)
  Future<List<PredictionModel>> getCompetitionPredictions(
    String competitionId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('predictions')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      return snapshot.docs
          .map((doc) => PredictionModel.fromSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting competition predictions: $e');
      return [];
    }
  }

  // Recalculate all participant stats from scratch (Repair Tool)
  Future<void> recalculateParticipantStats(String competitionId) async {
    debugPrint('Recalculating participant stats for $competitionId');
    try {
      final competitionDoc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();
      if (!competitionDoc.exists) return;
      final competition = CompetitionModel.fromSnapshot(competitionDoc);
      final pointsForWinner = competition.rules['correctWinner'] ?? 3;
      final pointsForScore = competition.rules['correctScore'] ?? 2;

      // 1. Get all matches
      final matchesSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .get();
      final matches = matchesSnapshot.docs
          .map((d) => MatchModel.fromSnapshot(d))
          .toList();
      final matchesMap = {for (var m in matches) m.id: m};

      // 2. Get all participants
      final participantsSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .get();

      // 3. Get all predictions
      final predictionsSnapshot = await _firestore
          .collection('predictions')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      // Initialize Stats Map
      final Map<String, Map<String, dynamic>> userStats = {};
      final Map<String, DocumentReference> userRefs = {};

      for (var doc in participantsSnapshot.docs) {
        final uid = doc.data()['userId'] as String;
        userStats[uid] = {
          'totalPoints': 0,
          'correctOutcomes': 0,
          'perfectScores': 0,
          'totalPredictions': 0,
        };
        userRefs[uid] = doc.reference;
      }

      // Prepare Prediction Updates
      final List<Map<String, dynamic>> predictionUpdates = [];
      final List<DocumentReference> predictionUpdateRefs = [];

      // DEBUG: Log all match statuses
      debugPrint('═══ ALL MATCHES IN COMPETITION ═══');
      for (var m in matches) {
        debugPrint(
          '  Match#${m.matchNumber}: ${m.team1Name} vs ${m.team2Name} | status="${m.status}" | hasScore=${m.actualScore != null} | winnerId=${m.winnerId}',
        );
      }
      debugPrint(
        'Total matches: ${matches.length}, Completed/Ended: ${matches.where((m) => m.isFinished).length}',
      );
      debugPrint('═══════════════════════════════════');

      // Process Predictions
      for (var doc in predictionsSnapshot.docs) {
        final pred = PredictionModel.fromSnapshot(doc);
        final match = matchesMap[pred.matchId];
        final uid = pred.userId;

        if (match == null) continue;
        if (!userStats.containsKey(uid)) continue;

        // Increment total predictions
        userStats[uid]!['totalPredictions'] =
            (userStats[uid]!['totalPredictions'] as int) + 1;

        // Calculate Points if completed/ended OR manually verified
        if (match.isFinished && match.actualScore != null) {
          int points = 0;
          bool isCorrectOutcome = false;
          bool isPerfectScore = false;

          final predScore = pred.prediction;
          final actualScore = match.actualScore!;

          // --- Calculation Logic ---
          if (competition.sport == AppConstants.sportCricket) {
            String? actualWinnerId = actualScore['winnerId'];
            final String? predWinnerId = predScore['winnerId'];
            String? startMarginType = actualScore['marginType'];
            final String? actualMarginValue = actualScore['marginValue']
                ?.toString();

            // Find participant name for logging
            String logUserName = uid.substring(0, 6);
            for (var pDoc in participantsSnapshot.docs) {
              if (pDoc.data()['userId'] == uid) {
                logUserName = pDoc.data()['userName'] ?? uid.substring(0, 6);
                break;
              }
            }

            debugPrint(
              '━━━ SCORING: $logUserName | Match#${match.matchNumber}: ${match.team1Name} vs ${match.team2Name} ━━━',
            );
            debugPrint('  actualScore MAP: $actualScore');
            debugPrint('  predScore MAP: $predScore');
            debugPrint(
              '  Raw: actualWinnerId=$actualWinnerId, predWinnerId=$predWinnerId',
            );
            debugPrint(
              '  Raw: marginType=$startMarginType, marginValue=$actualMarginValue',
            );
            debugPrint(
              '  Match IDs: team1=${match.team1Id}, team2=${match.team2Id}',
            );

            // 1. Resolve winner ID: API stores slugs (e.g., "south_africa"),
            //    but predictions store UUIDs. Map slug → UUID using team names.
            if (actualWinnerId != null &&
                actualWinnerId != 'tied' &&
                actualWinnerId != 'no_result' &&
                !actualWinnerId.contains('-')) {
              final originalSlug = actualWinnerId;
              final slug = actualWinnerId.toLowerCase().replaceAll('_', '');
              final t1n = match.team1Name
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .replaceAll('_', '');
              final t2n = match.team2Name
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .replaceAll('_', '');
              if (t1n.contains(slug) || slug.contains(t1n)) {
                actualWinnerId = match.team1Id;
                debugPrint(
                  '  RESOLVED winner slug "$originalSlug" → ${match.team1Id} (${match.team1Name})',
                );
              } else if (t2n.contains(slug) || slug.contains(t2n)) {
                actualWinnerId = match.team2Id;
                debugPrint(
                  '  RESOLVED winner slug "$originalSlug" → ${match.team2Id} (${match.team2Name})',
                );
              }
            }

            // 2. Infer Winner if missing (for older/incomplete match data)
            if (actualWinnerId == null && actualScore['t1Runs'] != null) {
              final t1 =
                  int.tryParse(actualScore['t1Runs']?.toString() ?? '0') ?? 0;
              final t2 =
                  int.tryParse(actualScore['t2Runs']?.toString() ?? '0') ?? 0;
              if (t1 > t2) {
                actualWinnerId = match.team1Id;
                debugPrint(
                  '  INFERRED Winner: team1 (${match.team1Name}) because $t1 > $t2',
                );
              } else if (t2 > t1) {
                actualWinnerId = match.team2Id;
                debugPrint(
                  '  INFERRED Winner: team2 (${match.team2Name}) because $t2 > $t1',
                );
              } else if (t1 == t2) {
                actualWinnerId = 'tied';
                debugPrint('  INFERRED Winner: tied because $t1 == $t2');
              }
            }

            // 2. Check Winner Points
            debugPrint(
              '  WINNER CHECK: actual=$actualWinnerId vs pred=$predWinnerId => match=${actualWinnerId == predWinnerId}',
            );
            if (actualWinnerId != null &&
                predWinnerId != null &&
                actualWinnerId == predWinnerId) {
              points = pointsForWinner;
              isCorrectOutcome = true;
              debugPrint('  ✅ Winner CORRECT: +$pointsForWinner pts');
            } else {
              debugPrint('  ❌ Winner WRONG: +0 pts');
            }

            // 3. Infer Margin Type if missing (Fix for 'null' marginType issue)
            if (startMarginType == null && actualMarginValue != null) {
              final val = int.tryParse(actualMarginValue) ?? -1;
              final t1 =
                  int.tryParse(actualScore['t1Runs']?.toString() ?? '0') ?? 0;
              final t2 =
                  int.tryParse(actualScore['t2Runs']?.toString() ?? '0') ?? 0;
              final diffRuns = (t1 - t2).abs();

              // Use Batting First to determine margin type (Standard Cricket Rules)
              final String? battingFirstId = actualScore['battingFirstId'];
              debugPrint(
                '  INFER marginType: battingFirstId=$battingFirstId, diffRuns=$diffRuns, marginVal=$val',
              );
              if (battingFirstId != null && actualWinnerId != null) {
                if (battingFirstId == actualWinnerId) {
                  startMarginType = 'runs';
                  debugPrint(
                    '  INFERRED marginType=runs (winner batted first)',
                  );
                } else {
                  startMarginType = 'wickets';
                  debugPrint('  INFERRED marginType=wickets (winner chased)');
                }
              } else {
                // Fallback: Infer from values
                debugPrint('  FALLBACK inference (no battingFirstId)');
                if (val == diffRuns) {
                  startMarginType = 'runs';
                  debugPrint(
                    '  INFERRED marginType=runs (val $val == diffRuns $diffRuns)',
                  );
                } else {
                  final w1 =
                      int.tryParse(
                        actualScore['t1Wickets']?.toString() ?? '0',
                      ) ??
                      0;
                  final w2 =
                      int.tryParse(
                        actualScore['t2Wickets']?.toString() ?? '0',
                      ) ??
                      0;
                  final rem1 = 10 - w1;
                  final rem2 = 10 - w2;
                  debugPrint(
                    '  Wicket check: val=$val, rem1=$rem1, rem2=$rem2',
                  );
                  if (val == rem1 || val == rem2) {
                    startMarginType = 'wickets';
                    debugPrint(
                      '  INFERRED marginType=wickets (val matches remaining wickets)',
                    );
                  } else {
                    debugPrint('  ⚠️ Could NOT infer marginType!');
                  }
                }
              }
            }

            // 4. Prepare for Margin Check
            final String? predRuns = predScore['runs']?.toString();
            final String? predWickets = predScore['wickets']?.toString();
            bool marginCorrect = false;

            debugPrint(
              '  MARGIN CHECK: marginType=$startMarginType, actualVal=$actualMarginValue, predRuns=$predRuns, predWickets=$predWickets',
            );

            if (startMarginType != null && actualMarginValue != null) {
              String cleanMarginType = startMarginType.toLowerCase();
              if (cleanMarginType == 'runs' && predRuns != null) {
                marginCorrect = _checkMargin(
                  actualMarginValue,
                  predRuns,
                  'runs',
                );
                debugPrint(
                  '  Runs margin check: actual=$actualMarginValue vs pred=$predRuns => $marginCorrect',
                );
              } else if (cleanMarginType == 'wickets' && predWickets != null) {
                marginCorrect = _checkMargin(
                  actualMarginValue,
                  predWickets,
                  'wickets',
                );
                debugPrint(
                  '  Wickets margin check: actual=$actualMarginValue vs pred=$predWickets => $marginCorrect',
                );
              } else {
                debugPrint(
                  '  ⚠️ Margin type=$cleanMarginType but predRuns=$predRuns, predWickets=$predWickets - no check possible',
                );
              }
            }
            // Treat super over as a tie for scoring purposes
            final String? actualMarginType = actualScore['marginType'];
            final bool isSuperOver =
                actualMarginType?.toLowerCase() == 'super_over';

            if (actualWinnerId == 'tied' && predWinnerId == 'tied') {
              marginCorrect = true;
              debugPrint(
                '  Tied match + predicted tied => margin auto-correct',
              );
            } else if (isSuperOver && predWinnerId == 'tied') {
              // Super over match: user predicted tie, award full points
              marginCorrect = true;
              isCorrectOutcome = true;
              points =
                  pointsForWinner; // Award winner points for predicting tie
              debugPrint(
                '  Super over match + predicted tied => awarding full 5 points (treating as tie)',
              );
            }

            if (marginCorrect &&
                (isCorrectOutcome || actualWinnerId == 'tied' || isSuperOver)) {
              points += pointsForScore;
              if (isCorrectOutcome) isPerfectScore = true;
              debugPrint(
                '  ✅ Margin CORRECT: +$pointsForScore pts (total=$points, perfect=$isPerfectScore)',
              );
            } else {
              debugPrint(
                '  ❌ Margin NOT awarded (marginCorrect=$marginCorrect, isCorrectOutcome=$isCorrectOutcome)',
              );
            }
            debugPrint(
              '  FINAL: $logUserName => $points pts for Match#${match.matchNumber}',
            );
            debugPrint('');
          } else {
            // Football / Default Logic - Standardized
            final act1 = actualScore['team1'];
            final act2 = actualScore['team2'];
            final pr1 = predScore['team1'];
            final pr2 = predScore['team2'];

            final actualHome = int.tryParse(act1?.toString() ?? '0') ?? 0;
            final actualAway = int.tryParse(act2?.toString() ?? '0') ?? 0;
            final predHome = int.tryParse(pr1?.toString() ?? '0') ?? 0;
            final predAway = int.tryParse(pr2?.toString() ?? '0') ?? 0;

            // Determine Outcomes
            final bool actualIsTie =
                (actualScore['marginType']?.toLowerCase() == 'tie') ||
                (act1 != null && actualHome == actualAway);
            final bool predIsTie =
                (predScore['isTie'] == true) ||
                (pr1 != null && predHome == predAway);

            bool outcomeMatches = false;
            if (actualIsTie && predIsTie) {
              outcomeMatches = true;
            } else if (!actualIsTie && !predIsTie) {
              if (actualHome > actualAway && predHome > predAway) {
                outcomeMatches = true;
              } else if (actualAway > actualHome && predAway > predHome) {
                outcomeMatches = true;
              }
            }

            if (outcomeMatches) {
              points = pointsForWinner;
              isCorrectOutcome = true;
              debugPrint('  Outcome: CORRECT');

              // Check for Perfect Score
              if (actualHome == predHome && actualAway == predAway) {
                points += pointsForScore;
                isPerfectScore = true;
                debugPrint('  Score: PERFECT (+ $pointsForScore)');
              }
            } else {
              debugPrint('  Outcome: INCORRECT');
            }
          }
          // --- End Calculation Logic ---

          userStats[uid]!['totalPoints'] =
              (userStats[uid]!['totalPoints'] as int) + points;
          if (isCorrectOutcome) {
            userStats[uid]!['correctOutcomes'] =
                (userStats[uid]!['correctOutcomes'] as int) + 1;
          }
          if (isPerfectScore) {
            userStats[uid]!['perfectScores'] =
                (userStats[uid]!['perfectScores'] as int) + 1;
          }

          // Queue Prediction Update
          predictionUpdates.add({
            'points': points,
            'isScored': true,
            'wasPerfectScore': isPerfectScore,
            'wasCorrectOutcome': isCorrectOutcome,
          });
          predictionUpdateRefs.add(doc.reference);
        } else {
          debugPrint(
            '⏭️ SKIPPED: Match#${match.matchNumber} ${match.team1Name} vs ${match.team2Name} | status="${match.status}" hasScore=${match.actualScore != null} | user=$uid',
          );
        }
      }

      // Assign Ranks
      final sortedUids = userStats.keys.toList()
        ..sort((a, b) {
          int pA = userStats[a]!['totalPoints'] as int;
          int pB = userStats[b]!['totalPoints'] as int;
          return pB.compareTo(pA);
        });

      for (int i = 0; i < sortedUids.length; i++) {
        final uid = sortedUids[i];
        if (i > 0) {
          final prevUid = sortedUids[i - 1];
          if (userStats[uid]!['totalPoints'] ==
              userStats[prevUid]!['totalPoints']) {
            userStats[uid]!['rank'] = userStats[prevUid]!['rank'];
          } else {
            userStats[uid]!['rank'] = i + 1;
          }
        } else {
          userStats[uid]!['rank'] = 1;
        }
      }

      // Batch Update 1: Participants
      int batchCount = 0;
      var batch = _firestore.batch();
      final updates = userStats.entries.toList();

      for (var i = 0; i < updates.length; i++) {
        final entry = updates[i];
        if (userRefs.containsKey(entry.key)) {
          batch.update(userRefs[entry.key]!, entry.value);
          batchCount++;
          if (batchCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }
      if (batchCount > 0) {
        await batch.commit();
      }

      // Batch Update 2: Predictions
      batch = _firestore.batch(); // New batch
      batchCount = 0; // Reset count

      for (var i = 0; i < predictionUpdates.length; i++) {
        batch.update(predictionUpdateRefs[i], predictionUpdates[i]);
        batchCount++;
        if (batchCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint(
        'Recalculation complete for ${updates.length} participants and ${predictionUpdates.length} predictions.',
      );
    } catch (e) {
      debugPrint('Error recalculating stats: $e');
      rethrow;
    }
  }

  // Convert Cricket Overs (10.3) to True Overs (10.5)
  double _cricketOversToTrueOvers(double overs) {
    return _getBallsFromOvers(overs) / 6.0;
  }

  int _getBallsFromOvers(double overs) {
    int o = overs.toInt();
    int b = ((overs - o) * 10).round();
    return (o * 6) + b;
  }

  // Check if a match is finished (handles both 'completed' and 'Match Ended')
  bool _isMatchFinished(String status) {
    final s = status.toLowerCase().trim();
    return s == AppConstants.matchStatusCompleted.toLowerCase() ||
        s == 'match ended' ||
        s == 'ft' ||
        s == 'finished' ||
        s == 'final';
  }

  // Check if margin is correct (handles Ranges for Runs)
  bool _checkMargin(String actual, String predicted, String type) {
    if (type.toLowerCase() == 'wickets') {
      return actual == predicted;
    }
    // Runs - Check for Range
    final actualVal = int.tryParse(actual);
    if (actualVal == null) return actual == predicted;

    if (predicted.contains('+')) {
      final threshold = int.tryParse(predicted.replaceAll('+', '').trim()) ?? 0;
      return actualVal >= threshold;
    }
    if (predicted.contains('-')) {
      final parts = predicted.split('-');
      if (parts.length == 2) {
        final min = int.tryParse(parts[0].trim()) ?? 0;
        final max = int.tryParse(parts[1].trim()) ?? 0;
        return actualVal >= min && actualVal <= max;
      }
    }
    return actual == predicted;
  }
}
