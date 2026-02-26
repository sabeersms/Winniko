import '../models/match_model.dart';
import '../models/standing_model.dart';
import '../models/team_model.dart';
import '../models/competition_model.dart';
import '../constants/app_constants.dart';

/// Calculates standings in-memory from match data without
/// needing Firestore `standings` subcollection access.
class StandingsCalculator {
  static List<StandingModel> calculate({
    required List<MatchModel> matches,
    required List<TeamModel> teams,
    required CompetitionModel competition,
  }) {
    final Map<String, StandingModel> teamStats = {};

    // 1. Initialize empty rows for all teams
    for (var team in teams) {
      teamStats[team.id] = StandingModel(
        teamId: team.id,
        teamName: team.name,
        teamLogoUrl: team.logoUrl,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        points: 0,
        group: team.group,
      );
    }

    // 2. Filter matches (Finished or Live)
    final activeMatches = matches.where((m) {
      return m.isFinished;
    }).toList();

    // 3. Process each match
    for (var match in activeMatches) {
      if (match.actualScore == null) continue;

      // Robust parsing for scores
      num t1Score = _parseScore(
        match.actualScore!['team1'] ?? match.actualScore!['t1Runs'],
      );
      num t2Score = _parseScore(
        match.actualScore!['team2'] ?? match.actualScore!['t2Runs'],
      );

      // Ensure teams exist in our map
      if (!teamStats.containsKey(match.team1Id)) {
        teamStats[match.team1Id] = _createEmptyStanding(
          match.team1Id,
          match.team1Name,
          null,
        );
      }
      if (!teamStats.containsKey(match.team2Id)) {
        teamStats[match.team2Id] = _createEmptyStanding(
          match.team2Id,
          match.team2Name,
          null,
        );
      }

      final t1 = teamStats[match.team1Id]!;
      final t2 = teamStats[match.team2Id]!;

      // Calculate outcome
      int t1Points = 0, t2Points = 0;
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
          t1Points = 1;
          t2Points = 1;
          t1NR = 1;
          t2NR = 1;
        } else if (match.actualScore!.isNotEmpty) {
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

      // Update team stats
      teamStats[match.team1Id] = t1.copyWith(
        played: t1.played + 1,
        won: t1.won + t1Won,
        drawn: t1.drawn + t1Drawn,
        tied: t1.tied + t1Tied,
        noResult: t1.noResult + t1NR,
        lost: t1.lost + t1Lost,
        goalsFor: t1.goalsFor + t1Score.toInt(),
        goalsAgainst: t1.goalsAgainst + t2Score.toInt(),
        points: t1.points + t1Points,
        oversFaced: (competition.sport == AppConstants.sportCricket)
            ? _sumCricketOvers(
                t1.oversFaced,
                _parseOvers(match.actualScore!['t1Overs']),
              )
            : 0,
        oversBowled: (competition.sport == AppConstants.sportCricket)
            ? _sumCricketOvers(
                t1.oversBowled,
                _parseOvers(match.actualScore!['t2Overs']),
              )
            : 0,
      );

      teamStats[match.team2Id] = t2.copyWith(
        played: t2.played + 1,
        won: t2.won + t2Won,
        drawn: t2.drawn + t2Drawn,
        tied: t2.tied + t2Tied,
        noResult: t2.noResult + t2NR,
        lost: t2.lost + t2Lost,
        goalsFor: t2.goalsFor + t2Score.toInt(),
        goalsAgainst: t2.goalsAgainst + t1Score.toInt(),
        points: t2.points + t2Points,
        oversFaced: (competition.sport == AppConstants.sportCricket)
            ? _sumCricketOvers(
                t2.oversFaced,
                _parseOvers(match.actualScore!['t2Overs']),
              )
            : 0,
        oversBowled: (competition.sport == AppConstants.sportCricket)
            ? _sumCricketOvers(
                t2.oversBowled,
                _parseOvers(match.actualScore!['t1Overs']),
              )
            : 0,
      );
    }

    // 4. Calculate NRR for Cricket
    if (competition.sport == AppConstants.sportCricket) {
      final updatedStandings = <String, StandingModel>{};
      for (var teamId in teamStats.keys) {
        final t = teamStats[teamId]!;
        double facedTrue = _cricketOversToTrueOvers(t.oversFaced);
        double bowledTrue = _cricketOversToTrueOvers(t.oversBowled);
        double forRate = (facedTrue > 0) ? (t.goalsFor / facedTrue) : 0.0;
        double againstRate = (bowledTrue > 0)
            ? (t.goalsAgainst / bowledTrue)
            : 0.0;
        double nrr = forRate - againstRate;
        if (nrr.isNaN || nrr.isInfinite) nrr = 0.0;
        updatedStandings[teamId] = t.copyWith(netRunRate: nrr);
      }
      return updatedStandings.values.toList();
    }

    return teamStats.values.toList();
  }

  static num _parseScore(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  static double _parseOvers(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  static StandingModel _createEmptyStanding(
    String id,
    String name,
    String? group,
  ) {
    return StandingModel(
      teamId: id,
      teamName: name,
      played: 0,
      won: 0,
      drawn: 0,
      lost: 0,
      goalsFor: 0,
      goalsAgainst: 0,
      points: 0,
      group: group,
    );
  }

  static double _sumCricketOvers(double a, double b) {
    int balls = _getBallsFromOvers(a) + _getBallsFromOvers(b);
    return (balls ~/ 6) + (balls % 6) / 10.0;
  }

  static double _cricketOversToTrueOvers(double overs) {
    return _getBallsFromOvers(overs) / 6.0;
  }

  static int _getBallsFromOvers(double overs) {
    int o = overs.toInt();
    int b = ((overs - o) * 10).round();
    return (o * 6) + b;
  }
}
