import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../constants/app_constants.dart';

class FixtureGenerator {
  static bool canGenerateFixtures(String format) {
    return [
      AppConstants.formatLeague,
      AppConstants.formatKnockout,
      AppConstants.formatLeagueKnockout,
      AppConstants.formatGroupsKnockout,
    ].contains(format);
  }

  // Round Robin Algorithm (Circle Method)
  static List<MatchModel> generateLeagueFixtures({
    required String competitionId,
    required List<TeamModel> teams,
    required DateTime startDate,
    bool doubleRoundRobin = false,
    int startMatchNumber = 1,
  }) {
    List<MatchModel> matches = [];
    if (teams.length < 2) return matches;

    // Add a dummy team for odd number of teams
    List<TeamModel?> roundTeams = List.from(teams);
    if (roundTeams.length % 2 != 0) {
      roundTeams.add(null); // Bye
    }

    int numRounds = roundTeams.length - 1;
    int halfSize = roundTeams.length ~/ 2;

    List<TeamModel?> currentTeams = List.from(roundTeams);
    DateTime matchDate = startDate;

    int currentMatchNum = startMatchNumber;

    // Single Round Generation
    void generateRound(int roundIndex) {
      for (int i = 0; i < halfSize; i++) {
        TeamModel? t1 = currentTeams[i];
        TeamModel? t2 = currentTeams[currentTeams.length - 1 - i];

        // Skip 'Bye' matches
        if (t1 != null && t2 != null) {
          matches.add(
            MatchModel(
              id: const Uuid().v4(),
              competitionId: competitionId,
              team1Id: t1.id,
              team1Name: t1.name,
              team1LogoUrl: t1.logoUrl,
              team2Id: t2.id,
              team2Name: t2.name,
              team2LogoUrl: t2.logoUrl,
              scheduledTime: matchDate.add(
                const Duration(hours: 10),
              ), // 10 AM default
              status: AppConstants.matchStatusScheduled,
              round: 'Round ${roundIndex + 1}',
              matchNumber: currentMatchNum++,
            ),
          );
        }
      }
    }

    // Generate Standard Rounds
    for (int r = 0; r < numRounds; r++) {
      generateRound(r);

      // Rotate teams (Circle Method)
      // Keep first team fixed, rotate others clockwise
      if (currentTeams.length > 2) {
        TeamModel? last = currentTeams.removeLast();
        currentTeams.insert(1, last);
      }

      // Increment Day
      matchDate = matchDate.add(
        const Duration(days: 3),
      ); // 3 days between rounds
    }

    // Double Round Robin (Reverse fixtures)
    if (doubleRoundRobin) {
      int initialMatchesCount = matches.length;
      matchDate = matchDate.add(
        const Duration(days: 7),
      ); // Break between halves

      for (int i = 0; i < initialMatchesCount; i++) {
        MatchModel original = matches[i];
        matches.add(
          MatchModel(
            id: const Uuid().v4(),
            competitionId: competitionId,
            team1Id: original.team2Id,
            team1Name: original.team2Name,
            team1LogoUrl: original.team2LogoUrl,
            team2Id: original.team1Id,
            team2Name: original.team1Name,
            team2LogoUrl: original.team1LogoUrl,
            scheduledTime: matchDate.add(
              Duration(days: i ~/ (teams.length / 2) * 3),
            ), // Rough schedule
            status: AppConstants.matchStatusScheduled,
            round:
                'Round ${numRounds + int.parse(original.round!.split(' ')[1])}',
          ),
        );
      }
    }

    return matches;
  }

