import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../models/match_model.dart';
import '../constants/app_constants.dart';
import 'team_logo.dart';

class FooterImageData {
  final dynamic file; // Use dynamic for cross-platform compatibility
  final BoxFit fit;

  const FooterImageData(this.file, {this.fit = BoxFit.contain});
}

class MatchResultCard extends StatelessWidget {
  final MatchModel match;
  final String heading;
  final dynamic logoFile; // dynamic to avoid dart:io crash on web
  final String? competitionName;
  final List<FooterImageData>? bottomImages;
  final String? sport;

  const MatchResultCard({
    super.key,
    required this.match,
    required this.heading,
    this.logoFile,
    this.competitionName,
    this.bottomImages,
    this.sport,
  });

  String? resolveWinnerName(String? wId, {String? sport}) {
    if (wId == null || (wId.trim().isEmpty)) return wId;
    if (wId == 'tied' || wId == 'no_result' || wId == 'draw') return wId;

    String cleanWId = wId.trim().toLowerCase();
    if (cleanWId.contains(' ')) {
      cleanWId = cleanWId.split(' ')[0];
    }

    String cleanT1Id = match.team1Id.trim().toLowerCase();
    String cleanT2Id = match.team2Id.trim().toLowerCase();

    // Secondary check: look for names in the actualScore metadata
    if (match.actualScore != null) {
      if (match.actualScore!['winnerName'] != null) {
        return match.actualScore!['winnerName'].toString();
      }
      if (match.actualScore!['winner_name'] != null) {
        return match.actualScore!['winner_name'].toString();
      }
    }

    // Normalize all strings for comparison
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final nWId = norm(cleanWId);
    final nT1Id = norm(cleanT1Id);
    final nT2Id = norm(cleanT2Id);
    final nT1Name = norm(match.team1Name);
    final nT2Name = norm(match.team2Name);

    // 1. Precise or fuzzy ID match
    if (nWId == nT1Id ||
        (nT1Id.length > 5 && nWId.contains(nT1Id)) ||
        (nWId.length > 5 && nT1Id.contains(nWId))) return match.team1Name;
    if (nWId == nT2Id ||
        (nT2Id.length > 5 && nWId.contains(nT2Id)) ||
        (nWId.length > 5 && nT2Id.contains(nWId))) return match.team2Name;

    // 2. Name-based match (sometimes ID is a slug/name)
    if (nWId == nT1Name ||
        (nT1Name.length > 3 && (nWId.contains(nT1Name) || nT1Name.contains(nWId)))) {
      return match.team1Name;
    }
    if (nWId == nT2Name ||
        (nT2Name.length > 3 && (nWId.contains(nT2Name) || nT2Name.contains(nWId)))) {
      return match.team2Name;
    }

    // 3. Fallback: Check who won by looking at the score (only if not a literal TIE branch)
    final rootWinnerId = match.winnerId?.toLowerCase();
    if (rootWinnerId != null &&
        rootWinnerId != 'tied' &&
        rootWinnerId != 'draw') {
      if (rootWinnerId == cleanT1Id || norm(rootWinnerId) == nT1Id) {
        return match.team1Name;
      }
      if (rootWinnerId == cleanT2Id || norm(rootWinnerId) == nT2Id) {
        return match.team2Name;
      }
    }

    // 4. Last resort: If scores are NOT tied, infer from runs/points
    if (match.actualScore != null) {
      if (sport == AppConstants.sportCricket) {
        final t1Runs =
            int.tryParse(match.actualScore!['t1Runs']?.toString() ?? '0') ?? 0;
        final t2Runs =
            int.tryParse(match.actualScore!['t2Runs']?.toString() ?? '0') ?? 0;
        if (t1Runs != t2Runs && t1Runs > 0 && t2Runs > 0) {
          return t1Runs > t2Runs ? match.team1Name : match.team2Name;
        }
      } else {
        final s1 =
            int.tryParse(match.actualScore!['team1']?.toString() ?? '0') ?? 0;
        final s2 =
            int.tryParse(match.actualScore!['team2']?.toString() ?? '0') ?? 0;
        if (s1 != s2 && (s1 > 0 || s2 > 0)) {
          return s1 > s2 ? match.team1Name : match.team2Name;
        }
      }
    }

    // If it's a UUID and somehow didn't match, return Team 1 as a legacy visual fallback
    // but try to keep the ID if it's very short.
    if (wId.contains('-')) return match.team1Name;

    return wId;
  }

