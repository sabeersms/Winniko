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
import '../services/tournament_data_service.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'All';

    // Auto-sync on load for official tournaments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSync(force: false);
    });
  }

  Future<void> _triggerSync({bool force = false}) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (widget.competition.leagueId != null &&
        widget.competition.leagueId!.isNotEmpty) {
      // We allow syncing from official leagues for everyone (it's a cheap Firestore read)
      // but only Master Admins see the success/failure snackbars by default to avoid noise.
      try {
        final updates = await TournamentDataService.refreshCompetitionFixtures(
          competitionId: widget.competition.id,
          leagueId: widget.competition.leagueId!,
          firestore: firestore,
          force: force,
        );

        if (mounted && (authService.isMasterAdmin || force)) {
          if (updates > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Synced $updates matches from official league'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Auto-sync error: $e');
      }
    }
  }

  @override
  void dispose() {
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
              actions: [
                if (authService.isMasterAdmin &&
                    widget.competition.leagueId != null)
                  IconButton(
                    icon: const Icon(Icons.sync),
                    tooltip: 'Force Sync',
                    onPressed: () => _triggerSync(force: true),
                  ),
              ],
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
            child: RefreshIndicator(
              onRefresh: () => _triggerSync(force: true),
              child: StreamBuilder<List<MatchModel>>(
                stream: firestore.getMatches(widget.competition.id),
                builder: (context, matchSnapshot) {
                  if (matchSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: LoadingSpinner());
                  }

                  final allMatches = matchSnapshot.data ?? [];
                  var matches = List<MatchModel>.from(allMatches);

                  // Sort matches: Sort by scheduledTime first, then matchNumber
                  // If filtering by "Completed" OR if ALL matches are completed, sort Descending (Latest first)
                  // Otherwise Ascending (Oldest first)
                  bool isCompletedFilter = _selectedFilter == 'Completed';
                  bool allCompleted =
                      matches.isNotEmpty && matches.every((m) => m.isCompleted);

                  matches.sort((a, b) {
                    final timeCompare = a.scheduledTime.compareTo(
                      b.scheduledTime,
                    );

                    // For "Completed" or Archives, prioritize TIME (Latest first)
                    if (isCompletedFilter || allCompleted) {
                      // Reverse order (Newest first)
                      if (timeCompare != 0) return -timeCompare;
                      return 0;
                    }

                    // For "All" / "Pending" / "Live": Ascending (Oldest first)
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
                    matches = matches.where((m) => m.isLive).toList();
                  } else if (_selectedFilter == 'Completed') {
                    matches = matches.where((m) => m.isFinished).toList();
                  }

                  // Match Generation Logic (Organizer Only)
                  bool showGenerateButton = false;
                  List<MatchModel> lastRoundMatches = [];

                  if (!widget.isParticipant &&
                      widget.competition.organizerId == currentUser?.uid &&
                      allMatches.isNotEmpty &&
                      !widget.competition.isPublic &&
                      (widget.competition.format ==
                              AppConstants.formatKnockout ||
                          widget.competition.format ==
                              AppConstants.formatGroupsKnockout)) {
                    // Sort by time
                    final sorted = List<MatchModel>.from(allMatches)
                      ..sort(
                        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
                      );
                    final lastMatch = sorted.last;

                    // Ignore if already Final
                    if (lastMatch.round != 'Final') {
                      final lastRoundName = lastMatch.round;
                      lastRoundMatches = sorted
                          .where((m) => m.round == lastRoundName)
                          .toList();

                      // Check if all completed
                      if (lastRoundMatches.every((m) => m.isCompleted)) {
                        showGenerateButton = true;
                      }
                    }
                  }

                  // Auto-scroll logic: Calculate target index purely for initialScrollIndex
                  int targetIndex = 0;
                  if (_selectedFilter == 'All' &&
                      matches.isNotEmpty &&
                      !allCompleted) {
                    final firstUpcomingIndex = matches.indexWhere(
                      (m) => !m.isCompleted,
                    );
                    if (firstUpcomingIndex != -1) {
                      targetIndex = (firstUpcomingIndex - 1) < 0
                          ? 0
                          : (firstUpcomingIndex - 1);
                    } else {
                      targetIndex = matches.length - 1;
                    }
                  }
                  // If all completed (Descending), start at 0 (Newest)
                  if (allCompleted) {
                    targetIndex = 0;
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
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
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
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
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
                                    if (predictionSnapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error: ${predictionSnapshot.error}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      );
                                    }
                                    final predictions =
                                        predictionSnapshot.data ?? [];
                                    return ScrollablePositionedList.builder(
                                      key: Key(
                                        'MatchesList_${_selectedFilter}_Participant_$targetIndex',
                                      ),
                                      initialScrollIndex: targetIndex,
                                      itemScrollController:
                                          _itemScrollController,
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
                                              (p) =>
                                                  p.matchId.toString() ==
                                                  match.id.toString(),
                                            )
                                            ? predictions.firstWhere(
                                                (p) =>
                                                    p.matchId.toString() ==
                                                    match.id.toString(),
                                              )
                                            : null;

                                        return _buildMatchCard(
                                          context,
                                          match,
                                          existingPrediction: prediction,
                                          firestore: firestore,
                                        );
                                      },
                                    );
                                  },
                                )
                              : ScrollablePositionedList.builder(
                                  key: Key(
                                    'MatchesList_${_selectedFilter}_Standard_$targetIndex',
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
                                      firestore: firestore,
                                    );
                                  },
                                ),
                        ),
                    ],
                  );
                },
              ),
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
    MatchModel match, {
    PredictionModel? existingPrediction,
    required FirestoreService firestore,
  }) {
    // Retrieve User object for MatchCardWidget
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    return MatchCardWidget(
      existingPrediction: existingPrediction,
      match: match,
      competition: widget.competition,
      isParticipant: widget.isParticipant,
      currentUser: user,
      firestore: firestore,
      onShowPredictionDialog:
          (
            ctx,
            m, {
            existingPrediction,
            required firestore,
            required currentUserId,
          }) {
            _showPredictionDialog(
              ctx,
              m,
              existingPrediction: existingPrediction,
            );
          },
    );
  }

  void _showPredictionDialog(
    BuildContext context,
    MatchModel match, {
    PredictionModel? existingPrediction,
  }) {
    final sport = widget.competition.sport;
    final isCricket = sport.toLowerCase().contains('cricket');
    debugPrint('Predictions: Sport="$sport", isCricket=$isCricket');

    // Breadcrumb 1
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Debug: Routing for $sport (Is Cricket: $isCricket)'),
        duration: const Duration(milliseconds: 500),
      ),
    );

    if (isCricket) {
      debugPrint('Predictions: Showing Cricket Dialog');
      _showCricketPredictionDialog(
        context,
        match,
        existingPrediction: existingPrediction,
      );
    } else {
      debugPrint('Predictions: Showing Score Dialog');
      _showScorePredictionDialog(
        context,
        match,
        existingPrediction: existingPrediction,
      );
    }
  }

  void _showCricketPredictionDialog(
    BuildContext context,
    MatchModel match, {
    PredictionModel? existingPrediction,
  }) {
    showDialog(
      context: context,
      builder: (context) => _CricketPredictionDialog(
        match: match,
        competitionId: widget.competition.id,
        existingPrediction: existingPrediction,
      ),
    );
  }

  void _showScorePredictionDialog(
    BuildContext context,
    MatchModel match, {
    PredictionModel? existingPrediction,
  }) {
    showDialog(
      context: context,
      builder: (context) => _FootballPredictionDialog(
        match: match,
        existingPrediction: existingPrediction,
        competition: widget.competition,
      ),
    );
  }
}

