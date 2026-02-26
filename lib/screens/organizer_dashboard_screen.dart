import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../services/firestore_service.dart';
import '../models/competition_model.dart';
import 'competition_create_screen.dart';
import 'competition_teams_screen.dart';
import 'recycle_bin_screen.dart';

import 'matches_list_screen.dart';
import 'leaderboard_screen.dart';
import 'competition_detail_screen.dart';

import 'organizer_chat_list_screen.dart';
import '../widgets/loading_spinner.dart';

class MyCompetitionsScreen extends StatefulWidget {
  final String organizerId;

  const MyCompetitionsScreen({super.key, required this.organizerId});

  @override
  State<MyCompetitionsScreen> createState() => _MyCompetitionsScreenState();
}

class _MyCompetitionsScreenState extends State<MyCompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<CompetitionModel>>? _joinedCompetitionsStream;
  Stream<List<CompetitionModel>>? _organizedCompetitionsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize streams only once, but in didChangeDependencies to ensure proper context
    if (_joinedCompetitionsStream == null ||
        _organizedCompetitionsStream == null) {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      _joinedCompetitionsStream = firestoreService.getJoinedCompetitions(
        widget.organizerId,
      );
      _organizedCompetitionsStream = firestoreService
          .getCompetitionsByOrganizer(widget.organizerId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('My Competitions'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGreen,
          labelColor: AppColors.accentGreen,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Participating'),
            Tab(text: 'Organizing'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_delete, color: AppColors.textSecondary),
            tooltip: 'Recycle Bin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RecycleBinScreen(organizerId: widget.organizerId),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Participating
          _buildParticipatingTab(firestoreService),

          // Tab 2: Organizing
          StreamBuilder<List<CompetitionModel>>(
            stream: _organizedCompetitionsStream,
            builder: (context, snapshot) {
              debugPrint(
                '🔄 Organizing Stream Update: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, dataLength=${snapshot.data?.length ?? 0}',
              );

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: LoadingSpinner(color: AppColors.accentGreen),
                );
              }

              final competitions = snapshot.data ?? [];
              debugPrint(
                '📋 Organizing Competitions: ${competitions.map((c) => c.name).join(", ")}',
              );

              if (competitions.isEmpty) {
                return _buildEmptyState(
                  Icons.emoji_events_outlined,
                  'No competitions created yet',
                  'Start organizing your own tournaments!',
                  iconWidget: ClipOval(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      height: 64,
                      width: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: competitions.length,
                itemBuilder: (context, index) {
                  final competition = competitions[index];
                  return _buildOrganizedCard(competition);
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildParticipatingTab(FirestoreService firestoreService) {
    return StreamBuilder<List<CompetitionModel>>(
      stream: _joinedCompetitionsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
            Icons.error_outline,
            'Something went wrong',
            'Try switching tabs or restarting the app.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingSpinner(color: AppColors.accentGreen),
          );
        }

        final competitions = snapshot.data ?? [];

        if (competitions.isEmpty) {
          return _buildEmptyState(
            Icons.search,
            'No joined competitions',
            'Join a competition using a code to see it here!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: competitions.length,
          itemBuilder: (context, index) {
            final competition = competitions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentGreen.withValues(alpha: 0.1),
                  child: ClipOval(
                    child:
                        (competition.logoUrl != null &&
                            competition.logoUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: competition.logoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Icon(
                              competition.sport == 'Football'
                                  ? Icons.sports_soccer
                                  : Icons.sports_cricket,
                              color: AppColors.accentGreen,
                              size: 20,
                            ),
                            placeholder: (context, url) => Icon(
                              competition.sport == 'Football'
                                  ? Icons.sports_soccer
                                  : Icons.sports_cricket,
                              color: AppColors.accentGreen.withValues(
                                alpha: 0.5,
                              ),
                              size: 20,
                            ),
                          )
                        : Icon(
                            competition.sport == 'Football'
                                ? Icons.sports_soccer
                                : Icons.sports_cricket,
                            color: AppColors.accentGreen,
                            size: 20,
                          ),
                  ),
                ),
                title: Text(competition.name),
                subtitle: Text(
                  '${competition.participantCount} participants${(competition.sponsorName != null && competition.sponsorName!.isNotEmpty) ? " • ${competition.sponsorName}" : ""}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompetitionDetailScreen(
                        competitionId: competition.id,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    IconData? icon,
    String title,
    String subtitle, {
    Widget? iconWidget,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconWidget != null)
            iconWidget
          else
            Icon(
              icon,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizedCard(CompetitionModel competition) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final hasBackground =
        competition.cardBackgroundImageUrl != null &&
        competition.cardBackgroundImageUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _showManagementOptions(context, competition, firestoreService),
        child: Stack(
          children: [
            if (hasBackground)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: competition.cardBackgroundImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      hasBackground
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.transparent,
                      hasBackground
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          competition.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (competition.sponsorName != null &&
                            competition.sponsorName!.isNotEmpty)
                          Text(
                            'By ${competition.sponsorName}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${competition.participantCount} participants',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: firestoreService.getOrganizerUnreadCount(
                      competition.id,
                    ),
                    builder: (context, snapshot) {
                      final unread = snapshot.data ?? 0;
                      if (unread == 0) {
                        return const Icon(
                          Icons.settings,
                          size: 20,
                          color: Colors.white70,
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
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
          ],
        ),
      ),
    );
  }

  void _showManagementOptions(
    BuildContext context,
    CompetitionModel competition,
    FirestoreService firestoreService,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.textPrimary),
            title: const Text(
              'Edit Details',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompetitionCreateScreen(
                    organizerId: widget.organizerId,
                    organizerName: competition.organizerName,
                    competition: competition,
                  ),
                ),
              );
            },
          ),
          if (!competition.isPublic) ...[
            ListTile(
              leading: const Icon(Icons.group, color: AppColors.textPrimary),
              title: const Text(
                'Manage Teams',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompetitionTeamsScreen(competition: competition),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_month,
                color: AppColors.textPrimary,
              ),
              title: const Text(
                'Manage Matches',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchesListScreen(competition: competition),
                  ),
                );
              },
            ),
          ],
          ListTile(
            leading: const Icon(
              Icons.format_list_numbered,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Standings',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaderboardScreen(competition: competition),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.mail_outline,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Messages',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OrganizerChatListScreen(competition: competition),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete, color: AppColors.error),
            title: const Text(
              'Delete Competition',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () => _handleDelete(context, competition, firestoreService),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _handleDelete(
    BuildContext context,
    CompetitionModel competition,
    FirestoreService firestoreService,
  ) async {
    Navigator.pop(context);
    final codeController = TextEditingController();
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Competition?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type "DELETE" to confirm. This will move "${competition.name}" to the Recycle Bin for 7 days.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (codeController.text == 'DELETE') Navigator.pop(ctx, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await firestoreService.softDeleteCompetition(competition.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moved to Recycle Bin'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    }
  }
}