  /// Resolves a winner ID that may be an API name slug (e.g., "south_africa")
  /// OR a competition UUID. Returns the matching team1Id or team2Id,
  /// or the original value unchanged (for 'tied', 'no_result', already UUID, etc.)
  String? _resolveWinnerId(String? wId) {
    if (wId == null || wId.isEmpty) return wId;
    if (wId == 'tied' || wId == 'no_result' || wId == 'draw') return wId;
    if (wId == match.team1Id || wId == match.team2Id) {
      return wId; // already a UUID
    }

    // Case-insensitive ID check
    if (wId.toLowerCase() == match.team1Id.toLowerCase()) return match.team1Id;
    if (wId.toLowerCase() == match.team2Id.toLowerCase()) return match.team2Id;

    // Looks like a slug — try to map to a team UUID via name fuzzy match
    final slug = wId.toLowerCase().replaceAll('_', '');
    final t1n =
        match.team1Name.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    final t2n =
        match.team2Name.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (t1n.contains(slug) || slug.contains(t1n)) return match.team1Id;
    if (t2n.contains(slug) || slug.contains(t2n)) return match.team2Id;

    if (wId.contains('-')) {
      // Fallback: If it's a UUID and somehow didn't match team1Id or team2Id,
      // map it to team1Id so the UI doesn't print raw alphanumeric codes to the user
      return match.team1Id;
    }

    return wId; // unresolved, return as-is
  }

