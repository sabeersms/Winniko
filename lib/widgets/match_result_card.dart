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

  @override
  Widget build(BuildContext context) {
    // Determine scores and logic
    final team1ScoreVal = match.actualScore?['team1'] ?? 0;
    final team2ScoreVal = match.actualScore?['team2'] ?? 0;

    final team1Score = team1ScoreVal.toString();
    final team2Score = team2ScoreVal.toString();

    final isLive = match.status == AppConstants.matchStatusLive;
    final isUpcoming =
        match.status == AppConstants.matchStatusUpcoming ||
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

    // Check winnerId from root OR inside actualScore (legacy/compat)
    String? rawWinnerId = match.winnerId;
    if ((rawWinnerId == null || rawWinnerId.isEmpty) &&
        match.actualScore != null) {
      rawWinnerId = match.actualScore!['winnerId']?.toString();
    }

    // Check if it was a tie-breaker (scores equal but winner exists)
    bool isScoreEqual;
    if (sport == 'Cricket') {
      final t1Runs = match.actualScore?['t1Runs'] ?? 0;
      final t2Runs = match.actualScore?['t2Runs'] ?? 0;
      // If we have no run data, assume not equal to avoid false positive on 0-0
      if (match.actualScore?['t1Runs'] == null &&
          match.actualScore?['t2Runs'] == null) {
        isScoreEqual = false;
      } else {
        isScoreEqual = (t1Runs == t2Runs);
      }
    } else {
      isScoreEqual = (team1ScoreVal == team2ScoreVal);
    }

    final bool isTieBreaker =
        isScoreEqual &&
        (rawWinnerId != null &&
            rawWinnerId.isNotEmpty &&
            rawWinnerId != 'tied' &&
            rawWinnerId != 'no_result');

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Top Alignment for Logos
                    children: [
                      // Home Team
                      Expanded(
                        child: Column(
                          children: [
                            if (sport == 'Cricket' &&
                                match.status ==
                                    AppConstants.matchStatusCompleted)
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
                                if (isUpcoming)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ), // Dark background
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            Colors.amberAccent, // Gold Border
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
                                        color: Colors.amberAccent, // Gold Text
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  )
                                else if (sport == 'Cricket' &&
                                    match.status ==
                                        AppConstants.matchStatusCompleted) ...[
                                  // Cricket Completed State: Win Margin
                                  if (match.actualScore?['winnerId'] == 'tied')
                                    const Text(
                                      'MATCH TIED',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (match.actualScore?['winnerId'] ==
                                      'no_result')
                                    const Text(
                                      'NO RESULT',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 100,
                                      ), // Prevent crushing logos
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Actual Scores (Runs/Wickets)
                                          Builder(
                                            builder: (context) {
                                              final t1R =
                                                  match
                                                      .actualScore?['t1Runs'] ??
                                                  0;
                                              final t1W =
                                                  match
                                                      .actualScore?['t1Wickets'] ??
                                                  0;
                                              final t2R =
                                                  match
                                                      .actualScore?['t2Runs'] ??
                                                  0;
                                              final t2W =
                                                  match
                                                      .actualScore?['t2Wickets'] ??
                                                  0;
                                              if (sport != 'Cricket') {
                                                return Text(
                                                  '$t1R/$t1W - $t2R/$t2W',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Roboto',
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                          const SizedBox(height: 4),
                                          // Result Summary
                                          AutoSizeText(
                                            match.actualScore?['winnerId'] ==
                                                    match.team1Id
                                                ? '${match.team1Name} Won'
                                                : '${match.team2Name} Won',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            minFontSize: 8,
                                            wrapWords: true, // Allow wrapping
                                            overflow: TextOverflow.visible,
                                            style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              final String type =
                                                  match
                                                      .actualScore?['marginType']
                                                      ?.toString() ??
                                                  '';

                                              String val =
                                                  match
                                                      .actualScore?['marginValue']
                                                      ?.toString() ??
                                                  '?';

                                              // If Won by Runs, calculate exact difference
                                              if (type == 'runs') {
                                                final t1 =
                                                    int.tryParse(
                                                      match.actualScore?['t1Runs']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                final t2 =
                                                    int.tryParse(
                                                      match.actualScore?['t2Runs']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                val = (t1 - t2)
                                                    .abs()
                                                    .toString();
                                              }

                                              if (type == 'super_over') {
                                                return const AutoSizeText(
                                                  '(Super Over)',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  minFontSize: 10,
                                                  style: TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              }

                                              // Fix "1 wickets" -> "1 wicket"
                                              final String displayType =
                                                  (val == '1' &&
                                                      type == 'wickets')
                                                  ? 'wicket'
                                                  : type;
                                              return AutoSizeText(
                                                'by $val $displayType',
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                minFontSize: 10,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ] else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        team1Score,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24, // Reduced from 28
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
                                          fontSize: 24, // Reduced from 28
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ],
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
                            if (sport == 'Cricket' &&
                                match.status ==
                                    AppConstants.matchStatusCompleted)
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

                  // Tie Breaker / Winner Text (MOVED HERE: below the main row inside the column)
                  if (isTieBreaker &&
                      match.status == AppConstants.matchStatusCompleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amberAccent,
                            width: 1,
                          ),
                        ),
                        child: AutoSizeText(
                          rawWinnerId == match.team1Id
                              ? '${match.team1Name} Won by Tie Breaker'
                              : '${match.team2Name} Won by Tie Breaker',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          minFontSize: 10,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