  // Knockout Tree Generation
  static List<MatchModel> generateKnockoutFixtures({
    required String competitionId,
    required List<TeamModel> teams,
    required DateTime startDate,
    bool randomSeed = true,
    int startMatchNumber = 1,
  }) {
    List<MatchModel> matches = [];
    if (teams.length < 2) return matches;

    List<TeamModel> seededTeams = List.from(teams);
    if (randomSeed) seededTeams.shuffle();

    // Determine nearest power of 2
    int powerOf2 = 1;
    while (powerOf2 < seededTeams.length) {
      powerOf2 *= 2;
    }

    // Handle initial round (Round of X)
    // Actually, simple apps usually just do Round 1 with available pairs.
    // Let's pair them up. Ideally we want exactly PowerOf2 teams.
    // Byes would be complex to UI visualize without a bracket view.
    // We will just pair top to bottom.

    int matchCount = seededTeams.length ~/ 2;
    DateTime matchDate = startDate;

    for (int i = 0; i < matchCount; i++) {
      matches.add(
        MatchModel(
          id: const Uuid().v4(),
          competitionId: competitionId,
          team1Id: seededTeams[i * 2].id,
          team1Name: seededTeams[i * 2].name,
          team1LogoUrl: seededTeams[i * 2].logoUrl,
          team2Id: seededTeams[i * 2 + 1].id,
          team2Name: seededTeams[i * 2 + 1].name,
          team2LogoUrl: seededTeams[i * 2 + 1].logoUrl,
          scheduledTime: matchDate.add(
            Duration(hours: 10 + (i % 4) * 2),
          ), // Different times
          status: AppConstants.matchStatusScheduled,
          round: 'Round 1',
          matchNumber: startMatchNumber + i,
        ),
      );
    }

    // Future work: Generate empty placeholder matches for Round 2?
    // "Winner of Match A vs Winner of Match B"
    // For now, let's just generate the active round. The user can generate "Next Round" later maybe?
    // Requirement says "Automatically creating knockout brackets".
    // Usually that implies the whole structure.

    return matches;
  }

  // Groups + Knockout
  static List<MatchModel> generateGroupsKnockoutFixtures({
    required String competitionId,
    required List<TeamModel> teams,
    required DateTime startDate,
    required int numberOfGroups,
  }) {
    List<MatchModel> matches = [];

    // Group teams by their assigned group
    final Map<String, List<TeamModel>> groupedTeams = {};

    // Initialize groups based on numberOfGroups if we want to force specific names or just dynamic
    // But better to trust the teams
    for (var team in teams) {
      final groupName = team.group ?? 'Unassigned';
      groupedTeams.putIfAbsent(groupName, () => []).add(team);
    }

    int currentMatchNum = 1;

    // Sort group names to be deterministic
    final sortedGroupNames = groupedTeams.keys.toList()..sort();

    for (var groupName in sortedGroupNames) {
      final groupTeamList = groupedTeams[groupName]!;

      // Only generate if we have at least 2 teams
      if (groupTeamList.length < 2) continue;

      List<MatchModel> groupMatches = generateLeagueFixtures(
        competitionId: competitionId,
        teams: groupTeamList,
        startDate: startDate,
        startMatchNumber: currentMatchNum,
      );

      currentMatchNum += groupMatches.length;

      // Ensure matches are labeled with the correct group
      for (var m in groupMatches) {
        matches.add(
          MatchModel(
            id: m.id,
            competitionId: m.competitionId,
            team1Id: m.team1Id,
            team1Name: m.team1Name,
            team1LogoUrl: m.team1LogoUrl,
            team2Id: m.team2Id,
            team2Name: m.team2Name,
            team2LogoUrl: m.team2LogoUrl,
            scheduledTime: m.scheduledTime,
            status: m.status,
            round: m.round, // Keep round info (e.g. Round 1, Round 2)
            group: groupName, // Explicitly set the group name from the team
            matchNumber: m.matchNumber,
          ),
        );
      }
    }

    return matches;
  }

