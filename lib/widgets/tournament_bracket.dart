import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match_model.dart';
import '../constants/app_constants.dart';
import '../widgets/loading_spinner.dart';
import '../services/firestore_service.dart';
import 'package:provider/provider.dart';

class TournamentBracket extends StatelessWidget {
  final String competitionId;

  const TournamentBracket({super.key, required this.competitionId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return StreamBuilder<List<MatchModel>>(
      stream: firestoreService.getMatches(competitionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingSpinner());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const Center(
            child: Text(
              'No matches generated yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // 1. Group matches by round
        final Map<String, List<MatchModel>> groupedMatches = {};
        for (var match in matches) {
          final round = match.round ?? 'Unknown';
          if (!groupedMatches.containsKey(round)) {
            groupedMatches[round] = [];
          }
          groupedMatches[round]!.add(match);
        }

        // 2. Determine round order
        // We want: Round 1 -> Round 2 ... -> Quarter Final -> Semi Final -> Final
        // A simple heuristic: sorted by the number of matches in descending order (Round 1 has most)
        // But some rounds might be partially completed.
        // Better: Predefined priority + logic
        final sortedRounds = groupedMatches.keys.toList()
          ..sort((a, b) => _compareRounds(a, b, groupedMatches));

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(40),
          minScale: 0.1,
          maxScale: 1.0,
          constrained: false, // Allows the child to be larger than the viewport
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedRounds.map((round) {
                return _buildRoundColumn(
                  context,
                  round,
                  groupedMatches[round]!,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  int _compareRounds(String a, String b, Map<String, List<MatchModel>> groups) {
    // Predefined order for known knockout rounds
    final order = {
      'Final': 100,
      'Semi Final': 90,
      'Quarter Final': 80,
      'Round of 16': 70,
      'Round of 32': 60,
    };

    int weightA = order[a] ?? _getRoundNumber(a);
    int weightB = order[b] ?? _getRoundNumber(b);

    // If both are "Round X", compare numerically (lower is earlier)
    // If one is "Final" (100) and other is "Round 1" (1), 1 should come first for left-to-right
    // So lower weight comes FIRST in the list.
    return weightA.compareTo(weightB);
  }

  int _getRoundNumber(String round) {
    if (round.startsWith('Round ')) {
      try {
        return int.parse(round.substring(6));
      } catch (_) {}
    }
    return 0; // Default if unknown
  }

  Widget _buildRoundColumn(
    BuildContext context,
    String roundName,
    List<MatchModel> roundMatches,
  ) {
    // Sort matches in the round by matchNumber or time
    roundMatches.sort(
      (a, b) => (a.matchNumber ?? 0).compareTo(b.matchNumber ?? 0),
    );

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          // Round Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              roundName.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Matches
          ...roundMatches.map((match) => _buildBracketMatch(context, match)),
        ],
      ),
    );
  }

  Widget _buildBracketMatch(BuildContext context, MatchModel match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.isLive ? AppColors.accentGreen : AppColors.dividerColor,
          width: match.isLive ? 2 : 1,
        ),
        boxShadow: [
          if (match.isLive)
            BoxShadow(
              color: AppColors.accentGreen.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamRow(
            match.team1Name,
            match.actualScore?['team1'],
            match.winnerId == match.team1Id,
          ),
          const Divider(color: AppColors.dividerColor, height: 16),
          _buildTeamRow(
            match.team2Name,
            match.actualScore?['team2'],
            match.winnerId == match.team2Id,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'M#${match.matchNumber ?? ""}',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
              if (match.isLive)
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (match.isUpcoming)
                Text(
                  DateFormat('MMM d, h:mm a').format(match.scheduledTime),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(String name, int? score, bool isWinner) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner ? Colors.white : AppColors.textSecondary,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
        if (score != null)
          Text(
            score.toString(),
            style: TextStyle(
              color: isWinner ? AppColors.accentGreen : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          )
        else
          Text('-', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
      ],
    );
  }
}