  @override
  Widget build(BuildContext context) {
    // Determine scores and logic
    final team1ScoreVal = match.actualScore?['team1'] ?? 0;
    final team2ScoreVal = match.actualScore?['team2'] ?? 0;

    final team1Score = team1ScoreVal.toString();
    final team2Score = team2ScoreVal.toString();

    final isLive = match.status == AppConstants.matchStatusLive ||
        match.status == AppConstants.matchStatusProgressing;
    final isUpcoming = match.status == AppConstants.matchStatusUpcoming ||
        match.status == AppConstants.matchStatusScheduled;

    String dateStr;
    if (isLive) {
      dateStr = 'LIVE';
    } else if (isUpcoming) {
      dateStr = DateFormat('MMM d, yyyy • h:mm a').format(match.scheduledTime);
    } else {
      dateStr = DateFormat('MMM d, yyyy').format(match.scheduledTime);
    }

    final AutoSizeGroup teamNameGroup = AutoSizeGroup();

    // Resolve IDs
    String? rawWinnerId = match.winnerId;
    if (rawWinnerId == null || rawWinnerId.isEmpty) {
      rawWinnerId = match.actualScore?['winnerId']?.toString();
    }

    // Check if it was a tie-breaker situation
    bool isScoreEqual;
    if (sport == 'Cricket') {
      final t1Runs = int.tryParse(match.actualScore?['t1Runs']?.toString() ?? '0') ?? 0;
      final t2Runs = int.tryParse(match.actualScore?['t2Runs']?.toString() ?? '0') ?? 0;
      if (match.actualScore?['t1Runs'] == null &&
          match.actualScore?['t2Runs'] == null) {
        isScoreEqual = false;
      } else {
        isScoreEqual = (t1Runs == t2Runs && t1Runs > 0);
      }
    } else {
      isScoreEqual = (team1ScoreVal == team2ScoreVal);
    }

    String? tbwId = match.actualScore?['tieBreakerWinnerId']?.toString();
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['superOverWinnerId']?.toString();
    }
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['shootoutWinnerId']?.toString();
    }
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['tie_breaker_winner_id']?.toString();
    }

    if (tbwId != null && tbwId.isNotEmpty) {
      isScoreEqual = true;
    }
    
    if (rawWinnerId == 'tied' || rawWinnerId == 'draw') {
      isScoreEqual = true;
    }

    if (isScoreEqual && (tbwId == null || tbwId.isEmpty)) {
      if (rawWinnerId != null &&
          rawWinnerId != 'tied' &&
          rawWinnerId != 'no_result' &&
          rawWinnerId != 'draw') {
        tbwId = rawWinnerId;
      }
    }

    final bool isTieBreaker =
        isScoreEqual && (tbwId != null && tbwId.isNotEmpty && tbwId != 'tied' && tbwId != 'draw' && tbwId != 'no_result');


    final gradient = _getGradient(match.competitionId);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),

          // --- Header Section (Editable) ---
          if (!kIsWeb && logoFile != null && logoFile is io.File)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                logoFile as io.File,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/app_logo.png',
                height: 60,
                width: 60,
                fit: BoxFit.contain,
              ),
            ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              (heading.isEmpty ? competitionName : heading)?.toUpperCase() ??
                  '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Scoreboard Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (match.matchNumber != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'MATCH ${match.matchNumber}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Top Alignment for Logos
                    children: [
                      // Home Team
                      Expanded(
                        child: Column(
                          children: [
                            if (sport == 'Cricket')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '${match.actualScore?['t1Runs'] ?? 0}/${match.actualScore?['t1Wickets'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: TeamLogo(
                                url: match.team1LogoUrl,
                                teamName: match.team1Name,
                                size: 50,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AutoSizeText(
                              match.team1Name,
                              group: teamNameGroup, // Sync font size
                              textAlign: TextAlign.center,
                              maxLines: 2, // Strict 2 lines
                              minFontSize:
                                  8, // Allow smaller text to fit full name
                              wrapWords: true, // Allow wrapping
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score Center
                      Column(
                        children: [
                          // Date / Live Status (MOVED TO TOP)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLive ? Colors.red : Colors.blueGrey,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Score Box (Compacted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, // Reduced padding
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (sport == 'Cricket' && match.isFinished &&
                                    (rawWinnerId == 'tied' || rawWinnerId == 'draw' || isScoreEqual))
                                  // Cricket tied: show TIED in center
                                  const Text(
                                    'TIED',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (sport == 'Cricket' && match.isFinished && rawWinnerId == 'no_result')
                                  const Text(
                                    'NO RESULT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (sport != 'Cricket' && !isUpcoming)
                                  // Non-cricket finished/live: show score
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            team1Score,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.0,
                                            ),
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            team2Score,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  // Default: VS circle for upcoming, cricket finished with winner, etc.
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.amberAccent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Away Team
                      Expanded(
                        child: Column(
                          children: [
                            if (sport == 'Cricket')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '${match.actualScore?['t2Runs'] ?? 0}/${match.actualScore?['t2Wickets'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: TeamLogo(
                                url: match.team2LogoUrl,
                                teamName: match.team2Name,
                                size: 50,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AutoSizeText(
                              match.team2Name,
                              group: teamNameGroup, // Sync font size
                              textAlign: TextAlign.center,
                              maxLines: 2, // Strict 2 lines
                              minFontSize: 8,
                              wrapWords: true, // Allow wrapping
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (match.isFinished) ...[
                    const SizedBox(height: 12),
                    if (isTieBreaker)
                      Builder(builder: (context) {
                        // Resolve winner name directly from tbwId to avoid resolveWinnerName returning 'tied'
                        final String resolvedTbwId = _resolveWinnerId(tbwId) ?? '';
                        String winnerName;
                        if (resolvedTbwId == match.team1Id) {
                          winnerName = match.team1Name;
                        } else if (resolvedTbwId == match.team2Id) {
                          winnerName = match.team2Name;
                        } else {
                          // Fallback: try resolveWinnerName but skip if it returns tied/draw
                          final resolved = resolveWinnerName(tbwId ?? rawWinnerId, sport: sport);
                          if (resolved != null && resolved != 'tied' && resolved != 'draw') {
                            winnerName = resolved;
                          } else {
                            winnerName = 'UNKNOWN';
                          }
                        }
                        final String tieBreakerSuffix =
                            (sport ?? '').toLowerCase().contains('football') ? 'P/K' : 'S/O';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.accentGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '${winnerName.toUpperCase()} WON BY $tieBreakerSuffix',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      })
                    else if ((rawWinnerId == 'draw' ||
                        (isScoreEqual &&
                            (rawWinnerId == null ||
                                rawWinnerId.isEmpty ||
                                rawWinnerId == 'draw'))) && sport != 'Cricket')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DRAW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if ((rawWinnerId == match.team1Id || rawWinnerId == match.team2Id) && sport != 'Cricket')
                      Container( // Standard winner pill for non-cricket
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          rawWinnerId == match.team1Id 
                            ? '${match.team1Name} Won' 
                            : '${match.team2Name} Won',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    // Cricket winner name + margin combined pill at bottom
                    else if (sport == 'Cricket' &&
                        match.actualScore != null &&
                        match.actualScore!['winnerId'] != null &&
                        match.actualScore!['winnerId'].toString().isNotEmpty &&
                        match.actualScore!['winnerId'] != 'tied' &&
                        match.actualScore!['winnerId'] != 'no_result')
                      Builder(builder: (context) {
                        final resolvedWId = _resolveWinnerId(
                          match.actualScore?['winnerId']?.toString(),
                        );
                        final winnerName = resolvedWId == match.team1Id
                            ? match.team1Name
                            : match.team2Name;

                        // Calculate margin text
                        final String rawType =
                            match.actualScore?['marginType']?.toString() ?? '';
                        final String type = rawType.toLowerCase();
                        final String val =
                            match.actualScore?['marginValue']?.toString() ?? '';

                        String marginText = '';
                        final t1r = int.tryParse(
                              match.actualScore?['t1Runs']?.toString() ?? '0') ?? 0;
                        final t2r = int.tryParse(
                              match.actualScore?['t2Runs']?.toString() ?? '0') ?? 0;
                        final t1w = int.tryParse(
                              match.actualScore?['t1Wickets']?.toString() ?? '0') ?? 0;
                        final t2w = int.tryParse(
                              match.actualScore?['t2Wickets']?.toString() ?? '0') ?? 0;

                        if (type == 'runs') {
                          final diff = (t1r - t2r).abs();
                          marginText =
                              '${val.isNotEmpty && val != '?' ? val : diff} runs';
                        } else if (type == 'wickets' || type == 'wicket') {
                          final winnerWkts =
                              resolvedWId == match.team1Id ? t1w : t2w;
                          final wLeft = (10 - winnerWkts).clamp(0, 10);
                          final dVal = val.isNotEmpty && val != '?'
                              ? val
                              : wLeft.toString();
                          marginText =
                              '$dVal ${dVal == '1' ? 'wicket' : 'wickets'}';
                        } else if (type.isEmpty) {
                          final rawBattingFirstId =
                              match.actualScore?['battingFirstId']?.toString();
                          final battingFirstId =
                              _resolveWinnerId(rawBattingFirstId);

                          if (battingFirstId != null &&
                              battingFirstId.isNotEmpty) {
                            if (resolvedWId == battingFirstId) {
                              marginText = '${(t1r - t2r).abs()} runs';
                            } else {
                              final winnerWkts =
                                  (resolvedWId == match.team1Id) ? t1w : t2w;
                              final wLeft =
                                  (10 - winnerWkts).clamp(0, 10);
                              marginText =
                                  '$wLeft ${wLeft == 1 ? 'wicket' : 'wickets'}';
                            }
                          } else {
                            if (resolvedWId == match.team2Id) {
                              final wLeft = (10 - t2w).clamp(0, 10);
                              marginText =
                                  '$wLeft ${wLeft == 1 ? 'wicket' : 'wickets'}';
                            } else if (resolvedWId == match.team1Id) {
                              marginText = '${(t1r - t2r).abs()} runs';
                            }
                          }
                        }

                        if (type.contains('super')) {
                          marginText = '';
                        }

                        // Build full result text: "Cagliari Won by 2 runs"
                        final String fullText = marginText.isNotEmpty
                            ? '$winnerName Won by $marginText'
                            : '$winnerName Won';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AutoSizeText(
                            fullText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            minFontSize: 10,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                  ],

                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Footer Images (Custom Row) ---
          if (bottomImages != null && bottomImages!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                // Removed padding to let images fill the space
                decoration: BoxDecoration(
                  color: Colors.white, // Solid white background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 0; i < bottomImages!.length; i++) ...[
                        Expanded(
                          child: SizedBox(
                            height: 50, // Fixed height for consistency
                            child: Image.file(
                              bottomImages![i].file,
                              fit: bottomImages![i].fit,
                            ),
                          ),
                        ),
                        // Add divider if not the last item
                        if (i < bottomImages!.length - 1)
                          Container(
                            width: 1, // Narrow line
                            height: 50,
                            color: Colors.grey[300], // Visible separation
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // --- Footer ---
          if (bottomImages == null || bottomImages!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, color: Colors.white24, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Powered by Winniko',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          // Else spacing provided by padding of image row
        ],
      ),
    );
  }

  LinearGradient _getGradient(String text) {
    final gradients = [
      // Deep Blue (Default)
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF001F3F), Color(0xFF0074D9), Color(0xFF001F3F)],
      ),
      // Crimson Red
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF85144b), Color(0xFFFF4136), Color(0xFF85144b)],
      ),
      // Forest Green
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B5E20), Color(0xFF4CAF50), Color(0xFF1B5E20)],
      ),
      // Royal Purple
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A148C), Color(0xFF9C27B0), Color(0xFF4A148C)],
      ),
      // Burnt Orange
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBF360C), Color(0xFFFF5722), Color(0xFFBF360C)],
      ),
      // Midnight Black / Gold
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF000000), Color(0xFF333333), Color(0xFF000000)],
      ),
      // Teal / Cyan
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF004D40), Color(0xFF00BFA5), Color(0xFF004D40)],
      ),
    ];

    // Use hash code to pick a stable color for the same tournament name
    final index = text.hashCode.abs() % gradients.length;
    return gradients[index];
  }
}
