import 'package:flutter/material.dart';
import '../widgets/loading_spinner.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/standing_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../services/ad_service.dart';
import '../utils/share_util.dart';

class LeaderboardScreen extends StatefulWidget {
  final CompetitionModel competition;
  final bool embed;

  const LeaderboardScreen({
    super.key,
    required this.competition,
    this.embed = false,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      floatingActionButton: widget.embed
          ? FloatingActionButton.small(
              onPressed: () => ShareUtil.shareWidgetAsImage(
                key: _boundaryKey,
                fileName: '${widget.competition.name}_standing',
                text:
                    'Check out the latest standings for ${widget.competition.name} on Winniko!',
              ),
              backgroundColor: AppColors.accentGreen,
              child: const Icon(Icons.share, color: Colors.white, size: 20),
            )
          : null,
      appBar: widget.embed
          ? null
          : AppBar(
              title: Text('${widget.competition.name} Standings'),
              actions: [
                Builder(
                  builder: (context) {
                    final currentUserId = Provider.of<AuthService>(
                      context,
                      listen: false,
                    ).currentUserId;
                    debugPrint(
                      'Leaderboard Debug: Organizer=${widget.competition.organizerId}, CurrentUser=$currentUserId',
                    );
                    if (widget.competition.organizerId == currentUserId) {
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Recalculate Standings',
                            onPressed: () async {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recalculating standings...'),
                                  ),
                                );
                                await Provider.of<FirestoreService>(
                                  context,
                                  listen: false,
                                ).recalculateStandings(widget.competition.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Standings updated!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error updating: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            tooltip: 'Download Table PDF',
                            onPressed: () async {
                              // Show Ad before PDF generation
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please watch this short ad to support Winniko!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              AdService().showInterstitialAd(
                                onAdDismissed: () async {
                                  if (!context.mounted) return;
                                  try {
                                    final firestore =
                                        Provider.of<FirestoreService>(
                                          context,
                                          listen: false,
                                        );
                                    final standings = await firestore
                                        .getStandings(widget.competition.id)
                                        .first;

                                    standings.sort((a, b) {
                                      int cmp = b.points.compareTo(a.points);
                                      if (cmp != 0) return cmp;
                                      if (widget.competition.sport ==
                                          AppConstants.sportCricket) {
                                        return b.netRunRate.compareTo(
                                          a.netRunRate,
                                        );
                                      }
                                      cmp = b.goalDifference.compareTo(
                                        a.goalDifference,
                                      );
                                      if (cmp != 0) return cmp;
                                      return b.goalsFor.compareTo(a.goalsFor);
                                    });

                                    await PdfService.generateLeaderboardPdf(
                                      widget.competition,
                                      standings,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error generating PDF: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => ShareUtil.shareWidgetAsImage(
                    key: _boundaryKey,
                    fileName: '${widget.competition.name}_standing',
                    text:
                        'Check out the latest standings for ${widget.competition.name} on Winniko!',
                  ),
                ),
              ],
            ),
      body: StreamBuilder<List<StandingModel>>(
        stream: firestore.getStandings(widget.competition.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingSpinner());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading standings:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final standings = snapshot.data ?? [];

          // Client-side sorting based on competition rules
          // Client-side sorting based on competition rules
          standings.sort((a, b) {
            // 1. Points (Always first)
            int cmp = b.points.compareTo(a.points);
            if (cmp != 0) return cmp;

            // 2. Dynamic Tie Breakers (Respecting order defined by user)
            for (final rule in widget.competition.tieBreakerRules) {
              if (rule == AppConstants.tieBreakerGoalDiff) {
                cmp = b.goalDifference.compareTo(a.goalDifference);
              } else if (rule == AppConstants.tieBreakerGoalsScored) {
                cmp = b.goalsFor.compareTo(a.goalsFor);
              } else if (rule == AppConstants.tieBreakerWins) {
                cmp = b.won.compareTo(a.won);
              } else if (rule == AppConstants.tieBreakerNrr) {
                cmp = b.netRunRate.compareTo(a.netRunRate);
              }
              // Head-to-head not fully implemented on client-side yet
              if (cmp != 0) return cmp;
            }

            // 3. Sport-specific Fallbacks (If rules are not explicitly defined or points/rules are equal)
            if (widget.competition.sport == AppConstants.sportCricket) {
              // IPL Standard Fallback: Wins then NRR
              if (!widget.competition.tieBreakerRules.contains(
                AppConstants.tieBreakerWins,
              )) {
                cmp = b.won.compareTo(a.won);
                if (cmp != 0) return cmp;
              }
              if (!widget.competition.tieBreakerRules.contains(
                AppConstants.tieBreakerNrr,
              )) {
                cmp = b.netRunRate.compareTo(a.netRunRate);
                if (cmp != 0) return cmp;
              }
            } else {
              // Football/General Fallback: GD then Goals For
              if (!widget.competition.tieBreakerRules.contains(
                AppConstants.tieBreakerGoalDiff,
              )) {
                cmp = b.goalDifference.compareTo(a.goalDifference);
                if (cmp != 0) return cmp;
              }
              if (!widget.competition.tieBreakerRules.contains(
                AppConstants.tieBreakerGoalsScored,
              )) {
                cmp = b.goalsFor.compareTo(a.goalsFor);
                if (cmp != 0) return cmp;
              }
            }

            // 4. Final Fallback: Name
            return a.teamName.compareTo(b.teamName);
          });

          if (standings.isEmpty) {
            return const Center(
              child: Text(
                'No standings available yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Group standings if format is Groups + Knockout or group field is present
          final Map<String, List<StandingModel>> groupedData = {};
          for (var s in standings) {
            final g = s.group ?? 'Other';
            groupedData.putIfAbsent(g, () => []).add(s);
          }

          // Sort group names
          final sortedGroups = groupedData.keys.toList()..sort();

          return SingleChildScrollView(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: AppColors.backgroundDark,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: sortedGroups.map((groupName) {
                    final groupStandings = groupedData[groupName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            groupName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child:
                              widget.competition.sport ==
                                  AppConstants.sportCricket
                              ? _buildCricketTable(groupStandings)
                              : _buildDefaultTable(groupStandings),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultTable(List<StandingModel> standings) {
    bool isFootball = widget.competition.sport == AppConstants.sportFootball;

    return DataTable(
      headingRowHeight: 40,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      headingRowColor: WidgetStateProperty.all(AppColors.cardBackground),
      columnSpacing: isFootball ? 15 : 20, // Adjust spacing for more columns
      columns: [
        const DataColumn(
          label: Text(
            '#',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'Team',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'P',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'W',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'D',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'L',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        if (isFootball) ...[
          const DataColumn(
            label: Text(
              'GF',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const DataColumn(
            label: Text(
              'GA',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
        const DataColumn(
          label: Text(
            'GD',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const DataColumn(
          label: Text(
            'Pts',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
      rows: List.generate(standings.length, (idx) {
        final team = standings[idx];
        return DataRow(
          cells: [
            DataCell(
              Text(
                '${idx + 1}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            DataCell(_buildTeamCell(team)),
            DataCell(
              Text(
                '${team.played}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            DataCell(
              Text(
                '${team.won}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            DataCell(
              Text(
                '${team.drawn}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            DataCell(
              Text(
                '${team.lost}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            if (isFootball) ...[
              DataCell(
                Text(
                  '${team.goalsFor}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              DataCell(
                Text(
                  '${team.goalsAgainst}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
            DataCell(
              Text(
                '${team.goalDifference}',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            DataCell(
              Text(
                '${team.points}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGreen,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCricketTable(List<StandingModel> standings) {
    return DataTable(
      headingRowHeight: 40,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      headingRowColor: WidgetStateProperty.all(AppColors.cardBackground),
      columnSpacing: 10,
      columns: const [
        DataColumn(
          label: Text(
            '#',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'Team',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'Mat',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'W',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'L',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'T',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'NR',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'NRR',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        DataColumn(
          label: Text(
            'Pts',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
      rows: List.generate(standings.length, (idx) {
        final team = standings[idx];
        return DataRow(
          cells: [
            DataCell(
              Text(
                '${idx + 1}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(_buildTeamCell(team)),
            DataCell(
              Text(
                '${team.played}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                '${team.won}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                '${team.lost}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                '${team.tied}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                '${team.noResult}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                team.netRunRate.toStringAsFixed(3),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Text(
                '${team.points}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGreen,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTeamCell(StandingModel team) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (team.teamLogoUrl != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 10,
              backgroundImage: NetworkImage(team.teamLogoUrl!),
              backgroundColor: Colors.transparent,
            ),
          ),
        Text(
          team.teamName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
