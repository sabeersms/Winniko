import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import 'loading_spinner.dart';
import 'share_competition_dialog.dart';
import 'default_competition_background.dart';

class CompetitionCard extends StatelessWidget {
  final CompetitionModel competition;
  final GeoPoint? userLocation;
  final VoidCallback onTap;

  const CompetitionCard({
    super.key,
    required this.competition,
    this.userLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior:
          Clip.antiAlias, // Ensure background image respects borderRadius
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child:
                  competition.cardBackgroundImageUrl != null &&
                      competition.cardBackgroundImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: competition.cardBackgroundImageUrl!,
                      memCacheHeight: 600, // Optimize memory usage
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const DefaultCompetitionBackground(),
                    )
                  : const DefaultCompetitionBackground(),
            ),

            // Gradient Overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Competition Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: competition.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: competition.logoUrl!,
                                  memCacheHeight: 200, // Optimize memory usage
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: LoadingSpinner(
                                      color: AppColors.accentGreen,
                                      size: 24,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      ClipOval(
                                        child: Image.asset(
                                          'assets/images/app_logo.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                ),
                              )
                            : ClipOval(
                                child: Image.asset(
                                  AppConstants.defaultCompetitionLogo,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Competition Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              competition.name,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white, // Ensure white text
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (competition.sponsorName != null &&
                                competition.sponsorName!.isNotEmpty)
                              Text(
                                'By ${competition.sponsorName}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ), // White secondary
                                    ),
                              ),
                          ],
                        ),
                      ),

                      // Paid Badge
                      if (competition.isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats Row
                  Row(
                    children: [
                      _buildStat(
                        Icons.people,
                        '${competition.displayParticipantCount} Participants',
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Points Info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars,
                          color: AppColors.accentGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Winner: ${competition.rules['correctWinner']}pts • Score: ${competition.rules['correctScore']}pts',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Join Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white70),
                          tooltip: 'Share',
                          onPressed: () => showShareCompetitionDialog(
                            context,
                            competition.name,
                            competition.joinCode,
                            competition.sponsorName,
                            competition.cardBackgroundImageUrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            competition.isFinished
                                ? 'FINISHED'
                                : 'View Details',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, [Color? color]) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color ?? AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
