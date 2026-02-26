import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // Added for Timer
import '../models/match_model.dart';
import '../models/team_model.dart';
import 'tournament_data_service.dart';
import 'firestore_service.dart'; // Added for FirestoreService type
import 'teams_data_service.dart';

/// Service responsible for fetching OFFICIAL data via API
/// and writing it to the shared Firestore collection `official_leagues`.
/// This should only be run by ONE instance (Admin App or Cloud Function).
class MasterSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // List of leagues we want to keep in sync
  static const List<String> supportedLeagues = [
    'pl', // Premier League
    'ipl', // IPL
    'asiacup', // Asia Cup
    'cwc', // Cricket World Cup
    'ucl', // Champions League
    'laliga',
    'bundesliga',
    'seriea',
    'ligue1',
    'wc2026',
    'isl-2025',
    'mens-t20-world-cup-2026',
  ];

  /// Runs the full sync for a specific league
  Future<void> syncLeague(String leagueId) async {
    debugPrint('🔄 MASTER SYNC: Starting sync for $leagueId...');

    try {
      // 0. Check Status (Pause/Cleaned)
      final leagueDoc = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .get();
      if (!leagueDoc.exists) return;

      final bool isPaused = leagueDoc.data()?['syncPaused'] == true;
      if (isPaused) {
        debugPrint('⏹️ MASTER SYNC: Paused for $leagueId. Skipping.');
        return;
      }

      final lastCleanedAt = (leagueDoc.data()?['lastCleanedAt'] as Timestamp?)
          ?.toDate();

      // 1. Get Temporary Teams List for mapping
      List<Map<String, String>> rawTeams = [];
      if (leagueId == 'pl' ||
          leagueId == 'ucl' ||
          leagueId == 'laliga' ||
          leagueId == 'bundesliga' ||
          leagueId == 'seriea' ||
          leagueId == 'ligue1' ||
          leagueId.contains('isl') ||
          leagueId.contains('indian-super-league')) {
        rawTeams = TeamsDataService.getClubTeams(leagueId);
      } else if (leagueId == 'ipl' || leagueId == 'asiacup') {
        rawTeams = TeamsDataService.getCricketTeams(leagueId);
      } else {
        rawTeams = TeamsDataService.getNationalTeams();
      }

      final List<TeamModel> canonicalTeams = rawTeams.map((t) {
        return TeamModel(
          id: 'canonical_${t['code']}', // Dummy ID, we match by name/code
          name: t['name']!,
          shortName: t['code']!,
          logoUrl: t['logo'],
          competitionId: 'official_$leagueId',
          createdAt: DateTime.now(),
        );
      }).toList();

      // 2. Fetch Raw Data from API (isMaster = true)
      final allMatches = await TournamentDataService.getLatestScores(
        'official_$leagueId', // Dummy Comp ID
        leagueId,
        canonicalTeams,
        isMaster: true, // FORCE API CALL
      );

      // Filter by lastCleanedAt to prevent re-populating deleted history
      final matches = allMatches.where((m) {
        if (lastCleanedAt == null) return true;
        return m.scheduledTime.isAfter(lastCleanedAt);
      }).toList();

      debugPrint(
        '✅ MASTER SYNC: Fetched ${allMatches.length} raw, processing ${matches.length} matches for $leagueId (Cleaned At: $lastCleanedAt)',
      );

      if (matches.isEmpty) {
        // Still update the lastMasterSync time to prevent stuck "Sync Recommended" status
        await _firestore.collection('official_leagues').doc(leagueId).update({
          'lastMasterSync': FieldValue.serverTimestamp(),
        });
        return;
      }

      // 3. Write to Firestore `official_leagues/{leagueId}/matches`
      final collectionRef = _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches');

      // Fetch existing official matches to check for protection (verified status)
      final existingMatchesSnapshot = await collectionRef.get();
      final Map<String, Map<String, dynamic>> protectedScores = {};

      for (var doc in existingMatchesSnapshot.docs) {
        final data = doc.data();
        final score = data['actualScore'] as Map<String, dynamic>?;
        if (score != null &&
            (score['verified'] == true || score['manuallyScored'] == true)) {
          protectedScores[doc.id] = score;
        }
      }

      final batch = _firestore.batch();
      int updateCount = 0;

      for (var match in matches) {
        final docId = _generateMatchDocId(leagueId, match);

        // 🛡️ PROTECTION: Skip if this match is verified in official_leagues (under ANY docId)
        bool isAlreadyVerified = protectedScores.entries.any((entry) {
          final pData = entry.value;
          // Check if same teams
          final bool pTeamsMatch =
              (pData['homeTeamName'] == match.team1Name &&
                  pData['awayTeamName'] == match.team2Name) ||
              (pData['homeTeamName'] == match.team2Name &&
                  pData['awayTeamName'] == match.team1Name);
          if (!pTeamsMatch) return false;

          // Check time proximity (12 hours)
          final pTime = (pData['scheduledTime'] as Timestamp).toDate();
          return pTime.difference(match.scheduledTime).inHours.abs() < 12;
        });

        if (isAlreadyVerified) {
          debugPrint(
            '🛡️ MASTER SYNC PROTECTED: Skipping $docId in $leagueId (Match is already verified globally)',
          );
          continue;
        }

        final docRef = collectionRef.doc(docId);
        final data = match.toMap();

        data['lastUpdated'] = FieldValue.serverTimestamp();
        data['homeTeamCode'] = _findTeamCode(canonicalTeams, match.team1Name);
        data['awayTeamCode'] = _findTeamCode(canonicalTeams, match.team2Name);
        data['homeTeamName'] = match.team1Name;
        data['awayTeamName'] = match.team2Name;

        batch.set(docRef, data, SetOptions(merge: true));
        updateCount++;
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint(
          '💾 MASTER SYNC: Saved $updateCount matches to Firestore for $leagueId',
        );
      } else {
        debugPrint(
          'ℹ️ MASTER SYNC: No matches updated for $leagueId (all protected or empty)',
        );
      }
    } catch (e) {
      debugPrint('❌ MASTER SYNC ERROR ($leagueId): $e');
    }
  }

  String _generateMatchDocId(String leagueId, MatchModel match) {
    // ID Format: "match_1" or "teamA_v_teamB_date"
    if (match.matchNumber != null && match.matchNumber! > 0) {
      return 'match_${match.matchNumber}';
    }
    // Fallback: Date + Teams
    final datePart = match.scheduledTime.toIso8601String().split('T').first;
    // Sanitize names
    final t1 = match.team1Name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final t2 = match.team2Name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return '${datePart}_${t1}_v_$t2';
  }

  String _findTeamCode(List<TeamModel> teams, String teamName) {
    try {
      final team = teams.firstWhere((t) => t.name == teamName);
      return team.shortName;
    } catch (e) {
      return '';
    }
  }

  /// Checks if a sync is recommended for a league right now.
  /// Returns TRUE if there are matches scheduled within 4 hours (past/future) or marked as Live.
  /// This helps the admin know WHICH league to sync without checking external sites.
  Future<bool> isSyncRecommended(String leagueId) async {
    try {
      final now = DateTime.now();
      final fourHoursAgo = now.subtract(const Duration(hours: 4));
      final twoHoursAhead = now.add(const Duration(hours: 2));

      // We only need a lightweight query here
      final snapshot = await _firestore
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .get(); // Reading from Firestore is cheap (cache-friendly)

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final scheduledTime = (data['scheduledTime'] as Timestamp?)?.toDate();
        final status = (data['status'] as String?)?.toLowerCase() ?? '';

        // 1. Check Metadata Status
        if (status.contains('live') || status.contains('in_progress')) {
          return true;
        }

        // 2. Check Time Window (if schedule exists)
        if (scheduledTime != null) {
          if (scheduledTime.isAfter(fourHoursAgo) &&
              scheduledTime.isBefore(twoHoursAhead)) {
            // Match is happening roughly NOW
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking sync recommendation for $leagueId: $e');
      return false;
    }
  }

  // --- AUTO SYNC (For Master Admins) ---
  // Using static to ensure state persists regardless of service instantiation
  static final Map<String, Timer> _activeSyncs = {};

  static bool isSyncing(String competitionId) =>
      _activeSyncs.containsKey(competitionId);

  static void toggleAutoSync(
    String competitionId,
    String leagueId,
    FirestoreService firestore,
  ) {
    if (_activeSyncs.containsKey(competitionId)) {
      stopAutoSync(competitionId);
    } else {
      startAutoSync(competitionId, leagueId, firestore);
    }
  }

  static void startAutoSync(
    String competitionId,
    String leagueId,
    FirestoreService firestore,
  ) {
    if (_activeSyncs.containsKey(competitionId)) return;

    debugPrint("✅ AUTO SYNC STARTED for $competitionId (League: $leagueId)");

    // Run immediately
    _runSync(competitionId, leagueId, firestore);

    // Then every 2 minutes
    _activeSyncs[competitionId] = Timer.periodic(const Duration(minutes: 2), (
      timer,
    ) {
      _runSync(competitionId, leagueId, firestore);
    });
  }

  static void stopAutoSync(String competitionId) {
    _activeSyncs[competitionId]?.cancel();
    _activeSyncs.remove(competitionId);
    debugPrint("🛑 AUTO SYNC STOPPED for $competitionId");
  }

  static Future<void> _runSync(
    String competitionId,
    String leagueId,
    FirestoreService firestore,
  ) async {
    debugPrint("🔄 AUTO SYNC: Refreshing fixtures for $competitionId...");
    try {
      await TournamentDataService.refreshCompetitionFixtures(
        competitionId: competitionId,
        leagueId: leagueId,
        firestore: firestore,
        force: true, // Force API call
      );
    } catch (e) {
      debugPrint("⚠️ AUTO SYNC ERROR: $e");
    }
  }
}
