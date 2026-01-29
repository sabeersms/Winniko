import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/competition_model.dart';
import '../models/standing_model.dart';
import '../constants/app_constants.dart';

class StandingsPoster extends StatelessWidget {
  final CompetitionModel competition;
  final List<StandingModel> standings;
  final Map<String, List<StandingModel>> groupedData;

  const StandingsPoster({
    super.key,
    required this.competition,
    required this.standings,
    required this.groupedData,
  });

  @override
  Widget build(BuildContext context) {
    // Sort group names
    final sortedGroups = groupedData.keys.toList()..sort();

    return Container(
      width: 800, // Fixed width for consistent export resolution
      color: AppColors.backgroundDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: competition.cardBackgroundImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: competition.cardBackgroundImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/default_bg.jpg',
                        fit: BoxFit.cover,
                      ),
              ),
              // Gradient Overlay (Matches CompetitionCard)
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
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 48,
                  horizontal: 24,
                ),
                child: Row(
                  children: [
                    if (competition.logoUrl != null) ...[
                      CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          competition.logoUrl!,
                        ),
                        radius: 40,
                      ),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            competition.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'OFFICIAL STANDINGS • ${competition.format}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 18,
                              letterSpacing: 2,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
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
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: sortedGroups.map((groupName) {
                final groupStandings = groupedData[groupName]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Group Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            groupName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        // Table
                        competition.sport == AppConstants.sportCricket
                            ? _buildCricketTable(groupStandings)
                            : _buildDefaultTable(groupStandings),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: AppColors.accentGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Generated by Winniko',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTable(List<StandingModel> standings) {
    bool isFootball = competition.sport == AppConstants.sportFootball;

    final columns = [
      '#',
      'Team',
      'P',
      'W',
      'D',
      'L',
      if (isFootball) ...['GF', 'GA'],
      'GD',
      'Pts',
    ];

    final Map<int, TableColumnWidth> columnWidths = {
      0: const FixedColumnWidth(40),
      1: const FlexColumnWidth(4),
      2: const FlexColumnWidth(1),
      3: const FlexColumnWidth(1),
      4: const FlexColumnWidth(1),
      5: const FlexColumnWidth(1),
      if (isFootball) ...{
        6: const FlexColumnWidth(1), // GF
        7: const FlexColumnWidth(1), // GA
        8: const FlexColumnWidth(1.2), // GD
        9: const FlexColumnWidth(1.2), // Pts
      } else ...{
        6: const FlexColumnWidth(1.2), // GD
        7: const FlexColumnWidth(1.2), // Pts
      },
    };

    return _StyledTable(
      columns: columns,
      columnWidths: columnWidths,
      rows: standings.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        return TableRow(
          decoration: BoxDecoration(
            color: index.isEven
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.02),
          ),
          children: [
            _Cell('${index + 1}'),
            _TeamCell(team),
            _Cell('${team.played}'),
            _Cell('${team.won}'),
            _Cell('${team.drawn}'),
            _Cell('${team.lost}'),
            if (isFootball) ...[
              _Cell('${team.goalsFor}'),
              _Cell('${team.goalsAgainst}'),
            ],
            _Cell('${team.goalDifference}'),
            _Cell('${team.points}', isBold: true, color: Colors.white),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCricketTable(List<StandingModel> standings) {
    return _StyledTable(
      columns: const ['#', 'Team', 'Mat', 'W', 'L', 'T', 'NR', 'NRR', 'Pts'],
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1),
        6: FlexColumnWidth(1),
        7: FlexColumnWidth(1.5),
        8: FlexColumnWidth(1),
      },
      rows: standings.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        return TableRow(
          decoration: BoxDecoration(
            color: index.isEven
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.02),
          ),
          children: [
            _Cell('${index + 1}'),
            _TeamCell(team),
            _Cell('${team.played}'),
            _Cell('${team.won}'),
            _Cell('${team.lost}'),
            _Cell('${team.tied}'), // Added Tied
            _Cell('${team.noResult}'), // Added No Result
            _Cell(team.netRunRate.toStringAsFixed(3)),
            _Cell('${team.points}', isBold: true, color: Colors.white),
          ],
        );
      }).toList(),
    );
  }
}

class _StyledTable extends StatelessWidget {
  final List<String> columns;
  final Map<int, TableColumnWidth> columnWidths;
  final List<TableRow> rows;

  const _StyledTable({
    required this.columns,
    required this.columnWidths,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          children: columns.map((c) => _HeaderCell(c)).toList(),
        ),
        ...rows,
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: ['TEAM'].contains(text) ? TextAlign.left : TextAlign.center,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color? color;

  const _Cell(this.text, {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white.withValues(alpha: 0.9),
          fontSize: 16,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TeamCell extends StatelessWidget {
  final StandingModel team;

  const _TeamCell(this.team);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          if (team.teamLogoUrl != null)
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(team.teamLogoUrl!),
              radius: 12,
              backgroundColor: Colors.transparent,
            )
          else
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 12,
              child: Icon(Icons.shield, size: 14, color: Colors.white),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              team.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
