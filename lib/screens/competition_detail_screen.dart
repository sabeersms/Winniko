import 'dart:async';
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

import 'leaderboard_screen.dart';
import 'participant_leaderboard_screen.dart';
import 'matches_list_screen.dart';
import 'competition_chat_screen.dart';
import 'organizer_chat_list_screen.dart';

import '../widgets/loading_spinner.dart';

import 'terms_and_conditions_screen.dart';
import '../widgets/share_competition_dialog.dart';

import '../services/ad_service.dart';
import '../services/pdf_service.dart';
import 'package:flutter/foundation.dart';

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
    with TickerProviderStateMixin {
  CompetitionModel? _competition;
  UserModel? _currentUser;
  ParticipantModel? _participant;
  bool _isLoading = true;
  bool _hasJoined = false;
  bool _isJoining = false;
  late TabController _tabController;
  StreamSubscription? _syncSubscription;

  bool get _isOfficial => _competition?.leagueId?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    // Initialize with default length, will be updated in _loadData if necessary
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_handleTabSelection);
    _loadData();
  }

  void _handleTabSelection() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      debugPrint('🔍 Loading competition data for ID: ${widget.competitionId}');

      // 1. Try fetching by ID (Standard)
      CompetitionModel? competition = await firestoreService.getCompetition(
        widget.competitionId,
      );

      // 2. Fallback: Try by Join Code if not found by ID
      if (competition == null) {
        debugPrint(
          '🔍 Not found by ID, trying as Join Code: ${widget.competitionId}',
        );
        competition = await firestoreService.getCompetitionByJoinCode(
          widget.competitionId.toUpperCase(),
        );
      }

      if (competition == null) {
        debugPrint(
          '❌ CompetitionDetails: Competition not found (${widget.competitionId})',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final userId = authService.currentUserId;
      UserModel? user;
      bool hasJoined = false;
      ParticipantModel? participant;

      if (userId != null) {
        user = await authService.getUserProfile(userId);
        hasJoined = await firestoreService.hasJoinedCompetition(
          userId,
          competition.id, // Use actual competition ID
        );
        if (hasJoined) {
          participant = await firestoreService.getParticipant(
            competition.id,
            userId,
          );
        }

        // Self-healing for missing Join Code
        if (user != null &&
            competition.joinCode.isEmpty &&
            user.id == competition.organizerId) {
          debugPrint('🛠️ Self-healing: Generating missing join code...');
          await firestoreService.ensureJoinCode(competition.id);
          // Reload competition
          final updated = await firestoreService.getCompetition(competition.id);
          if (updated != null) {
            _loadData(); // Re-run with new data
            return;
          }
        }
      }

      if (!mounted) return;

      // 3. Update TabController length if necessary
      // We now show 4 tabs for official leagues too (to show the Table/Standings)
      // unless it's a format that specifically doesn't use a table.
      bool showTable = true;
      if (competition.format == AppConstants.formatKnockout ||
          competition.format == AppConstants.formatSingleMatch) {
        showTable = false;
      }

      // Hide table for official cricket tournaments as requested
      if (competition.sport == AppConstants.sportCricket &&
          competition.leagueId != null &&
          competition.leagueId!.isNotEmpty) {
        showTable = false;
      }

      final desiredTabCount = showTable ? 4 : 3;
      if (_tabController.length != desiredTabCount) {
        debugPrint(
          '🔄 Reconfiguring TabController: ${_tabController.length} -> $desiredTabCount',
        );
        final oldIndex = _tabController.index;

        _tabController.removeListener(_handleTabSelection);
        _tabController.dispose();

        _tabController = TabController(
          length: desiredTabCount,
          vsync: this,
          initialIndex: oldIndex < desiredTabCount ? oldIndex : 0,
        );
        _tabController.addListener(_handleTabSelection);
      }

      setState(() {
        _competition = competition;
        _currentUser = user;
        _hasJoined = hasJoined;
        _participant = participant;
        _isLoading = false;
      });

      // Start Auto Sync for Verification (Master Workflow)
      if (competition.leagueId?.isNotEmpty == true) {
        _syncSubscription?.cancel();
        _syncSubscription = firestoreService.startAutoSync(
          competition.id,
          competition.leagueId!,
        );
      }

      // Self-healing: Update participant count if it's negative or out of sync
      if (competition.participantCount < 0) {
        debugPrint(
          '🛠️ Auto-fixing negative participant count for ${competition.id}',
        );
        firestoreService.recountParticipants(competition.id).then((newCount) {
          if (mounted && newCount >= 0) {
            setState(() {
              _competition = _competition?.copyWith(participantCount: newCount);
            });
          }
        });
      }

      // Self-healing: Update participant photo
      if (participant != null &&
          user?.photoUrl != null &&
          participant.photoUrl != user!.photoUrl) {
        final currentPhotoUrl = user.photoUrl!;
        firestoreService
            .updateParticipantPhoto(competition.id, userId!, currentPhotoUrl)
            .then((_) {
              if (mounted) {
                setState(() {
                  _participant = _participant?.copyWith(
                    photoUrl: currentPhotoUrl,
                  );
                });
              }
            });
      }

      if (hasJoined) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // If viewing overview and joined, move to matches tab
          if (mounted && _tabController.index == 0) {
            _tabController.animateTo(1);
          }
        });
      }
    } catch (e) {
      debugPrint('💥 Error loading competition data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading competition: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _joinCompetition() async {
    if (_currentUser == null || _competition == null) return;

    void proceedToJoin() async {
      if (!mounted) return;

      // Check for Terms and Conditions
      if (_competition!.termsAndConditions != null &&
          _competition!.termsAndConditions!.isNotEmpty) {
        final participantPrototype = ParticipantModel(
          userId: _currentUser!.id,
          userName: _currentUser!.name,
          photoUrl: _currentUser!.photoUrl,
          phoneNumber: _currentUser!.phone,
          competitionId: _competition!.id,
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
          competitionId: _competition!.id, // Use actual ID
          joinedAt: DateTime.now(),
        );

        await firestoreService.joinCompetition(
          _competition!.id, // Use actual ID
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
          await firestoreService.sendMessage(_competition!.id, sysMsg);
        } catch (_) {}

        setState(() {
          _hasJoined = true;
          _isJoining = false;
        });

        // 🔄 Refresh data to show updated participant count
        _loadData();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined competition!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Auto Navigate to Matches
        _tabController.animateTo(1);
      } catch (e) {
        if (mounted) {
          setState(() => _isJoining = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error joining: $e')));
        }
      }
    }

    if (kIsWeb) {
      proceedToJoin();
    } else {
      // Show Ad before Joining
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please watch this short ad to join the competition!'),
          duration: Duration(seconds: 2),
        ),
      );

      AdService().showInterstitialAd(onAdDismissed: proceedToJoin);
    }
  }

  Future<void> _leaveCompetition() async {
    if (_participant == null || _currentUser == null || _competition == null) {
      return;
    }

    // Check restriction: Cannot leave if made predictions
    // Only check if participant exists
    if (_participant != null && _participant!.totalPredictions > 0) {
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

      // 🔄 Refresh data to show updated participant count
      _loadData();

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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.textSecondary,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Competition not found',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'We couldn\'t find a competition with ID:\n${widget.competitionId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Go Back',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
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

          // Manual Standings Refresh (Table Tab Only (Index 3) - Organizer Only)
          if (!_isOfficial &&
              _tabController.index == 3 &&
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

          // Task 17: PDF Action
          if (_currentUser?.id == _competition!.organizerId &&
              _tabController.index == 1) // Matches tab
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Download Match List',
              onPressed: () async {
                // Call PDF Service
                final matches = await Provider.of<FirestoreService>(
                  context,
                  listen: false,
                ).getMatches(_competition!.id).first;
                if (context.mounted) {
                  PdfService.generateMatchListSchedule(_competition!, matches);
                }
              },
            ),

          // Task 18: PDF Action (Table/Standings)
          if (!_isOfficial &&
              _tabController.index == 3 &&
              _currentUser?.id == _competition!.organizerId &&
              !(_competition!.format == AppConstants.formatKnockout ||
                  _competition!.format == AppConstants.formatSingleMatch))
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Download Standings',
              onPressed: () async {
                // Call PDF Service
                final standings = await Provider.of<FirestoreService>(
                  context,
                  listen: false,
                ).getStandings(_competition!.id).first;
                if (context.mounted) {
                  PdfService.generateLeaderboardPdf(_competition!, standings);
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
            const Tab(text: 'Overview'),
            const Tab(text: 'Matches'),
            const Tab(text: 'Leaderboard'),
            if (_tabController.length > 3)
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
          if (_tabController.length > 3)
            (_competition!.format == AppConstants.formatKnockout ||
                    _competition!.format == AppConstants.formatSingleMatch)
                ? MatchesListScreen(
                    competition: _competition!,
                    embed: true,
                    isParticipant: _hasJoined,
                    initialFilter: 'Completed',
                  )
                : LeaderboardScreen(
                    competition: _competition!,
                    embed: true,
                    isParticipant: _hasJoined,
                  ),
        ],
      ),
      floatingActionButton: null,
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
                // 3. Join Button (Moved to top)
                if (!_hasJoined)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: (_competition?.isFinished ?? false)
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              child: const Text(
                                'FINISHED',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ElevatedButton(
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
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
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
                              Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                              ),
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
                  ),

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
                            'Share this code to join others', // Updated Text
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

                // Stats & Chat
                _buildInfoCard(
                  'Participants',
                  '${_competition!.participantCount}',
                  Icons.people,
                  trailing: SizedBox(
                    width: 130, // Fixed width for prominence
                    child: Builder(
                      builder: (context) {
                        int unread = 0;
                        if (_participant != null) {
                          final total = _competition!.messageCount;
                          final read = _participant!.lastReadMessageCount;
                          unread = total - read;
                        }

                        // Sanity check
                        if (unread < 0) unread = 0;

                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('Group Chat'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Group Chat'),
                                    ),
                                    body: CompetitionChatScreen(
                                      competition: _competition!,
                                      isParticipant: _hasJoined,
                                    ),
                                  ),
                                ),
                              ).then((_) {
                                // Refresh data when returning to update badge
                                _loadData();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Removed Points System
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
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
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
