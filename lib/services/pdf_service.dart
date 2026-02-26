import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/prediction_model.dart';
import '../models/participant_model.dart';
import '../models/competition_model.dart';
import '../models/standing_model.dart';
import 'package:intl/intl.dart';

class PdfService {
  // Generate Match Report
  static Future<void> generateMatchReport(
    MatchModel match,
    List<PredictionModel> predictions,
    CompetitionModel competition,
    List<ParticipantModel> participants,
  ) async {
    final pdf = pw.Document();

    // Sort predictions by user name
    predictions.sort((a, b) {
      final nameA = _getName(a.userId, participants);
      final nameB = _getName(b.userId, participants);
      return nameA.compareTo(nameB);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'Match Prediction Report',
              subtitle:
                  '${competition.name} - Match ${match.matchNumber ?? ""}',
            ),
            pw.SizedBox(height: 20),
            _buildMatchSummary(match, competition),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Predictions: ${predictions.length}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildPredictionsTable(
              match,
              predictions,
              participants,
              competition,
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Match_${match.matchNumber}_Report.pdf',
    );
  }

  // Generate User Report
  static Future<void> generateUserReport(
    ParticipantModel participant,
    List<PredictionModel> predictions,
    CompetitionModel competition,
    List<MatchModel> matches,
  ) async {
    final pdf = pw.Document();

    // Sort predictions by match number
    predictions.sort((a, b) {
      final matchA = _getMatch(a.matchId, matches);
      final matchB = _getMatch(b.matchId, matches);
      final numA = matchA?.matchNumber ?? 0;
      final numB = matchB?.matchNumber ?? 0;
      return numA.compareTo(numB);
    });

    // Calculate stats dynamically to ensure consistency with the table
    int totalPoints = 0;
    int correctOutcomes = 0;
    int perfectScores = 0;

    for (var p in predictions) {
      totalPoints += (p.points ?? 0);
      if (p.wasCorrectOutcome) correctOutcomes++;
      if (p.wasPerfectScore) perfectScores++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'User Prediction Report',
              subtitle: '${competition.name} - ${participant.userName}',
            ),
            pw.SizedBox(height: 20),
            _buildUserSummary(
              totalPoints: totalPoints,
              correctOutcomes: correctOutcomes,
              perfectScores: perfectScores,
              totalPredictions: predictions.length,
            ),
            pw.SizedBox(height: 20),
            _buildUserPredictionsTable(predictions, matches, competition),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${participant.userName}_Report.pdf',
    );
  }

