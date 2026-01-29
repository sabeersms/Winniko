import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

import '../models/competition_model.dart';
import '../models/user_model.dart';
import '../models/participant_model.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../services/tournament_data_service.dart';
import '../models/standing_model.dart';
import '../widgets/standings_poster.dart';
import '../utils/share_util.dart';

import 'leaderboard_screen.dart';
import 'participant_leaderboard_screen.dart';
import 'matches_list_screen.dart';
import 'competition_chat_screen.dart';
import 'organizer_chat_list_screen.dart';
import 'direct_chat_screen.dart';
import '../widgets/loading_spinner.dart';

import 'terms_and_conditions_screen.dart';
import '../widgets/share_competition_dialog.dart';
import 'full_fixtures_screen.dart';
import '../services/ad_service.dart';

class CompetitionDetailScreen extends StatefulWidget {
  final String competitionId;
  final int initialTab;

  const CompetitionDetailScreen({
    super.key,
    required this.competitionId,
    this.initialTab = 0,
  });

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with SingleTickerProviderStateMixin {
  CompetitionModel? _competition;
  UserModel? _currentUser;
  ParticipantModel? _participant;
  bool _isLoading = true;
  bool _hasJoined = false;
  bool _isJoining = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ... _loadData, _joinCompetition, _leaveCompetition, _syncMatches methods remain the same ...
  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final competition = await firestoreService.getCompetition(
        widget.competitionId,
      );

      // Trigger auto-refresh for active official tournaments
      if (competition != null &&
          competition.leagueId != null &&
          competition.leagueId!.isNotEmpty &&
          competition.status == 'active') {
        TournamentDataService.refreshCompetitionFixtures(
          competitionId: widget.competitionId,
          leagueId: competition.leagueId!,
          firestore: firestoreService,
        ).catchError((e) => debugPrint('Auto-refresh error: $e'));
      }
      final userId = authService.currentUserId;

      if (userId != null) {
        final user = await authService.getUserProfile(userId);
        final hasJoined = await firestoreService.hasJoinedCompetition(
          userId,
          widget.competitionId,
        );

        ParticipantModel? participant;
        if (hasJoined) {
          participant = await firestoreService.getParticipant(
            widget.competitionId,
            userId,
          );
        }

        if (competition != null && user != null) {
          // Location check removed
          // isEligible = await locationService.isEligibleForCompetition(...);

          // Ensure Join Code exists (Self-healing for older competitions)
          if (competition.joinCode.isEmpty &&
              user.id == competition.organizerId) {
            await firestoreService.ensureJoinCode(competition.id);
            // Reload competition to get the code
            final updatedCompetition = await firestoreService.getCompetition(
              widget.competitionId,
            );
            if (updatedCompetition != null) {
              setState(() {
                _competition = updatedCompetition;
                _currentUser = user;
                _hasJoined = hasJoined;
                _participant = participant;
                _isLoading = false;
              });
              return;
            }
          }
        }

        setState(() {
          _competition = competition;
          _currentUser = user;
          _hasJoined = hasJoined;
          _participant = participant;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinCompetition() async {
    if (_currentUser == null || _competition == null) return;

    // Show Ad before Joining
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please watch this short ad to join the competition!'),
        duration: Duration(seconds: 2),
      ),
    );

    AdService().showInterstitialAd(
      onAdDismissed: () async {
        if (!mounted) return;

        // Check for Terms and Conditions
        if (_competition!.termsAndConditions != null &&
            _competition!.termsAndConditions!.isNotEmpty) {
          final participantPrototype = ParticipantModel(
            userId: _currentUser!.id,
            userName: _currentUser!.name,
            photoUrl: _currentUser!.photoUrl,
            phoneNumber: _currentUser!.phone,
            competitionId: widget.competitionId,
            joinedAt: DateTime.now(),
          );

          // Navigate to T&C Screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TermsAndConditionsScreen(
                competition: _competition!,
                participant: participantPrototype,
              ),
            ),
          );

          // Upon return, check if they joined (by refreshing data)
          _loadData();
          return;
        }

        setState(() {
          _isJoining = true;
        });

        try {
          final firestoreService = Provider.of<FirestoreService>(
            context,
            listen: false,
          );

          final participant = ParticipantModel(
            userId: _currentUser!.id,
            userName: _currentUser!.name,
            photoUrl: _currentUser!.photoUrl,
            phoneNumber: _currentUser!.phone,
            competitionId: widget.competitionId,
            joinedAt: DateTime.now(),
          );

          await firestoreService.joinCompetition(
            widget.competitionId,
            participant,
          );

          // Send System Message
          try {
            final sysMsg = MessageModel(
              id: '',
              senderId: 'system',
              senderName: 'System',
              text: '${_currentUser!.name} joined the competition!',
              timestamp: DateTime.now(),
              isOrganizer: false,
              isSystem: true,
            );
            await firestoreService.sendMessage(widget.competitionId, sysMsg);
          } catch (_) {}

          setState(() {
            _hasJoined = true;
            _isJoining = false;
          });

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined competition!'),
              backgroundColor: AppColors.success,
            ),
          );
        } catch (e) {
          if (mounted) {
            setState(() => _isJoining = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error joining: $e')));
          }
        }
      },
    );
  }

  Future<void> _leaveCompetition() async {
    if (_participant == null || _currentUser == null || _competition == null) {
      return;
    }

    // Check restriction: Cannot leave if made predictions
    if (_participant!.totalPredictions > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot leave competition after making predictions.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Leave Competition?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to leave this competition?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.leaveCompetition(_competition!.id, _currentUser!.id);

      setState(() {
        _hasJoined = false;
        _participant = null;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the competition.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _syncMatches() async {
    if (_competition == null) return;

    // Use stored leagueId if available (robust), otherwise try name matching (legacy)
    final leagueId =
        _competition!.leagueId ??
        TournamentDataService.getLeagueIdByName(_competition!.name);

    if (leagueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot sync: Unknown league')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      // 1. Get existing teams
      final teams = await firestore.getTeams(_competition!.id).first;

      // 2. Fetch latest data
      final latestMatches = await TournamentDataService.getTournamentFixtures(
        _competition!.id,
        leagueId,
        teams,
      );

      // 3. Get existing matches
      final existingMatches = await firestore
          .getMatches(_competition!.id)
          .first;

      int updatedCount = 0;
      for (var newMatch in latestMatches) {
        // Find existing match by teams
        MatchModel? existing;
        for (var m in existingMatches) {
          if (m.team1Id == newMatch.team1Id && m.team2Id == newMatch.team2Id) {
            existing = m;
            break;
          }
        }

        if (existing != null) {
          bool needsUpdate = false;
          // Check status
          if (existing.status != newMatch.status) needsUpdate = true;
          // Check time (if changed significantly, e.g. rescheduled)
          if (existing.scheduledTime != newMatch.scheduledTime) {
            needsUpdate = true;
          }

          // Check scores
          final oldS = existing.actualScore;
          final newS = newMatch.actualScore;
          if (oldS == null && newS != null) needsUpdate = true;
          if (oldS != null && newS == null) needsUpdate = true;
          if (oldS != null && newS != null) {
            if (oldS['team1'] != newS['team1'] ||
                oldS['team2'] != newS['team2']) {
              needsUpdate = true;
            }
          }

          if (needsUpdate) {
            final isLiveOrCompleted =
                newMatch.status == AppConstants.matchStatusLive ||
                newMatch.status == AppConstants.matchStatusCompleted;

            if (isLiveOrCompleted && newMatch.actualScore != null) {
              if (existing.scheduledTime != newMatch.scheduledTime) {
                await firestore.updateMatch(
                  existing.copyWith(scheduledTime: newMatch.scheduledTime),
                );
              }

              await firestore.updateMatchScore(
                _competition!.id,
                existing.id,
                newMatch.actualScore!,
                newMatch.status,
                oldScore: existing.actualScore,
              );
            } else {
              await firestore.updateMatch(newMatch.copyWith(id: existing.id));
            }
            updatedCount++;
          }
        }
      }

      await firestore.recalculateStandings(_competition!.id);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced! Updated $updatedCount matches.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generatePdfShim() async {
    setState(() => _isLoading = true);
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final matches = await firestore.getMatches(widget.competitionId).first;
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FullFixturesScreen(competition: _competition!, matches: matches),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading matches: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(title: const Text('Competition Details')),
        body: const Center(child: LoadingSpinner(color: AppColors.accentGreen)),
      );
    }

    if (_competition == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(title: const Text('Competition Details')),
        body: const Center(
          child: Text(
            'Competition not found',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(_competition!.name),
        actions: [
          // Share Competition (Overview Tab Only)
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Competition',
              onPressed: () => showShareCompetitionDialog(
                context,
                _competition!.name,
                _competition!.joinCode,
                _competition!.sponsorName,
                _competition!.cardBackgroundImageUrl,
              ),
            ),

          // PDF Download (Matches Tab Only)
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Download Schedule PDF',
              onPressed: _generatePdfShim,
            ),

          // Manual Standings Refresh (Table Tab Only (Index 3) - Organizer Only)
          if (_tabController.index == 3 &&
              _currentUser?.id == _competition!.organizerId &&
              !(_competition!.format == AppConstants.formatKnockout ||
                  _competition!.format == AppConstants.formatSingleMatch))
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recalculate Standings',
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recalculating standings...')),
                  );
                  await Provider.of<FirestoreService>(
                    context,
                    listen: false,
                  ).recalculateStandings(_competition!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Standings updated!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating: $e')),
                    );
                  }
                }
              },
            ),

          // Sync Button (Only for Organizer of Public Competition)
          if (_currentUser?.id == _competition!.organizerId &&
              _competition!.isPublic)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync with Official Scores',
              onPressed: _syncMatches,
            ),

          if (_currentUser?.id == _competition!.organizerId)
            StreamBuilder<int>(
              stream: Provider.of<FirestoreService>(
                context,
                listen: false,
              ).getOrganizerUnreadCount(_competition!.id),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mail_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrganizerChatListScreen(
                              competition: _competition!,
                            ),
                          ),
                        );
                      },
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

          if (_tabController.index == 3 &&
              !(_competition!.format == AppConstants.formatKnockout ||
                  _competition!.format == AppConstants.formatSingleMatch) &&
              _currentUser?.id == _competition!.organizerId)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Standings Image',
              onPressed: () async {
                try {
                  final firestore = Provider.of<FirestoreService>(
                    context,
                    listen: false,
                  );
                  // Get latest data
                  final standings = await firestore
                      .getStandings(_competition!.id)
                      .first;

                  // Sort logic
                  standings.sort((a, b) {
                    // 1. Points
                    int cmp = b.points.compareTo(a.points);
                    if (cmp != 0) return cmp;

                    // 2. Dynamic Rules
                    for (final rule in _competition!.tieBreakerRules) {
                      if (rule == AppConstants.tieBreakerGoalDiff) {
                        cmp = b.goalDifference.compareTo(a.goalDifference);
                      } else if (rule == AppConstants.tieBreakerGoalsScored) {
                        cmp = b.goalsFor.compareTo(a.goalsFor);
                      } else if (rule == AppConstants.tieBreakerWins) {
                        cmp = b.won.compareTo(a.won);
                      } else if (rule == AppConstants.tieBreakerNrr) {
                        cmp = b.netRunRate.compareTo(a.netRunRate);
                      }
                      if (cmp != 0) return cmp;
                    }

                    // 3. Fallbacks
                    if (_competition!.sport == AppConstants.sportCricket) {
                      if (!_competition!.tieBreakerRules.contains(
                        AppConstants.tieBreakerWins,
                      )) {
                        cmp = b.won.compareTo(a.won);
                        if (cmp != 0) return cmp;
                      }
                      if (!_competition!.tieBreakerRules.contains(
                        AppConstants.tieBreakerNrr,
                      )) {
                        cmp = b.netRunRate.compareTo(a.netRunRate);
                        if (cmp != 0) return cmp;
                      }
                    } else {
                      if (!_competition!.tieBreakerRules.contains(
                        AppConstants.tieBreakerGoalDiff,
                      )) {
                        cmp = b.goalDifference.compareTo(a.goalDifference);
                        if (cmp != 0) return cmp;
                      }
                      if (!_competition!.tieBreakerRules.contains(
                        AppConstants.tieBreakerGoalsScored,
                      )) {
                        cmp = b.goalsFor.compareTo(a.goalsFor);
                        if (cmp != 0) return cmp;
                      }
                    }

                    return a.teamName.compareTo(b.teamName);
                  });

                  // Group Data
                  final Map<String, List<StandingModel>> groupedData = {};
                  for (var s in standings) {
                    final g = s.group ?? 'Other';
                    groupedData.putIfAbsent(g, () => []).add(s);
                  }

                  if (!context.mounted) return;

                  // Show Dialog to render and capture
                  await showDialog(
                    context: context,
                    builder: (context) {
                      final GlobalKey boundaryKey = GlobalKey();
                      return Dialog(
                        backgroundColor: Colors.black.withValues(alpha: 0.95),
                        insetPadding: EdgeInsets.zero,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Poster Preview', // Changed title
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: FittedBox(
                                      fit: BoxFit.fitWidth,
                                      child: RepaintBoundary(
                                        key: boundaryKey,
                                        child: StandingsPoster(
                                          competition: _competition!,
                                          standings: standings,
                                          groupedData: groupedData,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SafeArea(
                                top: false,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share / Save Image'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () async {
                                    try {
                                      // Wait a bit ensuring render
                                      await Future.delayed(
                                        const Duration(milliseconds: 100),
                                      );
                                      await ShareUtil.shareWidgetAsImage(
                                        key: boundaryKey,
                                        fileName:
                                            '${_competition!.name.replaceAll(' ', '_')}_standings',
                                        text:
                                            'Check out the official standings for ${_competition!.name}!',
                                      );
                                    } catch (e) {
                                      debugPrint('Error sharing: $e');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGreen,
          labelColor: AppColors.accentGreen,
          unselectedLabelColor: AppColors.textSecondary,
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Matches'),
            Tab(text: 'Leaderboard'),
            Tab(
              text:
                  (_competition!.format == AppConstants.formatKnockout ||
                      _competition!.format == AppConstants.formatSingleMatch)
                  ? 'Result'
                  : 'Table',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          MatchesListScreen(
            competition: _competition!,
            embed: true,
            isParticipant: _hasJoined,
          ),
          ParticipantLeaderboardScreen(competition: _competition!),
          (_competition!.format == AppConstants.formatKnockout ||
                  _competition!.format == AppConstants.formatSingleMatch)
              ? MatchesListScreen(
                  competition: _competition!,
                  embed: true,
                  isParticipant: _hasJoined,
                  initialFilter: 'Completed',
                )
              : LeaderboardScreen(competition: _competition!, embed: true),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Discussion')),
                      body: CompetitionChatScreen(
                        competition: _competition!,
                        isParticipant: _hasJoined,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text('Chat'),
              backgroundColor: AppColors.accentGreen,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildOverviewTab() {
    final hasBackground =
        _competition!.cardBackgroundImageUrl != null &&
        _competition!.cardBackgroundImageUrl!.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Banner Image (No Overlay)
          if (hasBackground)
            Container(
              height: 220,
              width: double.infinity,
              decoration: const BoxDecoration(color: AppColors.backgroundDark),
              child: CachedNetworkImage(
                imageUrl: _competition!.cardBackgroundImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: LoadingSpinner(size: 24)),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              color: AppColors.cardBackground,
              child: const Center(
                child: Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // 2. Content below the image
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small Logo
                    if (_competition!.logoUrl != null)
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: _competition!.logoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const LoadingSpinner(size: 16),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // Name and Sponsor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _competition!.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_competition!.sponsorName != null &&
                              _competition!.sponsorName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'By ${_competition!.sponsorName}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Contact Button (moved closer to content)
                if (_hasJoined && _currentUser?.id != _competition!.organizerId)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 12.0,
                        left: 52.0,
                      ), // Align with text
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                competitionId: _competition!.id,
                                participantId: _currentUser!.id,
                                participantName: _currentUser!.name,
                                amIOrganizer: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: AppColors.accentGreen,
                        ),
                        label: const Text(
                          'Contact Organizer',
                          style: TextStyle(color: AppColors.accentGreen),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentGreen,
                          side: const BorderSide(color: AppColors.accentGreen),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Competition Code (Visible to All)
                if (true)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentGreen),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentUser?.id == _competition!.organizerId
                              ? 'JOIN CODE'
                              : 'COMPETITION CODE',
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              _competition!.joinCode.isNotEmpty
                                  ? _competition!.joinCode
                                  : 'Generating...',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                if (_competition!.joinCode.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: _competition!.joinCode),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Code copied to clipboard!',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        if (_currentUser?.id != _competition!.organizerId)
                          const Text(
                            'Use this code as a template when creating a new competition',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            'Share this code with participants',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                // Description
                if (_competition!.description != null &&
                    _competition!.description!.isNotEmpty) ...[
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _competition!.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],

                // Stats
                _buildInfoCard(
                  'Participants',
                  '${_competition!.participantCount}',
                  Icons.people,
                ),
                const SizedBox(height: 12),

                // Points System
                _buildInfoCard(
                  'Points System',
                  'Winner: ${_competition!.rules['correctWinner']}pts • ${_competition!.sport == AppConstants.sportCricket ? 'Runs' : 'Score'}: ${_competition!.rules['correctScore']}pts',
                  Icons.stars,
                ),
                const SizedBox(height: 24),

                // Join Button
                if (!_hasJoined)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: !_isJoining ? _joinCompetition : null,
                      child: _isJoining
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: LoadingSpinner(
                                size: 20,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Text(
                              'Join Competition',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: AppColors.success),
                            SizedBox(width: 8),
                            Text(
                              'You have joined this competition',
                              style: TextStyle(color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                      if (_currentUser?.id != _competition!.organizerId) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              foregroundColor: AppColors.error,
                            ),
                            onPressed: _isLoading ? null : _leaveCompetition,
                            child: const Text('Leave Competition'),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
