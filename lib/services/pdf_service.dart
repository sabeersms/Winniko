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

    // Sort predictions by user name (using participants list for name lookup)
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
            _buildMatchSummary(match),
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

    // Save/Share
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
            _buildUserSummary(participant, predictions.length),
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

  // Generate Full Leaderboard Report (Organizer Only)
  static Future<void> generateFullLeaderboard(
    CompetitionModel competition,
    List<ParticipantModel> participants,
  ) async {
    final pdf = pw.Document();

    // Ensure sorted by rank/points just in case
    participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(title: 'Full Leaderboard', subtitle: competition.name),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Participants: ${participants.length}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildFullLeaderboardTable(participants),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${competition.name}_Full_Leaderboard.pdf',
    );
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

  // --- Helpers ---

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

  static pw.Widget _buildMatchSummary(MatchModel match) {
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
            pw.Text('Final Score: ${_formatScore(match)}'),
        ],
      ),
    );
  }

  static pw.Widget _buildUserSummary(
    ParticipantModel participant,
    int totalPredictions,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Points', '${participant.totalPoints}'),
          _buildStatItem('Correct Outcomes', '${participant.correctOutcomes}'),
          _buildStatItem('Perfect Scores', '${participant.perfectScores}'),
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
          match?.actualScore != null ? _formatScore(match!) : '-',
          _formatPrediction(p, competition, match),
          '${p.points ?? 0}',
        ];
      }).toList(),
    );
  }

  static String _formatScore(MatchModel match) {
    final score = match.actualScore!;
    String scoreLine;
    bool isCricket = score.containsKey('t1Runs');

    if (isCricket) {
      // Cricket
      scoreLine =
          '${score['t1Runs']}/${score['t1Wickets']} vs ${score['t2Runs']}/${score['t2Wickets']}';
    } else {
      // Football
      scoreLine = '${score['team1']} - ${score['team2']}';
    }

    // Add Margin info if available
    if (score.containsKey('winnerId') &&
        score['winnerId'] != 'tied' &&
        score['winnerId'] != 'no_result') {
      final String winnerId = score['winnerId'];
      final String winnerName = winnerId == match.team1Id
          ? match.team1Name
          : match.team2Name;

      String margin = '';
      if (score.containsKey('marginType')) {
        final type = score['marginType'];
        String val = score['marginValue']?.toString() ?? '';

        if (type == 'runs') {
          // Calculate exact diff for safety like in MatchResultCard
          final t1 = int.tryParse(score['t1Runs']?.toString() ?? '0') ?? 0;
          final t2 = int.tryParse(score['t2Runs']?.toString() ?? '0') ?? 0;
          val = (t1 - t2).abs().toString();
          margin = '$val runs';
        } else if (type == 'wickets') {
          margin = '$val ${val == '1' ? 'wicket' : 'wickets'}';
        } else if (type == 'super_over') {
          margin = 'Super Over';
        }

        if (margin.isNotEmpty) {
          // Add newline and result text
          scoreLine += '\n$winnerName won by $margin';
        } else {
          scoreLine += '\n$winnerName won';
        }
      } else {
        // Fallback if no margin type but we have a winner
        scoreLine += '\n$winnerName won';
      }
    } else if (score['winnerId'] == 'tied') {
      scoreLine += '\nMatch Tied';
    } else if (score['winnerId'] == 'no_result') {
      scoreLine += '\nNo Result';
    }

    return scoreLine;
  }

  static String _formatPrediction(
    PredictionModel p,
    CompetitionModel c,
    MatchModel? m,
  ) {
    if (c.sport == AppConstants.sportCricket) {
      final winnerId = p.prediction['winnerId'];
      final String winnerName = (m != null)
          ? (winnerId == m.team1Id
                ? m.team1Name
                : (winnerId == m.team2Id ? m.team2Name : 'Draw'))
          : 'Unknown';

      String detail = '';
      // If match is completed and we have a margin type, show the RELEVANT prediction
      if (m != null &&
          m.status == AppConstants.matchStatusCompleted &&
          m.actualScore != null &&
          m.actualScore!.containsKey('marginType')) {
        final type = m.actualScore!['marginType'];
        if (type == 'runs') {
          detail = 'Runs: ${p.prediction['runs'] ?? "-"}';
        } else if (type == 'wickets') {
          detail = 'Wickets: ${p.prediction['wickets'] ?? "-"}';
        } else {
          // Fallback or Super Over - show both or just runs as default?
          // Let's show both contextually or just one.
          // If super over, margin doesn't matter for points usually unless defined.
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
      return '${p.prediction['team1']} - ${p.prediction['team2']}';
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
}
