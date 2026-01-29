import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import 'default_competition_background.dart';

class MiniCompetitionCard extends StatelessWidget {
  final CompetitionModel competition;
  final VoidCallback onTap;

  const MiniCompetitionCard({
    super.key,
    required this.competition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150, // Reduced width by 25% (200 -> 150)
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Section (Fixed Aspect Ratio for "Full View")
              AspectRatio(
                aspectRatio: 16 / 9, // Standard landscape photo ratio
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            competition.cardBackgroundImageUrl != null &&
                                competition.cardBackgroundImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: competition.cardBackgroundImageUrl!,
                                memCacheHeight: 400, // Optimize memory usage
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const DefaultCompetitionBackground(),
                              )
                            : const DefaultCompetitionBackground(),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Content Section (Bottom, Below Image)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.0,
                ),
                child: Row(
                  children: [
                    // Small Logo
                    Container(
                      width: 16, // Reduced logo (20 -> 16)
                      height: 16,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: competition.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: competition.logoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.emoji_events,
                                      color: Colors.white70,
                                      size: 12, // Reduced icon size
                                    ),
                              ),
                            )
                          : Image.asset(AppConstants.defaultCompetitionLogo),
                    ),
                    // Name and Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competition.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10, // Reduced font (11 -> 10)
                            ),
                          ),
                          const SizedBox(height: 1),
                          if (competition.sponsorName != null &&
                              competition.sponsorName!.isNotEmpty)
                            Text(
                              competition.sponsorName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 8, // Reduced font (9 -> 8)
                              ),
                            )
                          else
                            Text(
                              '${competition.participantCount} joined',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 8, // Reduced font (9 -> 8)
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
      ),
    );
  }
}
