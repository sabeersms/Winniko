import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../models/participant_model.dart';
import '../models/competition_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/loading_spinner.dart';
import '../utils/share_util.dart';
import 'user_profile_screen.dart';
import '../services/pdf_service.dart';
import '../services/ad_service.dart';
import '../models/match_model.dart';
import '../models/prediction_model.dart';

class ParticipantLeaderboardScreen extends StatefulWidget {
  final CompetitionModel competition;

  const ParticipantLeaderboardScreen({super.key, required this.competition});

  @override
  State<ParticipantLeaderboardScreen> createState() =>
      _ParticipantLeaderboardScreenState();
}

class _ParticipantLeaderboardScreenState
    extends State<ParticipantLeaderboardScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid;
    final isOrganizer =
        currentUserId != null &&
        currentUserId == widget.competition.organizerId;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: StreamBuilder<List<ParticipantModel>>(
        stream: firestore.getLeaderboard(widget.competition.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingSpinner(color: AppColors.accentGreen),
            );
          }

          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString();
            if (errorStr.contains('permission-denied')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Access Restricted',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This leaderboard is only visible to participants of this competition.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Please join the competition to see the full rankings and detailed stats.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Text(
                'Error: $errorStr',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            );
          }

          final participants = snapshot.data ?? [];

          if (participants.isEmpty) {
            return const Center(
              child: Text(
                'No participants yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Determine if we show podium:
          // 1. Need at least 3 participants.
          // 2. No tie for 1st place (i.e. rank of 2nd participant is NOT 1).
          final bool isTieForFirst =
              participants.length > 1 && participants[1].rank == 1;
          final bool showPodium = participants.length >= 3 && !isTieForFirst;

          // Find current user's participant model
          final myParticipant = participants
              .where((p) => p.userId == currentUserId)
              .firstOrNull;

          return RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: AppColors.backgroundDark,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(
                    participants.length,
                    isOrganizer,
                    participants,
                    showPodium,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8, top: 16),
                          child: Text(
                            'Rankings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Sticky "You" Row
                        if (myParticipant != null) ...[
                          _buildParticipantTile(
                            myParticipant,
                            myParticipant.rank - 1, // index is rank-1 roughly
                            true, // isMe is true
                            isOrganizer,
                            onDownload: () =>
                                _downloadUserReport(myParticipant),
                          ),
                          const SizedBox(height: 8),
                          Divider(color: Colors.white.withValues(alpha: 0.1)),
                          const SizedBox(height: 8),
                        ],
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // If we have podium, skip first 3 in the general list
                          final adjustedIndex = showPodium ? index + 3 : index;
                          if (adjustedIndex >= participants.length) return null;

                          final participant = participants[adjustedIndex];

                          return _buildParticipantTile(
                            participant,
                            adjustedIndex,
                            participant.userId == currentUserId,
                            isOrganizer,
                            onDownload: () => _downloadUserReport(participant),
                          );
                        },
                        childCount: showPodium
                            ? participants.length - 3
                            : participants.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateToProfile(ParticipantModel participant) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: LoadingSpinner(color: AppColors.accentGreen)),
    );

    try {
      final userModel = await authService.getUserProfile(participant.userId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (userModel != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              user: userModel,
              isCurrentUser: participant.userId == authService.currentUserId,
              isOrganizer:
                  authService.currentUserId != null &&
                  authService.currentUserId == widget.competition.organizerId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load user profile.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _downloadUserReport(ParticipantModel participant) async {
    // Show Ad before PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please watch this short ad to support Winniko!'),
        duration: Duration(seconds: 2),
      ),
    );

    AdService().showInterstitialAd(
      onAdDismissed: () async {
        if (!mounted) return;

        // Show Loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) =>
              const Center(child: LoadingSpinner(color: AppColors.accentGreen)),
        );

        try {
          final firestore = Provider.of<FirestoreService>(
            context,
            listen: false,
          );

          // 1. Get User Predictions
          final predictionsStream = firestore.getUserPredictions(
            participant.userId,
            widget.competition.id,
          );
          final predictions = await predictionsStream.first;

          if (predictions.isEmpty) {
            if (!mounted) return;
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No predictions found for this user.'),
              ),
            );
            return;
          }

          // 2. Get Matches (for details)
          final matchesStream = firestore.getMatches(widget.competition.id);
          final matches = await matchesStream.first;

          // Filter out orphaned predictions (matches that no longer exist)
          // This ensures points match the Leaderboard calculation
          final validPredictions = predictions
              .where((p) => matches.any((m) => m.id == p.matchId))
              .toList();

          // 3. Generate PDF
          await PdfService.generateUserReport(
            participant,
            validPredictions,
            widget.competition,
            matches,
          );

          if (!mounted) return;
          Navigator.pop(context); // Close loading
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating report: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  Widget _buildSliverAppBar(
    int count,
    bool isOrganizer,
    List<ParticipantModel> participants,
    bool showPodium,
  ) {
    final double expandedHeight = showPodium ? 260 : 200;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: showPodium
            ? null // Hide title when expanded if podium is there
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.competition.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$count Participants',
                    style: TextStyle(
                      color: AppColors.accentGreen.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image
            if (widget.competition.cardBackgroundImageUrl != null)
              CachedNetworkImage(
                imageUrl: widget.competition.cardBackgroundImageUrl!,
                fit: BoxFit.cover,
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),
                placeholder: (context, url) =>
                    Container(color: AppColors.backgroundDark),
                errorWidget: (context, url, error) =>
                    Container(color: AppColors.backgroundDark),
              )
            else
              Container(color: AppColors.backgroundDark),

            // 2. Gradient Overlay (Darker at bottom for podium visibility)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2), // Top
                    Colors.black.withValues(alpha: 0.1), // Middle
                    AppColors.backgroundDark, // Bottom merges with body
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),

            // 3. Podium (if applicable)
            if (showPodium)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title inside Podium area since we hid the AppBar title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          Text(
                            widget.competition.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$count Participants',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildPodium(participants.take(3).toList(), isOrganizer),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (isOrganizer)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recalculate Stats',
            onPressed: () => _recalculateStats(),
          ),
        if (isOrganizer)
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download Full Leaderboard',
            onPressed: () => _downloadFullLeaderboard(participants),
          ),
        // Task 17: Screenshot Share (Organizer Only)
        if (isOrganizer)
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => ShareUtil.shareWidgetAsImage(
              key: _boundaryKey,
              fileName: '${widget.competition.name}_leaderboard',
              text:
                  'Check out the leaderboard for ${widget.competition.name} on Winniko! ⚽🏆',
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _recalculateStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Recalculate Leaderboard?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will rebuild everyone\'s points from scratch based on their prediction history. Useful if data seems out of sync.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Recalculate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: LoadingSpinner(color: AppColors.accentGreen)),
      );

      try {
        await Provider.of<FirestoreService>(
          context,
          listen: false,
        ).recalculateParticipantStats(widget.competition.id);

        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recalculation complete!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadFullLeaderboard(
    List<ParticipantModel> participants,
  ) async {
    // Show Ad before PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please watch this short ad to support Winniko!'),
        duration: Duration(seconds: 2),
      ),
    );

    AdService().showInterstitialAd(
      onAdDismissed: () async {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) =>
              const Center(child: LoadingSpinner(color: AppColors.accentGreen)),
        );

        try {
          final firestore = Provider.of<FirestoreService>(
            context,
            listen: false,
          );

          // 1. Fetch Matches
          final matchesStream = firestore.getMatches(widget.competition.id);
          final matches = await matchesStream.first;

          // 2. Fetch All Predictions (using new helper)
          final allPredictions = await firestore.getCompetitionPredictions(
            widget.competition.id,
          );

          // Filter out orphaned predictions to match Leaderboard logic
          final validPredictions = allPredictions
              .where((p) => matches.any((m) => m.id == p.matchId))
              .toList();

          await PdfService.generateFullLeaderboard(
            widget.competition,
            participants,
            matches,
            validPredictions,
          );
          if (!mounted) return;
          Navigator.pop(context);
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating PDF: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  // Adjusted _buildPodium to be visual only (container adjustments handled in parent stack)
  Widget _buildPodium(List<ParticipantModel> winners, bool isOrganizer) {
    return SizedBox(
      height: 150, // Height for the podium part (Reduced from 180)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isOrganizer ? () => _navigateToProfile(winners[1]) : null,
              child: _buildPodiumSpot(
                winners[1],
                winners[1].rank,
                55, // Avatar Size (Reduced from 60)
                90, // Bar Height (Reduced from 110)
                isOrganizer,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isOrganizer ? () => _navigateToProfile(winners[0]) : null,
              child: _buildPodiumSpot(
                winners[0],
                winners[0].rank,
                65, // Avatar Size (Reduced from 70)
                120, // Bar Height (Reduced from 140)
                isOrganizer,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isOrganizer ? () => _navigateToProfile(winners[2]) : null,
              child: _buildPodiumSpot(
                winners[2],
                winners[2].rank,
                55, // Avatar Size
                70, // Bar Height (Reduced from 90)
                isOrganizer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(
    ParticipantModel user,
    int rank,
    double avatarSize,
    double height,
    bool isOrganizer,
  ) {
    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey[300]!;
        break;
      case 3:
        rankColor = Colors.brown[300]!;
        break;
      default:
        rankColor = Colors.white;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Crown for Rank 1
            if (rank == 1)
              const Positioned(
                top: -20,
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 28,
                ),
              ),

            // Avatar Container
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: rank == 1 ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _buildAvatar(user, avatarSize),
            ),

            // Rank Badge
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ),

            // PDF Option (Organizer Only)
            if (isOrganizer)
              Positioned(
                right: -8,
                top: 0,
                child: InkWell(
                  onTap: () => _downloadUserReport(user),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      size: 12, // Small icon
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: avatarSize + 20, // Constrain width relative to avatar
          child: Text(
            user.userName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '${user.totalPoints}',
          style: TextStyle(
            color: rankColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const Text(
          'POINTS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4), // Compacted
      ],
    );
  }

  Widget _buildAvatar(ParticipantModel user, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.cardBackground,
      child: ClipOval(
        child: user.photoUrl != null
            ? CachedNetworkImage(
                imageUrl: user.photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => const LoadingSpinner(
                  size: 20,
                  color: AppColors.accentGreen,
                ),
                errorWidget: (context, url, error) =>
                    _buildInitials(user, size),
              )
            : _buildInitials(user, size),
      ),
    );
  }

  Widget _buildInitials(ParticipantModel user, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.accentGreen.withValues(alpha: 0.1),
      child: Text(
        user.userName.isNotEmpty ? user.userName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size / 2.5,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParticipantTile(
    ParticipantModel participant,
    int index,
    bool isMe,
    bool isOrganizer, {
    VoidCallback? onDownload,
  }) {
    // Determine custom styling for Top 3
    Color? borderColor;
    Color? rankTextColor;
    if (participant.rank == 1) {
      borderColor = Colors.amber;
      rankTextColor = Colors.amber;
    } else if (participant.rank == 2) {
      borderColor = Colors.grey[300];
      rankTextColor = Colors.grey[300];
    } else if (participant.rank == 3) {
      borderColor = Colors.brown[300];
      rankTextColor = Colors.brown[300];
    }

    final effectiveBorderColor =
        borderColor ??
        (isMe
            ? AppColors.accentGreen.withValues(alpha: 0.5)
            : AppColors.dividerColor.withValues(alpha: 0.05));

    return GestureDetector(
      onTap: isOrganizer ? () => _navigateToProfile(participant) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.accentGreen.withValues(alpha: 0.15)
              : AppColors.cardBackground.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectiveBorderColor,
            width: borderColor != null ? 2 : 1, // Thicker for top ranks
          ),
          boxShadow: borderColor != null
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              // Rank
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  '${participant.rank}',
                  style: TextStyle(
                    color: isMe
                        ? AppColors.accentGreen
                        : (rankTextColor ?? AppColors.textSecondary),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Avatar
              _buildAvatar(participant, 36), // Compacted size
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            participant.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14, // Compacted font
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.star_rounded,
                          '${participant.perfectScores}',
                          Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.check_circle_outline_rounded,
                          '${participant.correctOutcomes}',
                          AppColors.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${participant.totalPredictions} Pred.',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${participant.totalPoints}',
                    style: const TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 18, // Compacted font
                    ),
                  ),
                  const Text(
                    'PTS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isOrganizer && onDownload != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onDownload,
                  tooltip: 'Download Report',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