  // Generate Leaderboard/Standings Report
  static Future<void> generateLeaderboardPdf(
    CompetitionModel competition,
    List<StandingModel> standings,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'Competition Standings',
              subtitle: competition.name,
            ),
            pw.SizedBox(height: 20),
            _buildStandingsTable(standings, competition),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${competition.name}_Standings.pdf',
    );
  }

  // Generate Match List Schedule (Organizer Only)
  static Future<void> generateMatchListSchedule(
    CompetitionModel competition,
    List<MatchModel> matches,
  ) async {
    final pdf = pw.Document();

    // Sort by time
    matches.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(title: 'Match Schedule', subtitle: competition.name),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Matches: ${matches.length}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildMatchListTable(matches, competition),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${competition.name}_Schedule.pdf',
    );
  }

  // Generate Full Leaderboard Report (Organizer Only)
  static Future<void> generateFullLeaderboard(
    CompetitionModel competition,
    List<ParticipantModel> participants,
    List<MatchModel> matches,
    List<PredictionModel> allPredictions,
  ) async {
    final pdf = pw.Document();

    // Ensure sorted by rank/points
    participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    // Sort matches by time
    matches.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'Full Leaderboard & Report',
              subtitle: competition.name,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Overall Standings',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Participants: ${participants.length}',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            _buildFullLeaderboardTable(participants),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Individual Predictions by Match',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.SizedBox(height: 20),
            ..._buildAllMatchPredictionTables(
              matches,
              allPredictions,
              participants,
              competition,
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${competition.name}_Full_Report.pdf',
    );
  }

  // --- Helpers ---

  static List<pw.Widget> _buildAllMatchPredictionTables(
    List<MatchModel> matches,
    List<PredictionModel> allPredictions,
    List<ParticipantModel> participants,
    CompetitionModel competition,
  ) {
    List<pw.Widget> widgets = [];

    for (var match in matches) {
      // Get predictions for this match
      var matchPreds = allPredictions
          .where((p) => p.matchId == match.id)
          .toList();
      if (matchPreds.isEmpty) continue;

      // Sort by User Name for readability
      matchPreds.sort((a, b) {
        var nameA = _getName(a.userId, participants);
        var nameB = _getName(b.userId, participants);
        return nameA.compareTo(nameB);
      });

      // Match Header
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          color: PdfColors.grey200,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Match ${match.matchNumber ?? ""}: ${match.team1Name} vs ${match.team2Name}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                match.status.toUpperCase(),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      );

      // Result Line if completed OR verified
      if (match.isFinished && match.actualScore != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
            child: pw.Text(
              'Result: ${_formatScore(match, competition).replaceAll('\n', ', ')}',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ),
        );
      } else {
        widgets.add(pw.SizedBox(height: 5));
      }

      // Predictions Table
      // ignore: deprecated_member_use
      widgets.add(
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey700,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['User', 'Prediction', 'Pts'],
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(0.5),
          },
          data: matchPreds.map((p) {
            return [
              _getName(p.userId, participants),
              _formatPrediction(p, competition, match).replaceAll('\n', ' '),
              p.points?.toString() ?? '-',
            ];
          }).toList(),
        ),
      );

      widgets.add(pw.SizedBox(height: 20));
    }
    return widgets;
  }

  static pw.Widget _buildFullLeaderboardTable(
    List<ParticipantModel> participants,
  ) {
    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      headers: ['Rank', 'Participant', 'Points', 'Correct', 'Perfect', 'Total'],
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(50),
        4: const pw.FixedColumnWidth(50),
        5: const pw.FixedColumnWidth(50),
      },
      data: participants.map((p) {
        return [
          '${p.rank}',
          p.userName,
          '${p.totalPoints}',
          '${p.correctOutcomes}',
          '${p.perfectScores}',
          '${p.totalPredictions}',
        ];
      }).toList(),
    );
  }

  static String _getName(String userId, List<ParticipantModel> participants) {
    try {
      return participants.firstWhere((p) => p.userId == userId).userName;
    } catch (_) {
      return 'Unknown User';
    }
  }

  static MatchModel? _getMatch(String matchId, List<MatchModel> matches) {
    try {
      return matches.firstWhere((m) => m.id == matchId);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeader({
    required String title,
    required String subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildMatchSummary(
    MatchModel match,
    CompetitionModel competition,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${match.team1Name} vs ${match.team2Name}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(match.status.toUpperCase()),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text('Date: ${dateFormat.format(match.scheduledTime)}'),
          if (match.actualScore != null)
            pw.Text('Final Score: ${_formatScore(match, competition)}'),
        ],
      ),
    );
  }

  static pw.Widget _buildUserSummary({
    required int totalPoints,
    required int correctOutcomes,
    required int perfectScores,
    required int totalPredictions,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Points', '$totalPoints'),
          _buildStatItem('Correct Outcomes', '$correctOutcomes'),
          _buildStatItem('Perfect Scores', '$perfectScores'),
          _buildStatItem('Predictions', '$totalPredictions'),
        ],
      ),
    );
  }

  static pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildPredictionsTable(
    MatchModel match,
    List<PredictionModel> predictions,
    List<ParticipantModel> participants,
    CompetitionModel competition,
  ) {
    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      headers: ['User', 'Prediction', 'Points'],
      data: predictions.map((p) {
        return [
          _getName(p.userId, participants),
          _formatPrediction(p, competition, match),
          '${p.points ?? 0}',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildUserPredictionsTable(
    List<PredictionModel> predictions,
    List<MatchModel> matches,
    CompetitionModel competition,
  ) {
    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      headers: ['Match', 'Result', 'Prediction', 'Points'],
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
      },
      data: predictions.map((p) {
        final match = _getMatch(p.matchId, matches);
        final matchLabel = match != null
            ? 'M${match.matchNumber ?? "?"}: ${match.team1Name} vs ${match.team2Name}'
            : 'Unknown Match';

        return [
          matchLabel,
          match?.actualScore != null ? _formatScore(match!, competition) : '-',
          _formatPrediction(p, competition, match),
          '${p.points ?? 0}',
        ];
      }).toList(),
    );
  }

  static String _formatScore(MatchModel match, CompetitionModel competition) {
    if (match.actualScore == null) return '-';
    final score = match.actualScore!;
    final String? resultStatus = score['status']?.toString();
    String scoreLine = '';

    // Use competition sport if available, else infer from map content
    final bool isCricket =
        competition.sport.toLowerCase().contains('cricket') ||
        score.containsKey('t1Runs') ||
        score.containsKey('t1Wickets');

    if (isCricket) {
      // Cricket - show detailed scores if they exist
      final t1r = score['t1Runs'];
      final t1w = score['t1Wickets'];
      final t2r = score['t2Runs'];
      final t2w = score['t2Wickets'];

      if (t1r != null || t1w != null || t2r != null || t2w != null) {
        final t1Runs = t1r?.toString() ?? '0';
        final t1Wickets = t1w?.toString() ?? '0';
        final t2Runs = t2r?.toString() ?? '0';
        final t2Wickets = t2w?.toString() ?? '0';
        scoreLine = '$t1Runs/$t1Wickets vs $t2Runs/$t2Wickets';
      } else if (resultStatus != null && resultStatus.isNotEmpty) {
        // Fallback to the status string if no detailed runs/wickets (common in verified matches)
        return resultStatus;
      }

      // Add winner/margin if not already covered by resultStatus
      if (score.containsKey('winnerId') &&
          score['winnerId'] != null &&
          score['winnerId'] != 'tied' &&
          score['winnerId'] != 'no_result') {
        final String winnerId = score['winnerId'];
        final String winnerName = winnerId == match.team1Id
            ? match.team1Name
            : match.team2Name;

        String margin = '';
        if (score.containsKey('marginType')) {
          final type = score['marginType'].toString().toLowerCase();
          final val = score['marginValue']?.toString() ?? '';

          if (type == 'runs') {
            margin = '$val runs';
          } else if (type.contains('wicket')) {
            margin = '$val ${val == '1' ? 'wicket' : 'wickets'}';
          }
        }

        if (margin.isNotEmpty) {
          scoreLine +=
              (scoreLine.isEmpty ? '' : '\n') + '$winnerName won by $margin';
        } else {
          scoreLine += (scoreLine.isEmpty ? '' : '\n') + '$winnerName won';
        }
      } else if (score['winnerId'] == 'tied') {
        scoreLine += (scoreLine.isEmpty ? '' : '\n') + 'Match Tied';
      } else if (score['winnerId'] == 'no_result') {
        scoreLine += (scoreLine.isEmpty ? '' : '\n') + 'No Result';
      } else if (scoreLine.isEmpty && resultStatus != null) {
        // Last resort fallback
        scoreLine = resultStatus;
      }
    } else {
      // Football - with null safety
      final team1Score = score['team1']?.toString() ?? '0';
      final team2Score = score['team2']?.toString() ?? '0';
      scoreLine = '$team1Score - $team2Score';

      if (resultStatus != null && resultStatus.length > 5) {
        scoreLine += '\n$resultStatus';
      }
    }

    return scoreLine.isEmpty ? '-' : scoreLine;
  }

  static String _formatPrediction(
    PredictionModel p,
    CompetitionModel c,
    MatchModel? m,
  ) {
    if (c.sport == AppConstants.sportCricket) {
      final winnerId = p.prediction['winnerId']?.toString();
      final String winnerName = (m != null && winnerId != null)
          ? (winnerId == 'tied'
                ? 'Tie'
                : (winnerId == 'no_result'
                      ? 'No Result'
                      : (winnerId == m.team1Id
                            ? m.team1Name
                            : (winnerId == m.team2Id
                                  ? m.team2Name
                                  : 'Unknown'))))
          : 'Unknown';

      String detail = '';
      // If match is finished (completed OR verified) and we have a margin type, show the RELEVANT prediction
      if (m != null &&
          m.isFinished &&
          m.actualScore != null &&
          m.actualScore!.containsKey('marginType')) {
        final type = m.actualScore!['marginType'];
        if (type == 'runs') {
          detail = 'Runs: ${p.prediction['runs'] ?? "-"}';
        } else if (type == 'wickets') {
          detail = 'Wickets: ${p.prediction['wickets'] ?? "-"}';
        } else {
          // Fallback or Super Over - show both or just runs as default
          detail = 'Runs: ${p.prediction['runs'] ?? "-"}';
        }
      } else {
        // Pending or Live - Show both if available to be informative
        final runs = p.prediction['runs'];
        final wickets = p.prediction['wickets'];
        if (runs != null && wickets != null) {
          detail = 'Runs: $runs\nWkts: $wickets';
        } else {
          detail = 'Runs: ${runs ?? "-"}';
        }
      }

      return 'Winner: $winnerName\n$detail';
    } else {
      // Football prediction
      final team1Score = p.prediction['team1']?.toString() ?? '-';
      final team2Score = p.prediction['team2']?.toString() ?? '-';
      return '$team1Score - $team2Score';
    }
  }

  static pw.Widget _buildStandingsTable(
    List<StandingModel> standings,
    CompetitionModel competition,
  ) {
    bool isFootball = competition.sport == AppConstants.sportFootball;

    final List<String> headers = [
      'Pos',
      'Team',
      'P',
      'W',
      'D',
      'L',
      if (isFootball) ...['GF', 'GA'],
      'GD',
      'Pts',
    ];

    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      headers: headers,
      data: List.generate(standings.length, (index) {
        final team = standings[index];
        return [
          '${index + 1}',
          team.teamName,
          '${team.played}',
          '${team.won}',
          '${team.drawn}',
          '${team.lost}',
          if (isFootball) ...['${team.goalsFor}', '${team.goalsAgainst}'],
          '${team.goalDifference}',
          '${team.points}',
        ];
      }),
    );
  }

  static pw.Widget _buildMatchListTable(
    List<MatchModel> matches,
    CompetitionModel competition,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    // ignore: deprecated_member_use
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headers: ['Match', 'Date/Time', 'Teams', 'Result'],
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
      },
      data: matches.map((m) {
        String matchLabel = m.matchNumber != null ? 'M${m.matchNumber}' : '-';
        if (m.round != null && m.round!.isNotEmpty && m.round != 'League') {
          matchLabel += '\n${m.round}';
        }

        String result = '-';

        // Check if there is a meaningful score present (even if not officially completed/verified)
        bool hasScoreData = false;
        if (m.actualScore != null) {
          final s = m.actualScore!;
          if (competition.sport.toLowerCase().contains('cricket')) {
            hasScoreData = s.containsKey('t1Runs') || s.containsKey('winnerId');
          } else {
            hasScoreData = s.containsKey('team1') || s.containsKey('team2');
          }
        }

        if (m.isFinished || hasScoreData) {
          result = _formatScore(m, competition);
        } else {
          // Dynamic status based on time (matches MatchCardWidget logic)
          final now = DateTime.now();
          final diff = now.difference(m.scheduledTime);

          if (diff.isNegative) {
            result = 'UPCOMING';
          } else {
            // Threshold for Progressing vs Completed
            int ongoingHours =
                competition.sport.toLowerCase().contains('cricket') ? 12 : 4;
            if (diff.inHours < ongoingHours) {
              result = 'PROGRESSING';
            } else {
              result = 'COMPLETED';
            }
          }
        }

        return [
          matchLabel,
          dateFormat.format(m.scheduledTime),
          '${m.team1Name} vs ${m.team2Name}',
          result,
        ];
      }).toList(),
    );
  }
}
