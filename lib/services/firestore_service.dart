import 'package:flutter/foundation.dart';
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
import 'tournament_data_service.dart';

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
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('messages')
          .add(message.toMap());
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
      await _firestore.collection('competitions').doc(competitionId).update({
        'participantCount': FieldValue.increment(-1),
      });
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
  Future<String> createCompetition(CompetitionModel competition) async {
    try {
      // Generate a unique 6-digit code
      String joinCode = _generateJoinCode();

      // Ideally check for uniqueness here, skipping for MVP as 36^6 is large enough

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
    return List.generate(
      6,
      (index) => chars[DateTime.now().microsecond % chars.length],
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

      // Throttling: Max once every 5 seconds (for debugging)
      final lastSync = compDoc.data()?['lastSyncTime'] as Timestamp?;
      if (lastSync != null) {
        final now = DateTime.now();
        if (now.difference(lastSync.toDate()).inSeconds < 5) {
          debugPrint('Sync throttled for $competitionId');
          return;
        }
      }

      // Fetch teams (needed for mapping in getLatestScores)
      final teams = await getTeams(competitionId).first;

      // Fetch latest scores from external feed
      final externalMatches = await TournamentDataService.getLatestScores(
        competitionId,
        leagueId,
        teams,
      );

      if (externalMatches.isEmpty) return;

      // Fetch internal matches
      final internalMatches = await getMatches(competitionId).first;

      debugPrint(
        'Sync: Fetched ${externalMatches.length} external matches, ${internalMatches.length} internal matches.',
      );

      bool anyUpdate = false;
      final batch = _firestore.batch();

      for (var ext in externalMatches) {
        // Find internal match
        int intMatchIndex = -1;
        bool isReverse = false;

        // PRIORITY 1: Match by Teams (Unique Pairing) - Bidirectional
        intMatchIndex = internalMatches.indexWhere((m) {
          return (m.team1Id == ext.team1Id && m.team2Id == ext.team2Id);
        });

        if (intMatchIndex == -1) {
          intMatchIndex = internalMatches.indexWhere((m) {
            return (m.team1Id == ext.team2Id && m.team2Id == ext.team1Id);
          });
          if (intMatchIndex != -1) {
            isReverse = true;
          }
        }

        // PRIORITY 2: Match Number (Fallback only)
        if (intMatchIndex == -1 && ext.matchNumber != null) {
          intMatchIndex = internalMatches.indexWhere(
            (m) => m.matchNumber == ext.matchNumber,
          );
        }

        if (intMatchIndex == -1) {
          // debugPrint(
          //   'SYNC: ❌ Match NOT FOUND: "${ext.team1Name}" vs "${ext.team2Name}"',
          // );
          continue;
        }

        final intMatch = internalMatches[intMatchIndex];

        // Prepare correct external score based on direction
        Map<String, dynamic>? extScore = ext.actualScore;
        if (isReverse && extScore != null) {
          extScore = {
            'team1': extScore['team2'],
            'team2': extScore['team1'],
            'winnerId': extScore['winnerId'],
          };
        }

        // DEBUG: Print Comparison
        // debugPrint(
        //   'SYNC CHECK: ${intMatch.team1Name} vs ${intMatch.team2Name}',
        // );
        // debugPrint(
        //   '   INTERNAL: Status=${intMatch.status}, Score=${intMatch.actualScore}',
        // );
        // debugPrint('   EXTERNAL: Status=${ext.status}, Score=$extScore');

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
            if (m1['team1'] != m2['team1'] || (m1['team2'] != m2['team2'])) {
              scoreChanged = true;
            }
          }
        }

        if (statusChanged) {
          // debugPrint(
          //   'Sync: Status changed for ${intMatch.team1Name} vs ${intMatch.team2Name}: ${intMatch.status} -> ${ext.status}',
          // );
          updates['status'] = ext.status;
          needsUpdate = true;
        }
        if (scoreChanged) {
          // debugPrint(
          //   'Sync: Score changed for ${intMatch.team1Name} vs ${intMatch.team2Name}',
          // );
          updates['actualScore'] = ext.actualScore;
          needsUpdate = true;
        }

        // 2. Check Schedule Time Changes
        // Allow for small differences (e.g. seconds)
        if (intMatch.scheduledTime
                .difference(ext.scheduledTime)
                .inMinutes
                .abs() >
            5) {
          // debugPrint(
          //   'Sync: Time changed for ${intMatch.team1Name} vs ${intMatch.team2Name}: ${intMatch.scheduledTime} -> ${ext.scheduledTime}',
          // );
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

          // Trigger side effects if status/score changed (Standings/Predictions)
          // Note: We can't easily do side-effects in a batch unless we use Cloud Functions.
          // For now, we'll keep the direct method call for side effects if live/completed.
          if (statusChanged || scoreChanged) {
            // We owe a call to recalculateStandings & processPredictions
            // Since we can't batch that easily with the current architecture,
            // we will call updateMatchScore logic strictly for the side effects AFTER batch?
            // actually updateMatchScore does a transaction-like update.
            // Let's stick to updateMatchScore for score/status, and simple update for time.
            // BUT calling await updateMatchScore inside loop is slow.
            // Compromise: Update time directly. If score/status changes, call updateMatchScore.
          }
        }
      }

      if (anyUpdate) {
        await batch.commit();
      }

      // Re-loop for critical updates (Score/Status)
      for (var ext in externalMatches) {
        // Find match again (same logic)
        MatchModel? intMatch;
        bool isReverse = false;

        try {
          intMatch = internalMatches.firstWhere(
            (m) => m.team1Id == ext.team1Id && m.team2Id == ext.team2Id,
          );
        } catch (_) {
          try {
            intMatch = internalMatches.firstWhere(
              (m) => m.team1Id == ext.team2Id && m.team2Id == ext.team1Id,
            );
            isReverse = true;
          } catch (_) {}
        }

        if (intMatch == null && ext.matchNumber != null) {
          try {
            intMatch = internalMatches.firstWhere(
              (m) => m.matchNumber == ext.matchNumber,
            );
            // reset isReverse just in case, though matchNumber implies we trust it
            // we should probably check ID orientation, but assume direct if Number match
            isReverse = false;
          } catch (_) {}
        }

        if (intMatch == null) continue;

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
            // Basic check
            final t1Old = intMatch.actualScore!['team1'];
            final t2Old = intMatch.actualScore!['team2'];
            final t1New = extScore['team1'];
            final t2New = extScore['team2'];
            if (t1Old != t1New || t2Old != t2New) scoreChanged = true;
          }
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
        } else if (intMatch.scheduledTime
                .difference(ext.scheduledTime)
                .inMinutes
                .abs() >
            5) {
          // Only time changed logic handled by batch already, but if we wanted side effects...
          // Just ensuring the object in memory is updated for stream would require refetch
          // but batch update should trigger stream update in UI.
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
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('matches')
          .doc(matchId)
          .update({
            'actualScore': score.isEmpty ? null : score,
            'status': status,
          });

      if (status == AppConstants.matchStatusCompleted ||
          status == AppConstants.matchStatusLive) {
        await recalculateStandings(competitionId);
        // Process predictions
        await _processPredictions(
          competitionId,
          matchId,
          score,
          oldScore: oldScore,
        );
      } else if (status == AppConstants.matchStatusScheduled ||
          status == AppConstants.matchStatusUpcoming) {
        // REVERT points if match was previously completed/live
        if (oldScore != null) {
          await _revertPredictions(competitionId, matchId);
          await recalculateStandings(competitionId);
        }
      }
    } catch (e) {
      throw Exception('Failed to update match score: ${e.toString()}');
    }
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

      final batch = _firestore.batch();
      final participantsRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants');

      for (var doc in predictionsSnapshot.docs) {
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
    } catch (e) {
      debugPrint('Error reverting predictions: $e');
    }
  }

  // Private method to process predictions
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
      final predictionsSnapshot = await _firestore
          .collection('predictions')
          .where('matchId', isEqualTo: matchId)
          .get();

      final batch = _firestore.batch();
      final participantsRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants');

      for (var doc in predictionsSnapshot.docs) {
        final prediction = PredictionModel.fromSnapshot(doc);
        final predScore = prediction.prediction;
        // Calculate points and stats
        int points = 0;
        bool isPerfectScore = false;
        bool isCorrectOutcome = false;

        if (competition.sport == AppConstants.sportCricket) {
          // Cricket logic: 3 for winner, 2 for score/wickets prediction
          final String? actualWinnerId = actualScore['winnerId'];
          final String? predWinnerId = predScore['winnerId'];

          // Winner Points
          if (actualWinnerId != null && actualWinnerId == predWinnerId) {
            points = 3;
            isCorrectOutcome = true;
          }

          // Score Points (2 points only if the predicted winner's margin is correct)
          final String? predRuns = predScore['runs'];
          final String? predWickets = predScore['wickets'];
          final String? startMarginType = actualScore['marginType'];
          final String? actualMarginValue = actualScore['marginValue'];

          bool marginCorrect = false;

          if (startMarginType != null && actualMarginValue != null) {
            String cleanMarginType = startMarginType.toLowerCase();

            if (cleanMarginType == 'runs' && predRuns != null) {
              // Check Runs Prediction
              marginCorrect = predRuns == actualMarginValue;
            } else if (cleanMarginType == 'wickets' && predWickets != null) {
              // Check Wickets Prediction
              // Handle potential "1" vs "1" string match directly
              marginCorrect = predWickets == actualMarginValue;
            }
          }

          // Bonus Logic: Match Tied -> Full Points (Implicitly correct margin)
          if (actualWinnerId == 'tied' && predWinnerId == 'tied') {
            marginCorrect = true;
          }

          // FIX: Only award margin points if the winner was also correct (or it's a tie)
          if (marginCorrect && (isCorrectOutcome || actualWinnerId == 'tied')) {
            points += 2;
            if (isCorrectOutcome) isPerfectScore = true;
          }
        } else {
          // Football/Default logic
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

          // Skip if incomplete data for football
          if (predHome == -1 ||
              predAway == -1 ||
              actualHome == -1 ||
              actualAway == -1) {
            continue;
          }

          // 1. Determine Correct Outcome (Winner/Draw)
          bool outcomeMatches = false;
          if (actualHome > actualAway && predHome > predAway) {
            outcomeMatches = true;
          } else if (actualHome < actualAway && predHome < predAway) {
            outcomeMatches = true;
          } else if (actualHome == actualAway && predHome == predAway) {
            // Both are Draws.
            // Tie-breakers are ignored for predictions. A draw is a correct outcome.
            outcomeMatches = true;
          }

          // 2. Determine Correct Score
          final bool scoreMatches =
              actualHome == predHome && actualAway == predAway;

          // Calculate Points
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
        }

        // --- IDEMPOTENCY / RE-SCORING ---
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
          // Update Participant Stats
          batch.update(participantsRef.doc(prediction.userId), {
            'totalPoints': FieldValue.increment(pointsDiff),
            'perfectScores': FieldValue.increment(perfectScoresDiff),
            'correctOutcomes': FieldValue.increment(correctOutcomesDiff),
          });
        }

        // Update Prediction Status
        batch.update(doc.reference, {
          'points': points,
          'isScored': true,
          'wasPerfectScore': isPerfectScore,
          'wasCorrectOutcome': isCorrectOutcome,
        });
      }

      await batch.commit();
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
        .handleError((e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint('Error in getStandings: $e');
          }
        })
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
            return status == AppConstants.matchStatusCompleted ||
                status == AppConstants.matchStatusLive ||
                status == 'final' ||
                status == 'finished'; // Legacy support
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
        }

        if (t2ScoreRaw is String) {
          t2Score = num.tryParse(t2ScoreRaw) ?? 0;
        } else if (t2ScoreRaw is num) {
          t2Score = t2ScoreRaw;
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
          final winnerId = match.actualScore?['winnerId'];
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
        );
      }

      // 5. Batch Write
      final batch = _firestore.batch();
      final standingsRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('standings');

      for (var team in teamStats.values) {
        batch.set(standingsRef.doc(team.teamId), team.toMap());
      }
      await batch.commit();
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
      // Check if prediction already exists
      QuerySnapshot existing = await _firestore
          .collection('predictions')
          .where('userId', isEqualTo: prediction.userId)
          .where('matchId', isEqualTo: prediction.matchId)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing prediction
        await _firestore
            .collection('predictions')
            .doc(existing.docs.first.id)
            .update(prediction.toMap());
        return existing.docs.first.id;
      } else {
        // Create new prediction
        DocumentReference docRef = await _firestore
            .collection('predictions')
            .add(prediction.toMap());

        // Increment totalPredictions for participant
        await _firestore
            .collection('competitions')
            .doc(prediction.competitionId)
            .collection('participants')
            .doc(prediction.userId)
            .update({'totalPredictions': FieldValue.increment(1)});

        return docRef.id;
      }
    } catch (e) {
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
    try {
      // Ensure competitionId is correctly set in the participant record
      final participantData = participant.toMap();
      participantData['competitionId'] = competitionId;

      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('participants')
          .doc(participant.userId)
          .set(participantData);

      // Increment participant count
      await _firestore.collection('competitions').doc(competitionId).update({
        'participantCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to join competition: ${e.toString()}');
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

  // Get leaderboard for competition
  Stream<List<ParticipantModel>> getLeaderboard(String competitionId) {
    return _firestore
        .collection('competitions')
        .doc(competitionId)
        .collection('participants')
        .orderBy('totalPoints', descending: true)
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
        .doc('tournament_sync')
        .get();
    if (doc.exists) {
      final ts = doc.data()?['lastSyncAt'] as Timestamp?;
      return ts?.toDate();
    }
    return null;
  }

  Future<void> updateTournamentSyncAt(DateTime time) async {
    await _firestore.collection('app_metadata').doc('tournament_sync').set({
      'lastSyncAt': Timestamp.fromDate(time),
    });
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
        'discoveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<List<OfficialTournamentModel>> getDiscoveredTournaments() async {
    final query = await _firestore.collection('discovered_tournaments').get();
    return query.docs.map((doc) {
      final data = doc.data();
      return OfficialTournamentModel(
        id: data['id'],
        name: data['name'],
        country: data['country'],
        sport: data['sport'],
        logoUrl: data['logoUrl'],
        source: data['source'] ?? 'fixturedownload',
      );
    }).toList();
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
}
