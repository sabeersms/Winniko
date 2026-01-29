import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/prediction_model.dart';
import 'match_create_screen.dart';
import 'match_score_screen.dart';
import '../widgets/team_logo.dart';
import '../widgets/loading_spinner.dart';
import 'dialogs/share_match_dialog.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MatchesListScreen extends StatefulWidget {
  final CompetitionModel competition;
  final bool embed;
  final bool isParticipant;
  final String? initialFilter;

  const MatchesListScreen({
    super.key,
    required this.competition,
    this.embed = false,
    this.isParticipant = false,
    this.initialFilter,
  });

  @override
  State<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends State<MatchesListScreen> {
  late String _selectedFilter; // 'All', 'Pending', 'Live', 'Completed'
  bool _isLoading = false;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  final Map<String, GlobalKey> _cardKeys = {};

  GlobalKey _getCardKey(String matchId) {
    return _cardKeys.putIfAbsent(matchId, () => GlobalKey());
  }

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'All';
    _triggerSync();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _triggerSync();
    });
  }

  void _triggerSync() {
    if (widget.competition.leagueId != null) {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      firestore.syncOfficialTournamentScores(
        competitionId: widget.competition.id,
        leagueId: widget.competition.leagueId!,
      );
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    // ItemScrollController and ItemPositionsListener do not need disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: widget.embed
          ? null
          : AppBar(
              title: Text('${widget.competition.name} Matches'),
              actions: [],
            ),
      floatingActionButton:
          (!widget.embed &&
              !widget.isParticipant &&
              !widget.competition.isPublic)
          ? FloatingActionButton(
              backgroundColor: AppColors.accentGreen,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                final teams = await firestore
                    .getTeams(widget.competition.id)
                    .first;
                if (!context.mounted) {
                  return;
                }

                if (teams.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not enough teams to create a match'),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchCreateScreen(
                      competitionId: widget.competition.id,
                      teams: teams,
                    ),
                  ),
                );
              },
            )
          : null,
      body: Column(
        children: [
          // Filter Chips & Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pending'), // Scheduled
                        const SizedBox(width: 8),
                        _buildFilterChip('Live'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Matches List
          Expanded(
            child: StreamBuilder<List<MatchModel>>(
              stream: firestore.getMatches(widget.competition.id),
              builder: (context, matchSnapshot) {
                if (matchSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingSpinner());
                }

                final allMatches = matchSnapshot.data ?? [];
                var matches = List<MatchModel>.from(allMatches);

                // Sort matches: Sort by scheduledTime first, then matchNumber
                // If filtering by "Completed", sort Descending (Latest first)
                // Otherwise Ascending (Oldest first)
                bool isCompletedFilter = _selectedFilter == 'Completed';

                matches.sort((a, b) {
                  final timeCompare = a.scheduledTime.compareTo(
                    b.scheduledTime,
                  );

                  // For "Completed", prioritize TIME (Latest first)
                  if (isCompletedFilter) {
                    // Reverse order (Newest first)
                    if (timeCompare != 0) return -timeCompare;
                    return 0;
                  }

                  // For "All" / "Pending": Ascending (Oldest first)
                  return timeCompare;
                });

                // Apply Filter
                if (_selectedFilter == 'Pending') {
                  matches = matches
                      .where(
                        (m) =>
                            m.status == AppConstants.matchStatusScheduled ||
                            m.status == AppConstants.matchStatusUpcoming,
                      )
                      .toList();
                } else if (_selectedFilter == 'Live') {
                  matches = matches
                      .where((m) => m.status == AppConstants.matchStatusLive)
                      .toList();
                } else if (_selectedFilter == 'Completed') {
                  matches = matches
                      .where(
                        (m) => m.status == AppConstants.matchStatusCompleted,
                      )
                      .toList();
                }

                // Match Generation Logic (Organizer Only)
                bool showGenerateButton = false;
                List<MatchModel> lastRoundMatches = [];

                if (!widget.isParticipant &&
                    widget.competition.organizerId == currentUser?.uid &&
                    allMatches.isNotEmpty &&
                    !widget.competition.isPublic &&
                    (widget.competition.format == AppConstants.formatKnockout ||
                        widget.competition.format ==
                            AppConstants.formatGroupsKnockout)) {
                  // Sort by time
                  final sorted = List<MatchModel>.from(
                    allMatches,
                  )..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
                  final lastMatch = sorted.last;

                  // Ignore if already Final
                  if (lastMatch.round != 'Final') {
                    final lastRoundName = lastMatch.round;
                    lastRoundMatches = sorted
                        .where((m) => m.round == lastRoundName)
                        .toList();

                    // Check if all completed
                    if (lastRoundMatches.every(
                      (m) => m.status == AppConstants.matchStatusCompleted,
                    )) {
                      showGenerateButton = true;
                    }
                  }
                }

                // Auto-scroll logic: Calculate target index purely for initialScrollIndex
                int targetIndex = 0;
                if (_selectedFilter == 'All' && matches.isNotEmpty) {
                  final firstUpcomingIndex = matches.indexWhere(
                    (m) => m.status != AppConstants.matchStatusCompleted,
                  );
                  if (firstUpcomingIndex != -1) {
                    targetIndex = (firstUpcomingIndex - 1) < 0
                        ? 0
                        : (firstUpcomingIndex - 1);
                  } else {
                    targetIndex = matches.length - 1;
                  }
                }

                return Column(
                  children: [
                    if (showGenerateButton)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      await firestore.generateNextRound(
                                        widget.competition.id,
                                        lastRoundMatches,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Next round generated!',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.next_plan),
                            label: const Text('Generate Next Round'),
                          ),
                        ),
                      ),
                    if (matches.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedFilter == 'All'
                                    ? Icons.sports_soccer
                                    : Icons.filter_list_off,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'All'
                                    ? 'No matches scheduled'
                                    : 'No $_selectedFilter matches',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: widget.isParticipant && currentUser != null
                            ? StreamBuilder<List<PredictionModel>>(
                                stream: firestore.getUserPredictions(
                                  currentUser.uid,
                                  widget.competition.id,
                                ),
                                builder: (context, predictionSnapshot) {
                                  final predictions =
                                      predictionSnapshot.data ?? [];
                                  return ScrollablePositionedList.builder(
                                    key: Key(
                                      'MatchesList_${_selectedFilter}_Participant',
                                    ),
                                    initialScrollIndex: targetIndex,
                                    itemScrollController: _itemScrollController,
                                    itemPositionsListener:
                                        _itemPositionsListener,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    itemCount: matches.length,
                                    itemBuilder: (context, index) {
                                      final match = matches[index];
                                      final prediction =
                                          predictions.any(
                                            (p) => p.matchId == match.id,
                                          )
                                          ? predictions.firstWhere(
                                              (p) => p.matchId == match.id,
                                            )
                                          : null;

                                      return _buildMatchCard(
                                        context,
                                        match,
                                        firestore,
                                        prediction: prediction,
                                        currentUserId: currentUser.uid,
                                      );
                                    },
                                  );
                                },
                              )
                            : ScrollablePositionedList.builder(
                                key: Key(
                                  'MatchesList_${_selectedFilter}_Standard',
                                ),
                                initialScrollIndex: targetIndex,
                                itemScrollController: _itemScrollController,
                                itemPositionsListener: _itemPositionsListener,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: matches.length,
                                itemBuilder: (context, index) {
                                  final match = matches[index];
                                  return _buildMatchCard(
                                    context,
                                    match,
                                    firestore,
                                    currentUserId: currentUser?.uid,
                                  );
                                },
                              ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      backgroundColor: AppColors.cardBackground,
      selectedColor: AppColors.accentGreen.withAlpha(51),
      checkmarkColor: AppColors.accentGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.accentGreen : AppColors.dividerColor,
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    MatchModel match,
    FirestoreService firestore, {
    PredictionModel? prediction,
    String? currentUserId,
  }) {
    final bool canPredict =
        widget.isParticipant &&
        widget.competition.organizerId !=
            currentUserId && // Organizer cannot predict
        (match.status == AppConstants.matchStatusScheduled ||
            match.status == AppConstants.matchStatusUpcoming) &&
        match.scheduledTime.isAfter(DateTime.now());

    final bool hasPredicted = prediction != null;

    return GestureDetector(
      onTap: () {
        final bool isOrganizer =
            widget.competition.organizerId == currentUserId;

        if (isOrganizer) {
          if (DateTime.now().isBefore(match.scheduledTime)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot update score before match start time'),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchScoreScreen(
                match: match,
                sport: widget.competition.sport,
              ),
            ),
          );
        } else if (canPredict) {
          _showPredictionDialog(context, match, existingPrediction: prediction);
        }
      },
      child: RepaintBoundary(
        key: _getCardKey(match.id),
        child: Container(
          color: AppColors.backgroundDark, // Background for screenshot
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date / Match #
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (match.matchNumber != null &&
                                widget.competition.leagueId == null)
                              Text(
                                'Match ${match.matchNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'EEE, MMM d • h:mm a',
                              ).format(match.scheduledTime),
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Share Button
                      // Share Button (Organizer Only)
                      if (widget.competition.organizerId == currentUserId)
                        IconButton(
                          icon: const Icon(
                            Icons.share,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ShareMatchDialog(
                                match: match,
                                competitionName: widget.competition.name,
                                sport: widget.competition.sport,
                              ),
                            );
                          },
                        ),
                      if (widget.competition.organizerId == currentUserId)
                        const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(match.status).withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getStatusColor(match.status),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (match.status == AppConstants.matchStatusLive)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              match.status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(match.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Home Team
                      Expanded(
                        child: Column(
                          children: [
                            TeamLogo(
                              url: match.team1LogoUrl,
                              teamName: match.team1Name,
                              size: 40,
                              backgroundColor: AppColors.backgroundDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              match.team1Name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score or VS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            if (match.actualScore != null) ...[
                              // Cricket Display Logic
                              if (widget.competition.sport ==
                                      AppConstants.sportCricket &&
                                  (match.status ==
                                          AppConstants.matchStatusCompleted ||
                                      match.status ==
                                          AppConstants.matchStatusLive)) ...[
                                if (match.actualScore?['winnerId'] == 'tied')
                                  const Text(
                                    'TIED',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (match.actualScore?['winnerId'] ==
                                    'no_result')
                                  const Text(
                                    'NO RESULT',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Scoreline
                                      Text(
                                        '${match.actualScore!['t1Runs'] ?? 0}/${match.actualScore!['t1Wickets'] ?? 0} - ${match.actualScore!['t2Runs'] ?? 0}/${match.actualScore!['t2Wickets'] ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Result Summary
                                      Text(
                                        match.actualScore!['winnerId'] ==
                                                match.team1Id
                                            ? '${match.team1Name} Won'
                                            : '${match.team2Name} Won',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentGreen,
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final String type =
                                              match.actualScore?['marginType']
                                                  ?.toString() ??
                                              '';
                                          String val =
                                              match.actualScore?['marginValue']
                                                  ?.toString() ??
                                              '?';

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
                                            val = (t1 - t2).abs().toString();
                                          }

                                          final String displayType =
                                              (val == '1' && type == 'wickets')
                                              ? 'wicket'
                                              : type;

                                          return Text(
                                            'by $val $displayType',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              ] else ...[
                                // Standard / Football Display
                                Text(
                                  '${match.actualScore!['team1'] ?? 0} - ${match.actualScore!['team2'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (match.actualScore!['team1'] ==
                                        match.actualScore!['team2'] &&
                                    match.actualScore!['winnerId'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      match.actualScore!['winnerId'] ==
                                              match.team1Id
                                          ? '${match.team1Name} Win'
                                          : '${match.team2Name} Win',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentGreen,
                                      ),
                                    ),
                                  ),
                              ],
                            ] else
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accentGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.accentGreen,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Away Team
                      Expanded(
                        child: Column(
                          children: [
                            TeamLogo(
                              url: match.team2LogoUrl,
                              teamName: match.team2Name,
                              size: 40,
                              backgroundColor: AppColors.backgroundDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              match.team2Name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Organizer Actions
                  if (match.status == AppConstants.matchStatusScheduled &&
                      widget.competition.organizerId == currentUserId &&
                      !widget.competition.isPublic)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Edit Button
                          TextButton.icon(
                            onPressed: () async {
                              // Fetch teams for dropdown
                              try {
                                final teams = await firestore
                                    .getTeams(widget.competition.id)
                                    .first;
                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchCreateScreen(
                                      competitionId: widget.competition.id,
                                      teams: teams,
                                      match: match,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading teams: $e'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.accentGreen,
                            ),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Result Button
                          TextButton.icon(
                            onPressed: () {
                              if (DateTime.now().isBefore(
                                match.scheduledTime,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot update score before match start time',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchScoreScreen(
                                    match: match,
                                    sport: widget.competition.sport,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.assignment_turned_in,
                              size: 16,
                              color:
                                  DateTime.now().isBefore(match.scheduledTime)
                                  ? AppColors.textSecondary
                                  : AppColors.accentGreen,
                            ),
                            label: Text(
                              'Result',
                              style: TextStyle(
                                color:
                                    DateTime.now().isBefore(match.scheduledTime)
                                    ? AppColors.textSecondary
                                    : AppColors.accentGreen,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete Button
                          TextButton.icon(
                            onPressed: () {
                              // Strict Delete confirmation
                              final codeController = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.cardBackground,
                                  title: const Text(
                                    'Remove Match?',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'This will permanently remove the match and all associated predictions. This CANNOT be undone.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Type "DELETE" to confirm:',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: codeController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'DELETE',
                                          hintStyle: TextStyle(
                                            color: Colors.white24,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.white24,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        if (codeController.text == 'DELETE') {
                                          Navigator.pop(ctx);
                                          await firestore.deleteMatch(
                                            widget.competition.id,
                                            match.id,
                                          );
                                        }
                                      },
                                      child: const Text(
                                        'Delete Forever',
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Prediction Status Button
                  if (canPredict)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _showPredictionDialog(
                          context,
                          match,
                          existingPrediction: prediction,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: Text(
                          hasPredicted
                              ? 'Edit Prediction'
                              : (widget.competition.sport ==
                                        AppConstants.sportCricket
                                    ? 'Predict Runs'
                                    : 'Predict Score'),
                        ),
                      ),
                    ),
                  if (hasPredicted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.accentGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: AutoSizeText(
                          widget.competition.sport == AppConstants.sportCricket
                              ? 'Predicted: ${prediction.prediction['winnerId'] == 'tied' ? 'Draw' : (prediction.prediction['winnerId'] == match.team1Id ? match.team1Name : match.team2Name)} to win by ${prediction.prediction['runs']} runs / ${prediction.prediction['wickets']} wickets'
                              : 'Predicted: ${prediction.prediction['team1']} - ${prediction.prediction['team2']}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          minFontSize: 10,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPredictionDialog(
    BuildContext context,
    MatchModel match, {
    PredictionModel? existingPrediction,
  }) {
    final team1Controller = TextEditingController(
      text: existingPrediction?.prediction['team1']?.toString() ?? '',
    );
    final team2Controller = TextEditingController(
      text: existingPrediction?.prediction['team2']?.toString() ?? '',
    );

    // For Cricket
    String? cricketWinnerId = existingPrediction?.prediction['winnerId'];
    String? predictRuns = existingPrediction?.prediction['runs'];
    String? predictWickets = existingPrediction?.prediction['wickets'];

    // For Football/Generic
    int? t1Score = existingPrediction?.prediction['team1'];
    int? t2Score = existingPrediction?.prediction['team2'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bool isCricket =
                widget.competition.sport == AppConstants.sportCricket;

            if (isCricket) {
              return AlertDialog(
                backgroundColor: AppColors.cardBackground,
                title: Text(
                  existingPrediction != null
                      ? 'Edit Prediction'
                      : 'Make a Prediction',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Winner',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: Text(
                          match.team1Name,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        value: match.team1Id,
                        groupValue: cricketWinnerId,
                        activeColor: AppColors.accentGreen,
                        onChanged: (val) =>
                            setState(() => cricketWinnerId = val),
                      ),
                      RadioListTile<String>(
                        title: Text(
                          match.team2Name,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        value: match.team2Id,
                        groupValue: cricketWinnerId,
                        activeColor: AppColors.accentGreen,
                        onChanged: (val) =>
                            setState(() => cricketWinnerId = val),
                      ),
                      RadioListTile<String>(
                        title: const Text(
                          'Draw',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        value: 'tied',
                        groupValue: cricketWinnerId,
                        activeColor: AppColors.accentGreen,
                        onChanged: (val) => setState(() {
                          cricketWinnerId = val;
                          predictRuns = null; // Reset runs if draw is selected
                          predictWickets = null;
                        }),
                      ),
                      const Divider(color: AppColors.dividerColor, height: 32),
                      if (cricketWinnerId != 'tied') ...[
                        const Text(
                          "If batting first (Win by Runs)",
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: predictRuns,
                          hint: const Text('Select Runs Range'),
                          dropdownColor: AppColors.cardBackground,
                          items: AppConstants.cricketRunMargins
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => predictRuns = val),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "If batting second (Win by Wickets)",
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: predictWickets,
                          hint: const Text('Select Wickets'),
                          dropdownColor: AppColors.cardBackground,
                          items: AppConstants.cricketWicketMargins
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => predictWickets = val),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: const Text(
                            "If the match ends in a Draw, you will receive FULL POINTS.\nNo margin prediction needed.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (cricketWinnerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a winner'),
                          ),
                        );
                        return;
                      }
                      if (cricketWinnerId != 'tied' &&
                          (predictRuns == null || predictWickets == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please predict both Runs and Wickets scenarios',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        final user = Provider.of<AuthService>(
                          context,
                          listen: false,
                        ).currentUser!;
                        final prediction = PredictionModel(
                          userId: user.uid,
                          matchId: match.id,
                          competitionId: widget.competition.id,
                          prediction: {
                            'winnerId': cricketWinnerId,
                            'runs': predictRuns,
                            'wickets': predictWickets,
                          },
                          timestamp: DateTime.now(),
                        );
                        await Provider.of<FirestoreService>(
                          context,
                          listen: false,
                        ).submitPrediction(prediction);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Prediction Submitted!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text(
                      'Predict',
                      style: TextStyle(color: AppColors.accentGreen),
                    ),
                  ),
                ],
              );
            }

            // Determine if this is a league round where draws are allowed
            final bool isLeagueRound =
                widget.competition.format == AppConstants.formatLeague ||
                match.group != null ||
                (widget.competition.format ==
                        AppConstants.formatLeagueKnockout &&
                    RegExp(r'^Round \d+$').hasMatch(match.round ?? ''));

            t1Score == t2Score;

            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                existingPrediction != null
                    ? 'Edit Prediction'
                    : 'Make a Prediction',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${match.team1Name} vs ${match.team2Name}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Team 1
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                match.team1Name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: team1Controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.inputBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      t1Score = int.tryParse(val);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            ' - ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        // Team 2
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                match.team2Name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: team2Controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.inputBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      t2Score = int.tryParse(val);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (t1Score == null || t2Score == null) {
                      return;
                    }

                    if (t1Score == t2Score && !isLeagueRound) {
                      // Removed Tie Breaker Warning
                    }

                    try {
                      final authService = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      final firestore = Provider.of<FirestoreService>(
                        context,
                        listen: false,
                      );
                      final user = authService.currentUser!;

                      final prediction = PredictionModel(
                        userId: user.uid,
                        matchId: match.id,
                        competitionId: widget.competition.id,
                        prediction: {'team1': t1Score!, 'team2': t2Score!},
                        timestamp: DateTime.now(),
                        // tieBreakerWinnerId: selectedWinnerId, // Removed
                      );

                      await firestore.submitPrediction(prediction);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Prediction Submitted!'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text(
                    'Predict',
                    style: TextStyle(color: AppColors.accentGreen),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status == AppConstants.matchStatusLive) {
      return AppColors.error; // Red for live
    }
    if (status == AppConstants.matchStatusCompleted) {
      return AppColors.textSecondary;
    }
    return AppColors.accentGreen; // Green for upcoming
  }
}