// End of _MatchesListScreenState

class MatchCardWidget extends StatefulWidget {
  final MatchModel match;
  final CompetitionModel competition;
  final bool isParticipant;
  final dynamic currentUser; // User?
  final FirestoreService firestore;
  final PredictionModel? existingPrediction;
  final Function(
    BuildContext,
    MatchModel, {
    PredictionModel? existingPrediction,
    required FirestoreService firestore,
    required String? currentUserId,
  })
  onShowPredictionDialog;

  const MatchCardWidget({
    super.key,
    required this.match,
    required this.competition,
    required this.isParticipant,
    required this.currentUser,
    required this.firestore,
    this.existingPrediction,
    required this.onShowPredictionDialog,
  });

  @override
  State<MatchCardWidget> createState() => _MatchCardWidgetState();
}

class _MatchCardWidgetState extends State<MatchCardWidget> {
  Timer? _timer;
  late String _timeDisplay;
  bool _showCountdown = false;
  @override
  void initState() {
    super.initState();
    _updateTimeDisplay();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant MatchCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match != widget.match) {
      _updateTimeDisplay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    // Only start timer if match is scheduled/upcoming
    if (widget.match.status == AppConstants.matchStatusScheduled ||
        widget.match.status == AppConstants.matchStatusUpcoming) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _updateTimeDisplay();
          });
        }
      });
    }
  }

  void _updateTimeDisplay() {
    final now = DateTime.now();
    final diff = widget.match.scheduledTime.difference(now);
    final isWithin24Hours = diff.inHours <= 24 && !diff.isNegative;

    if (isWithin24Hours &&
        (widget.match.status == AppConstants.matchStatusScheduled ||
            widget.match.status == AppConstants.matchStatusUpcoming)) {
      _showCountdown = true;
      if (diff.isNegative) {
        _timeDisplay = 'Starts in 00:00:00';
      } else {
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        _timeDisplay = 'Starts in $h:$m:$s';
      }
    } else {
      _showCountdown = false;
      _timeDisplay = DateFormat(
        'EEE, MMM d | h:mm a',
      ).format(widget.match.scheduledTime);
    }
  }

  String _getDisplayStatus() {
    // Explicit statuses take precedence
    if (widget.match.status == AppConstants.matchStatusLive) {
      return 'PROGRESSING';
    }
    if (widget.match.isCompleted) {
      return 'COMPLETED';
    }

    // Handle 'Upcoming' / 'Scheduled' with time-based inference
    final now = DateTime.now();
    final diff = now.difference(widget.match.scheduledTime);

    if (diff.isNegative) {
      // Start time is in the future
      return 'UPCOMING';
    }

    // Start time is in the past
    // Determine 'Ongoing' duration threshold based on sport
    int ongoingDurationHours = 4; // Default (Football, etc.)
    if (widget.competition.sport.toLowerCase().contains('cricket')) {
      ongoingDurationHours = 12; // Allow for ODIs/longer matches
    }

    if (diff.inHours < ongoingDurationHours) {
      return 'PROGRESSING';
    } else {
      return 'COMPLETED';
    }
  }

  Color _getDisplayColor(String statusText) {
    switch (statusText) {
      case 'PROGRESSING':
        return Colors.orange;
      case 'COMPLETED':
        return AppColors.textSecondary;
      case 'UPCOMING':
      default:
        return AppColors.accentGreen;
    }
  }

  // Helper to get teams in batting order for cricket
  Map<String, dynamic> _getTeamsInBattingOrder() {
    final bool isCricket =
        widget.competition.sport == AppConstants.sportCricket;

    if (!isCricket) {
      // For non-cricket, use default order (team1 left, team2 right)
      return {
        'leftTeamId': widget.match.team1Id,
        'leftTeamName': widget.match.team1Name,
        'leftTeamLogo': widget.match.team1LogoUrl,
        'rightTeamId': widget.match.team2Id,
        'rightTeamName': widget.match.team2Name,
        'rightTeamLogo': widget.match.team2LogoUrl,
      };
    }

    // For cricket, check battingFirstId
    final battingFirstId = widget.match.actualScore?['battingFirstId'];

    if (battingFirstId == null) {
      // No batting order info, use default
      return {
        'leftTeamId': widget.match.team1Id,
        'leftTeamName': widget.match.team1Name,
        'leftTeamLogo': widget.match.team1LogoUrl,
        'rightTeamId': widget.match.team2Id,
        'rightTeamName': widget.match.team2Name,
        'rightTeamLogo': widget.match.team2LogoUrl,
      };
    }

    // Reorder based on batting order
    if (battingFirstId == widget.match.team1Id) {
      // Team1 batted first -> Team1 left, Team2 right
      return {
        'leftTeamId': widget.match.team1Id,
        'leftTeamName': widget.match.team1Name,
        'leftTeamLogo': widget.match.team1LogoUrl,
        'rightTeamId': widget.match.team2Id,
        'rightTeamName': widget.match.team2Name,
        'rightTeamLogo': widget.match.team2LogoUrl,
      };
    } else {
      // Team2 batted first -> Team2 left, Team1 right
      return {
        'leftTeamId': widget.match.team2Id,
        'leftTeamName': widget.match.team2Name,
        'leftTeamLogo': widget.match.team2LogoUrl,
        'rightTeamId': widget.match.team1Id,
        'rightTeamName': widget.match.team1Name,
        'rightTeamLogo': widget.match.team1LogoUrl,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = widget.currentUser?.uid;
    final bool canPredict =
        widget.isParticipant &&
        widget.competition.organizerId != currentUserId &&
        (widget.match.status == AppConstants.matchStatusScheduled ||
            widget.match.status == AppConstants.matchStatusUpcoming) &&
        widget.match.scheduledTime.isAfter(DateTime.now()) &&
        widget.match.scheduledTime.difference(DateTime.now()).inHours <= 24;

    final bool hasPredicted = widget.existingPrediction != null;

    final displayStatus = _getDisplayStatus();
    final statusColor = _getDisplayColor(displayStatus);

    return GestureDetector(
      onTap: () {
        final bool isOrganizer =
            widget.competition.organizerId == currentUserId;

        if (isOrganizer) {
          // Check if Custom Tournament
          final bool isCustomTournament =
              widget.competition.leagueId == null ||
              widget.competition.leagueId!.isEmpty;

          if (isCustomTournament) {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.cardBackground,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.edit_calendar,
                      color: AppColors.accentGreen,
                    ),
                    title: const Text(
                      'Edit Date & Time',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);

                      // Check if match is verified
                      if (widget.match.actualScore?['verified'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This match has been verified by a super admin and cannot be rescheduled.',
                            ),
                            backgroundColor: AppColors.error,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }

                      final date = await showDatePicker(
                        context: context,
                        initialDate: widget.match.scheduledTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.accentGreen,
                                onPrimary: Colors.white,
                                surface: AppColors.cardBackground,
                                onSurface: Colors.white,
                              ),
                              dialogTheme: DialogThemeData(
                                backgroundColor: AppColors.cardBackground,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            widget.match.scheduledTime,
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.accentGreen,
                                  onPrimary: Colors.white,
                                  surface: AppColors.cardBackground,
                                  onSurface: Colors.white,
                                ),
                                timePickerTheme: const TimePickerThemeData(
                                  backgroundColor: AppColors.cardBackground,
                                  hourMinuteTextColor: Colors.white,
                                  dayPeriodTextColor: Colors.white,
                                  dialHandColor: AppColors.accentGreen,
                                  dialBackgroundColor: AppColors.backgroundDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (time != null && context.mounted) {
                          final newDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );

                          // Update Firestore
                          try {
                            final updatedMatch = widget.match.copyWith(
                              scheduledTime: newDateTime,
                            );
                            // Use updateBatchMatches for single update
                            await widget.firestore.updateBatchMatches(
                              widget.competition.id,
                              [updatedMatch],
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Match rescheduled!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.scoreboard,
                      color: AppColors.accentGreen,
                    ),
                    title: const Text(
                      'Update Score',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (DateTime.now().isBefore(widget.match.scheduledTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot update score before match start time',
                            ),
                          ),
                        );
                        return;
                      }

                      // Check if match is verified
                      if (widget.match.actualScore?['verified'] == true &&
                          !authService.isMasterAdmin) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This match is verified and can only be edited by a super admin.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchScoreScreen(
                            match: widget.match,
                            sport: widget.competition.sport,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          } else {
            if (DateTime.now().isBefore(widget.match.scheduledTime)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot update score before match start time'),
                ),
              );
              return;
            }

            // Check if match is verified
            if (widget.match.actualScore?['verified'] == true &&
                !authService.isMasterAdmin) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This match is verified and can only be edited by a super admin.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchScoreScreen(
                  match: widget.match,
                  sport: widget.competition.sport,
                ),
              ),
            );
          }
        } else if (canPredict) {
          widget.onShowPredictionDialog(
            context,
            widget.match,
            existingPrediction: widget.existingPrediction,
            firestore: widget.firestore,
            currentUserId: currentUserId,
          );
        }
      },
      child: Container(
        // Removed RepaintBoundary key logic for simplicity
        color: AppColors.backgroundDark,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date / Match # / Countdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.match.matchNumber != null &&
                              widget.competition.leagueId == null)
                            Text(
                              'Match ${widget.match.matchNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _timeDisplay,
                            style: TextStyle(
                              color: _showCountdown
                                  ? Colors.amberAccent
                                  : AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: _showCountdown ? 'RobotoMono' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                              match: widget.match,
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
                        color: statusColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        children: [
                          if (displayStatus == 'PROGRESSING')
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
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
                    // Left Team (First batting team for cricket, Team1 for others)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final teams = _getTeamsInBattingOrder();
                          return Column(
                            children: [
                              TeamLogo(
                                url: teams['leftTeamLogo'],
                                teamName: teams['leftTeamName'],
                                size: 40,
                                backgroundColor: AppColors.backgroundDark,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                teams['leftTeamName'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Score Middle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildScoreSection(context),
                    ),

                    // Right Team (Second batting team for cricket, Team2 for others)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final teams = _getTeamsInBattingOrder();
                          return Column(
                            children: [
                              TeamLogo(
                                url: teams['rightTeamLogo'],
                                teamName: teams['rightTeamName'],
                                size: 40,
                                backgroundColor: AppColors.backgroundDark,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                teams['rightTeamName'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (hasPredicted)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.accentGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          // Helper to get winner name from prediction
                          Builder(
                            builder: (context) {
                              final pred = widget.existingPrediction!;
                              final pMap = pred.prediction;
                              String text = 'Predicted: ';

                              // Determine Winner Name
                              String wName = '';
                              if (pMap.containsKey('winnerName')) {
                                wName = pMap['winnerName'].toString();
                              } else if (pMap['winnerId'] ==
                                  widget.match.team1Id) {
                                wName = widget.match.team1Name;
                              } else if (pMap['winnerId'] ==
                                  widget.match.team2Id) {
                                wName = widget.match.team2Name;
                              } else if (pMap.containsKey('team1') &&
                                  pMap.containsKey('team2')) {
                                // Football-style score comparison fallback
                                try {
                                  final t1 = int.parse(
                                    pMap['team1'].toString(),
                                  );
                                  final t2 = int.parse(
                                    pMap['team2'].toString(),
                                  );
                                  if (t1 > t2) {
                                    wName = widget.match.team1Name;
                                  } else if (t2 > t1) {
                                    wName = widget.match.team2Name;
                                  } else {
                                    wName = 'Draw';
                                  }
                                } catch (_) {
                                  wName = 'Draw';
                                }
                              } else {
                                wName = 'Draw';
                              }
                              text += wName;

                              // Collect Margins
                              List<String> margins = [];
                              if (pMap.containsKey('runs')) {
                                margins.add('${pMap['runs']} Runs');
                              }
                              if (pMap.containsKey('wickets')) {
                                margins.add('${pMap['wickets']} Wickets');
                              }

                              // Legacy Fallback
                              if (margins.isEmpty) {
                                if (pMap.containsKey('margin') &&
                                    pMap.containsKey('marginType')) {
                                  margins.add(
                                    '${pMap['margin']} ${pMap['marginType']}',
                                  );
                                } else if (pMap.containsKey('team1') &&
                                    pMap.containsKey('team2')) {
                                  margins.add(
                                    '${pMap['team1']} - ${pMap['team2']}',
                                  );
                                }
                              }

                              if (margins.isNotEmpty) {
                                text += ' (${margins.join(' / ')})';
                              }

                              return Flexible(
                                child: Text(
                                  text,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.accentGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // Show "Tap to Predict" button if user can predict but hasn't
                // REMOVED DUPLICATE BUTTON CODE HERE
              ], // Column children
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context) {
    // Recalculate canPredict here as it's local logic for this widget state
    final currentUserId = widget.currentUser?.uid;
    final bool canPredict =
        widget.isParticipant &&
        widget.competition.organizerId != currentUserId &&
        (widget.match.status == AppConstants.matchStatusScheduled ||
            widget.match.status == AppConstants.matchStatusUpcoming) &&
        widget.match.scheduledTime.isAfter(DateTime.now()) &&
        widget.match.scheduledTime.difference(DateTime.now()).inHours <= 24;

    if (widget.match.actualScore != null) {
      // If the match is currently LIVE/PROGRESSING, show scores if available, else show message
      if (widget.match.status == AppConstants.matchStatusLive ||
          widget.match.status == AppConstants.matchStatusProgressing) {
        final hasAnyScore =
            widget.match.actualScore != null &&
            (widget.match.actualScore!['team1'] != null ||
                widget.match.actualScore!['t1Runs'] != null);

        if (!hasAnyScore) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats, color: Colors.orange, size: 24),
              SizedBox(height: 4),
              Text(
                'MATCH PROGRESSING',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }
        // If it has scores, proceed to build the score section normally even if live
      }

      if (widget.competition.sport == AppConstants.sportCricket) {
        final winnerId = widget.match.resolvedWinnerId ?? '';
        final t1Runs =
            int.tryParse(
              widget.match.actualScore?['t1Runs']?.toString() ?? '0',
            ) ??
            0;
        final t2Runs =
            int.tryParse(
              widget.match.actualScore?['t2Runs']?.toString() ?? '0',
            ) ??
            0;

        final bool isTieBreaker =
            (t1Runs != 0 && t1Runs == t2Runs) &&
            winnerId != 'tied' &&
            winnerId != 'no_result' &&
            winnerId.isNotEmpty;

        if (winnerId == 'tied' || isTieBreaker) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MATCH TIED',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isTieBreaker)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    winnerId == widget.match.team1Id
                        ? '${widget.match.team1Name} Won (S/O)'
                        : '${widget.match.team2Name} Won (S/O)',
                    style: const TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        } else if (winnerId == 'no_result') {
          return const Text(
            'NO RESULT',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          );
        } else {
          // Pre-process scores to handle missing data
          int t1Runs =
              int.tryParse(
                widget.match.actualScore!['t1Runs']?.toString() ?? '0',
              ) ??
              0;
          int t2Runs =
              int.tryParse(
                widget.match.actualScore!['t2Runs']?.toString() ?? '0',
              ) ??
              0;
          final String marginType =
              widget.match.actualScore!['marginType']?.toString() ?? '';
          final int marginVal =
              int.tryParse(
                widget.match.actualScore!['marginValue']?.toString() ?? '0',
              ) ??
              0;
          final String winnerId = widget.match.resolvedWinnerId ?? '';

          // Infer missing score if won by runs
          if (marginType == 'runs' && marginVal > 0) {
            if (t1Runs > 0 && t2Runs == 0 && winnerId == widget.match.team1Id) {
              t2Runs = t1Runs - marginVal;
            } else if (t2Runs > 0 &&
                t1Runs == 0 &&
                winnerId == widget.match.team2Id) {
              t1Runs = t2Runs - marginVal;
            }
          }

          // Validation: Don't show confusing 0/0 scores if data is missing
          bool showScore = true;
          if (t1Runs == 0 && t2Runs == 0) showScore = false;
          if ((t1Runs == 0 || t2Runs == 0) &&
              widget.match.status.toLowerCase().contains('won')) {
            // If someone won but one team has 0, it's likely data error
            showScore = false;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showScore)
                Builder(
                  builder: (context) {
                    // Get scores in batting order
                    final battingFirstId =
                        widget.match.actualScore?['battingFirstId'];
                    final t1Wickets =
                        widget.match.actualScore!['t1Wickets'] ?? 0;
                    final t2Wickets =
                        widget.match.actualScore!['t2Wickets'] ?? 0;

                    String scoreText;
                    if (battingFirstId == null ||
                        battingFirstId == widget.match.team1Id) {
                      // Team1 batted first or no info -> show t1 - t2
                      scoreText = '$t1Runs/$t1Wickets - $t2Runs/$t2Wickets';
                    } else {
                      // Team2 batted first -> show t2 - t1
                      scoreText = '$t2Runs/$t2Wickets - $t1Runs/$t1Wickets';
                    }

                    return Text(
                      scoreText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 4),
              // Result Summary
              Text(
                widget.match.resolvedWinnerId == widget.match.team1Id
                    ? '${widget.match.team1Name} Won'
                    : '${widget.match.team2Name} Won',
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
                      widget.match.actualScore?['marginType']?.toString() ?? '';
                  String val =
                      widget.match.actualScore?['marginValue']?.toString() ??
                      '?';

                  if (type == 'runs' && (val == '?' || val == '0')) {
                    final t1 =
                        int.tryParse(
                          widget.match.actualScore?['t1Runs']?.toString() ??
                              '0',
                        ) ??
                        0;
                    final t2 =
                        int.tryParse(
                          widget.match.actualScore?['t2Runs']?.toString() ??
                              '0',
                        ) ??
                        0;
                    val = (t1 - t2).abs().toString();
                  }

                  // Fix pluralization and handle case variations
                  String displayType = type;
                  final typeLower = type.toLowerCase();

                  if (typeLower == 'wickets' || typeLower == 'wicket') {
                    displayType = (val == '1') ? 'wicket' : 'wickets';
                  } else if (typeLower == 'runs' || typeLower == 'run') {
                    displayType = (val == '1') ? 'run' : 'runs';
                  } else if (displayType.isEmpty) {
                    // Fallback based on sport type
                    if (widget.competition.sport.toLowerCase() == 'cricket') {
                      displayType = (val == '1') ? 'wicket' : 'wickets';
                    } else {
                      displayType = 'points';
                    }
                  }

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
          );
        }
      } else {
        // Standard (Football)
        return Column(
          children: [
            Text(
              '${widget.match.actualScore!['team1'] ?? 0} - ${widget.match.actualScore!['team2'] ?? 0}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.match.isFinished) ...[
              if (widget.match.resolvedWinnerId == 'draw' ||
                  (widget.match.actualScore!['team1'] ==
                          widget.match.actualScore!['team2'] &&
                      (widget.match.resolvedWinnerId == null ||
                          widget.match.resolvedWinnerId == 'draw')))
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text(
                    'DRAW',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else if (widget.match.resolvedWinnerId == widget.match.team1Id)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${widget.match.team1Name} Win',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGreen,
                    ),
                  ),
                )
              else if (widget.match.resolvedWinnerId == widget.match.team2Id)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${widget.match.team2Name} Win',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
            ],
          ],
        );
      }
    } else {
      // No Score (Upcoming or Completed-with-no-score)

      final statusLower = widget.match.status.toLowerCase();
      final isResult =
          statusLower != AppConstants.matchStatusScheduled &&
          statusLower != AppConstants.matchStatusUpcoming &&
          statusLower != AppConstants.matchStatusLive &&
          statusLower != AppConstants.matchStatusProgressing &&
          statusLower != 'progressing';

      if (isResult) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              widget.match.status.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }

      if (canPredict) {
        // Show Predict Button
        return ElevatedButton.icon(
          onPressed: () {
            if (widget.currentUser?.uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please login to predict')),
              );
              return;
            }
            widget.onShowPredictionDialog(
              context,
              widget.match,
              existingPrediction: widget.existingPrediction,
              firestore: widget.firestore,
              currentUserId: widget.currentUser?.uid,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen.withValues(alpha: 0.1),
            foregroundColor: AppColors.accentGreen,
            elevation: 0,
            side: const BorderSide(color: AppColors.accentGreen),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(
            widget.competition.sport.toLowerCase().contains('cricket')
                ? Icons.sports_cricket
                : Icons.touch_app,
            size: 16,
          ),
          label: const Text(
            'Predict',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        // Cannot predict (Time window or role), show VS
        return Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }
  }
}

class _CricketPredictionDialog extends StatefulWidget {
  final MatchModel match;
  final String competitionId;
  final PredictionModel? existingPrediction;

  const _CricketPredictionDialog({
    required this.match,
    required this.competitionId,
    this.existingPrediction,
  });

  @override
  State<_CricketPredictionDialog> createState() =>
      _CricketPredictionDialogState();
}

class _CricketPredictionDialogState extends State<_CricketPredictionDialog> {
  String? selectedWinner;
  String? selectedRunMargin;
  String? selectedWicketMargin;
  bool isMatchTie = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPrediction != null) {
      final pMap = widget.existingPrediction!.prediction;
      selectedWinner = pMap['winnerId']?.toString();

      // Check for Tie
      if (pMap['isTie'] == true) {
        isMatchTie = true;
      } else {
        // Load separate margins
        selectedRunMargin = pMap['runs']?.toString();
        selectedWicketMargin = pMap['wickets']?.toString();

        // Fallback for legacy data (if only 'margin' exists)
        if (selectedRunMargin == null && selectedWicketMargin == null) {
          final legacyMargin = pMap['margin']?.toString();
          final legacyType = pMap['marginType']?.toString();
          if (legacyType == 'runs') {
            selectedRunMargin = legacyMargin;
          } else if (legacyType == 'wickets') {
            selectedWicketMargin = legacyMargin;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(
        0xFF25422D,
      ), // Brighter, more vibrant dark green
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Match Prediction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Winner Selection Group
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), // Subtle contrast
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildCompactWinnerTab(
                      label: widget.match.team1Name,
                      isSelected:
                          !isMatchTie && selectedWinner == widget.match.team1Id,
                      onTap: () => setState(() {
                        selectedWinner = widget.match.team1Id;
                        isMatchTie = false;
                      }),
                    ),
                    _buildCompactWinnerTab(
                      label: 'Tie',
                      isSelected: isMatchTie,
                      onTap: () => setState(() {
                        isMatchTie = true;
                        selectedWinner = null;
                      }),
                    ),
                    _buildCompactWinnerTab(
                      label: widget.match.team2Name,
                      isSelected:
                          !isMatchTie && selectedWinner == widget.match.team2Id,
                      onTap: () => setState(() {
                        selectedWinner = widget.match.team2Id;
                        isMatchTie = false;
                      }),
                    ),
                  ],
                ),
              ),

              if (isMatchTie) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.stars, color: AppColors.accentGreen, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tie predicts max points (5 pts)',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!isMatchTie) ...[
                const SizedBox(height: 20),
                // Wicket Selection
                const Text(
                  'Margin: Wickets (Bowling First)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: AppConstants.cricketWicketMargins.map((margin) {
                      final isSelected = selectedWicketMargin == margin;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildMarginChip(
                          label: margin,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => selectedWicketMargin = margin),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),
                // Run Selection
                const Text(
                  'Margin: Runs (Batting First)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: AppConstants.cricketRunMargins.map((margin) {
                      final isSelected = selectedRunMargin == margin;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildMarginChip(
                          label: margin,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => selectedRunMargin = margin),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  if (!isMatchTie && selectedWinner == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a winner or Match Tie'),
                      ),
                    );
                    return;
                  }

                  if (!isMatchTie &&
                      (selectedRunMargin == null ||
                          selectedWicketMargin == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select margins')),
                    );
                    return;
                  }

                  try {
                    final firestore = Provider.of<FirestoreService>(
                      context,
                      listen: false,
                    );
                    final auth = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );

                    String winnerName = 'Match Tie';
                    if (!isMatchTie) {
                      winnerName = selectedWinner == widget.match.team1Id
                          ? widget.match.team1Name
                          : widget.match.team2Name;
                    }

                    final prediction = PredictionModel(
                      userId: auth.currentUser!.uid,
                      matchId: widget.match.id,
                      competitionId: widget.competitionId,
                      prediction: {
                        'isTie': isMatchTie,
                        'winnerId': isMatchTie ? null : selectedWinner,
                        'winnerName': winnerName,
                        'runs': isMatchTie ? null : selectedRunMargin,
                        'wickets': isMatchTie ? null : selectedWicketMargin,
                      },
                      timestamp: DateTime.now(),
                    );

                    await firestore.submitPrediction(prediction);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isMatchTie
                                ? 'Predicted: Match Tie'
                                : 'Predicted: $winnerName ($selectedRunMargin Runs / $selectedWicketMargin Wkts)',
                          ),
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
                  'Submit Prediction',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactWinnerTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGreen.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accentGreen
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _FootballPredictionDialog extends StatefulWidget {
  final MatchModel match;
  final PredictionModel? existingPrediction;
  final CompetitionModel competition;

  const _FootballPredictionDialog({
    required this.match,
    this.existingPrediction,
    required this.competition,
  });

  @override
  _FootballPredictionDialogState createState() =>
      _FootballPredictionDialogState();
}

class _FootballPredictionDialogState extends State<_FootballPredictionDialog> {
  late TextEditingController t1Controller;
  late TextEditingController t2Controller;
  String? selectedOutcome; // 'team1', 'draw', 'team2'

  @override
  void initState() {
    super.initState();
    final p = widget.existingPrediction?.prediction;
    t1Controller = TextEditingController(text: p?['team1']?.toString() ?? '');
    t2Controller = TextEditingController(text: p?['team2']?.toString() ?? '');
    _updateOutcomeSelection();
  }

  void _updateOutcomeSelection() {
    final t1 = int.tryParse(t1Controller.text);
    final t2 = int.tryParse(t2Controller.text);
    if (t1 != null && t2 != null) {
      if (t1 > t2) {
        selectedOutcome = 'team1';
      } else if (t2 > t1) {
        selectedOutcome = 'team2';
      } else {
        selectedOutcome = 'draw';
      }
    } else {
      selectedOutcome = null;
    }
  }

  void _selectOutcome(String outcome) {
    setState(() {
      selectedOutcome = outcome;
      if (outcome == 'team1' &&
          (int.tryParse(t1Controller.text) ?? 0) <=
              (int.tryParse(t2Controller.text) ?? 0)) {
        t1Controller.text = '1';
        t2Controller.text = '0';
      } else if (outcome == 'draw' &&
          (int.tryParse(t1Controller.text) ?? 0) !=
              (int.tryParse(t2Controller.text) ?? 1)) {
        t1Controller.text = '1';
        t2Controller.text = '1';
      } else if (outcome == 'team2' &&
          (int.tryParse(t2Controller.text) ?? 0) <=
              (int.tryParse(t1Controller.text) ?? 0)) {
        t1Controller.text = '0';
        t2Controller.text = '1';
      }
    });
  }

  Widget _buildOutcomeCard({
    required String label,
    required String id,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectOutcome(id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGreen.withValues(alpha: 0.1)
                : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentGreen
                  : AppColors.dividerColor,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        'Predict: ${widget.match.team1Name} vs ${widget.match.team2Name}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Selection (Winner or Draw):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildOutcomeCard(
                  label: widget.match.team1Name,
                  id: 'team1',
                  isSelected: selectedOutcome == 'team1',
                ),
                const SizedBox(width: 8),
                _buildOutcomeCard(
                  label: 'Draw',
                  id: 'draw',
                  isSelected: selectedOutcome == 'draw',
                ),
                const SizedBox(width: 8),
                _buildOutcomeCard(
                  label: widget.match.team2Name,
                  id: 'team2',
                  isSelected: selectedOutcome == 'team2',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Precise Score Prediction:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: t1Controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setState(() => _updateOutcomeSelection()),
                    decoration: InputDecoration(
                      labelText: widget.match.team1Name,
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.dividerColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentGreen),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: t2Controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setState(() => _updateOutcomeSelection()),
                    decoration: InputDecoration(
                      labelText: widget.match.team2Name,
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.dividerColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentGreen),
                      ),
                    ),
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
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
          ),
          onPressed: () async {
            final t1 = int.tryParse(t1Controller.text);
            final t2 = int.tryParse(t2Controller.text);
            if (t1 == null || t2 == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter valid scores')),
              );
              return;
            }

            try {
              final firestore = Provider.of<FirestoreService>(
                context,
                listen: false,
              );
              final auth = Provider.of<AuthService>(context, listen: false);

              final prediction = PredictionModel(
                userId: auth.currentUser!.uid,
                matchId: widget.match.id,
                competitionId: widget.competition.id,
                prediction: {
                  'team1': t1,
                  'team2': t2,
                  'winnerId': t1 > t2
                      ? widget.match.team1Id
                      : (t2 > t1 ? widget.match.team2Id : 'draw'),
                  'winnerName': t1 > t2
                      ? widget.match.team1Name
                      : (t2 > t1 ? widget.match.team2Name : 'Draw'),
                },
                timestamp: DateTime.now(),
              );

              await firestore.submitPrediction(prediction);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prediction submitted!')),
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
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