  // Generate Next Knockout Round
  static List<MatchModel> generateNextKnockoutRound({
    required String competitionId,
    required List<MatchModel> previousRoundMatches,
    int startMatchNumber = 1,
  }) {
    List<MatchModel> nextRoundMatches = [];

    // Sort matches by scheduledTime to ensure bracket order is maintained if generated sequentially
    previousRoundMatches.sort(
      (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
    );

    int nextRoundMatchCount = previousRoundMatches.length ~/ 2;
    String roundName = _getRoundName(nextRoundMatchCount);

    // Determine start time (e.g., 2 days after last match of previous round)
    DateTime lastMatchTime = previousRoundMatches
        .map((m) => m.scheduledTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    DateTime startTime = lastMatchTime.add(const Duration(days: 2));

    for (int i = 0; i < nextRoundMatchCount; i++) {
      MatchModel m1 = previousRoundMatches[i * 2];
      MatchModel m2 = previousRoundMatches[i * 2 + 1];

      // Determine Winners
      String? winner1Id = _getWinnerId(m1);
      String? winner1Name = _getWinnerName(m1);
      String? winner2Id = _getWinnerId(m2);
      String? winner2Name = _getWinnerName(m2);

      if (winner1Id != null && winner2Id != null) {
        nextRoundMatches.add(
          MatchModel(
            id: const Uuid().v4(),
            competitionId: competitionId,
            team1Id: winner1Id,
            team1Name: winner1Name!,
            team1LogoUrl: _getWinnerLogo(m1),
            team2Id: winner2Id,
            team2Name: winner2Name!,
            team2LogoUrl: _getWinnerLogo(m2),
            scheduledTime: startTime.add(
              Duration(hours: 14 + (i * 3)),
            ), // Staggered times
            status: AppConstants.matchStatusScheduled,
            round: roundName,
            matchNumber: startMatchNumber + i,
          ),
        );
      }
    }

    return nextRoundMatches;
  }

  static String _getRoundName(int matchCount) {
    switch (matchCount) {
      case 1:
        return 'Final';
      case 2:
        return 'Semi Final';
      case 4:
        return 'Quarter Final';
      case 8:
        return 'Round of 16';
      default:
        return 'Round of ${matchCount * 2}';
    }
  }

  static String? _getWinnerId(MatchModel match) {
    if (match.actualScore == null) return null;
    int s1 = match.actualScore!['team1'] ?? 0;
    int s2 = match.actualScore!['team2'] ?? 0;
    if (s1 > s2) return match.team1Id;
    if (s2 > s1) return match.team2Id;
    return match.team1Id; // Fallback for draw
  }

  static String? _getWinnerName(MatchModel match) {
    if (match.actualScore == null) return null;
    int s1 = match.actualScore!['team1'] ?? 0;
    int s2 = match.actualScore!['team2'] ?? 0;
    if (s1 > s2) return match.team1Name;
    if (s2 > s1) return match.team2Name;
    return match.team1Name; // Fallback
  }

  static String? _getWinnerLogo(MatchModel match) {
    if (match.actualScore == null) return null;
    int s1 = match.actualScore!['team1'] ?? 0;
    int s2 = match.actualScore!['team2'] ?? 0;
    if (s1 > s2) return match.team1LogoUrl;
    if (s2 > s1) return match.team2LogoUrl;
    return match.team1LogoUrl; // Fallback
  }

  // Generate Full Knockout Tree
  static List<MatchModel> generateFullKnockoutFixtures({
    required String competitionId,
    required List<TeamModel> teams,
    required DateTime startDate,
    bool randomSeed = true,
  }) {
    List<MatchModel> allMatches = [];
    if (teams.length < 2) return allMatches;

    // 1. Generate Round 1 (Real Teams)
    List<MatchModel> currentRound = generateKnockoutFixtures(
      competitionId: competitionId,
      teams: teams,
      startDate: startDate,
      randomSeed: randomSeed,
      startMatchNumber: 1,
    );
    allMatches.addAll(currentRound);

    // 2. Generate Subsequent Rounds (Placeholders)
    int currentMatchNum = 1 + currentRound.length;
    DateTime roundDate = startDate.add(const Duration(days: 2));

    while (currentRound.length > 1) {
      List<MatchModel> nextRound = [];
      int matchCount = currentRound.length ~/ 2;
      String roundName = _getRoundName(matchCount);

      for (int i = 0; i < matchCount; i++) {
        // Logic to link to previous matches could be added here if we stored dependencies
        // For MVP, we just create empty slots
        nextRound.add(
          MatchModel(
            id: const Uuid().v4(),
            competitionId: competitionId,
            team1Id: 'TBD',
            team1Name: 'Winner of Match ${currentRound[i * 2].matchNumber}',
            team2Id: 'TBD',
            team2Name: 'Winner of Match ${currentRound[i * 2 + 1].matchNumber}',
            scheduledTime: roundDate.add(Duration(hours: 14 + (i * 3))),
            status: AppConstants.matchStatusScheduled,
            round: roundName,
            matchNumber: currentMatchNum++,
          ),
        );
      }

      allMatches.addAll(nextRound);
      currentRound = nextRound;
      roundDate = roundDate.add(const Duration(days: 2));
    }

    return allMatches;
  }
}
