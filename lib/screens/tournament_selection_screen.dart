import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/loading_spinner.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../services/firestore_service.dart';
import '../services/teams_data_service.dart';
import 'competition_detail_screen.dart';
import 'official_tournament_search_screen.dart';

import '../services/tournament_data_service.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class TournamentSelectionScreen extends StatefulWidget {
  final CompetitionModel competitionPrototype;

  const TournamentSelectionScreen({
    super.key,
    required this.competitionPrototype,
  });

  @override
  State<TournamentSelectionScreen> createState() =>
      _TournamentSelectionScreenState();
}

class _TournamentSelectionScreenState extends State<TournamentSelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  final List<Map<String, dynamic>> _tournaments = [
    {
      'id': 'pl',
      'name': 'Premier League',
      'country': 'England',
      'color': const Color(0xFF38003C), // PL Purple
      'gradient': [const Color(0xFF38003C), const Color(0xFF00FF85)],
      // Using a reliable generic PNG for now or official resource
      'trophyUrl': 'https://crests.football-data.org/PL.png',
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'laliga',
      'name': 'La Liga',
      'country': 'Spain',
      'color': const Color(0xFFEE2523),
      'gradient': [const Color(0xFFEE2523), const Color(0xFFF8B500)],
      'trophyUrl': 'https://crests.football-data.org/PD.png',
      'disabled': true,
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'bundesliga',
      'name': 'Bundesliga',
      'country': 'Germany',
      'color': const Color(0xFFD20515),
      'gradient': [const Color(0xFFD20515), const Color(0xFFFFFFFF)],
      'trophyUrl': 'https://crests.football-data.org/BL1.png',
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'seriea',
      'name': 'Serie A',
      'country': 'Italy',
      'color': const Color(0xFF008FD7),
      'gradient': [const Color(0xFF008FD7), const Color(0xFF021F48)],
      'trophyUrl': 'https://crests.football-data.org/SA.png',
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'ligue1',
      'name': 'Ligue 1',
      'country': 'France',
      'color': const Color(0xFFDAE025),
      'gradient': [const Color(0xFF091c3e), const Color(0xFFDAE025)],
      'trophyUrl': 'https://crests.football-data.org/FL1.png',
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'ucl',
      'name': 'Champions League',
      'country': 'Europe',
      'color': const Color(0xFF001C58),
      'gradient': [const Color(0xFF001C58), const Color(0xFF00A2E8)],
      'trophyUrl': 'https://crests.football-data.org/CL.png',
      'sport': AppConstants.sportFootball,
    },
    {
      'id': 'wc2026',
      'name': 'FIFA World Cup 2026',
      'country': 'International',
      'color': const Color(0xFF8A1538),
      'gradient': [const Color(0xFF8A1538), const Color(0xFFEE2523)],
      'trophyUrl':
          'https://freepngimg.com/thumb/fifa/11-2-fifa-world-cup-trophy-png-clipart.png',
      'sport': AppConstants.sportFootball,
    },
    // Cricket Tournaments
    {
      'id': 'ipl',
      'name': 'IPL',
      'country': 'India',
      'color': const Color(0xFF1B3E92),
      'gradient': [const Color(0xFF1B3E92), const Color(0xFFEE2523)],
      'trophyUrl': 'https://scores.iplt20.com/IPL/logos/IPL-Logo-2024.png',
      'sport': AppConstants.sportCricket,
    },
    {
      'id': 'asiacup',
      'name': 'Asia Cup',
      'country': 'Asia',
      'color': const Color(0xFF004B8D),
      'gradient': [const Color(0xFF004B8D), const Color(0xFFFDB913)],
      'trophyUrl':
          'https://upload.wikimedia.org/wikipedia/en/thumb/5/5e/Asia_Cup_official_logo.png/220px-Asia_Cup_official_logo.png', // Fallback icon will handle if broken
      'sport': AppConstants.sportCricket,
    },
    {
      'id': 'cwc',
      'name': 'Cricket World Cup',
      'country': 'International',
      'color': const Color(0xFF001C58),
      'gradient': [const Color(0xFF001C58), const Color(0xFFE91E63)],
      'trophyUrl':
          'https://upload.wikimedia.org/wikipedia/en/thumb/b/bf/2023_Cricket_World_Cup_logo.svg/200px-2023_Cricket_World_Cup_logo.svg.png',
      'sport': AppConstants.sportCricket,
    },
  ];

  List<Map<String, dynamic>> get _filteredTournaments => _tournaments
      .where((t) => t['sport'] == widget.competitionPrototype.sport)
      .toList();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectTournament(Map<String, dynamic> tournament) async {
    setState(() => _isLoading = true);

    try {
      debugPrint(
        'Selecting tournament: ${tournament['name']} (${tournament['id']})',
      );
      await _setupTournamentData(tournament['id']);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionDetailScreen(
            competitionId: widget.competitionPrototype.id,
          ),
        ),
        (route) => route.isFirst,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${tournament['name']} with official teams!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupTournamentData(String leagueId) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final competitionId = widget.competitionPrototype.id;

    // Update competition with selected League ID (Major Tournament)
    try {
      final updatedComp = widget.competitionPrototype.copyWith(
        leagueId: leagueId,
        format: leagueId == 'wc2026'
            ? AppConstants.formatGroupsKnockout
            : widget.competitionPrototype.format,
      );
      await firestore.updateCompetition(updatedComp);
    } catch (e) {
      debugPrint('Error updating competition leagueId: $e');
      // Proceed even if update fails (though it shouldn't)
    }

    List<Map<String, String>> teamsData;
    if (leagueId == 'wc2026') {
      teamsData = TeamsDataService.getNationalTeams();
      teamsData = teamsData.map((t) {
        return {
          'name': t['name']!,
          'code': t['code']!,
          'logo': TeamsDataService.getFlagUrl(t['flag']!),
        };
      }).toList();
    } else if (leagueId == 'ipl' || leagueId == 'asiacup') {
      teamsData = TeamsDataService.getCricketTeams(leagueId);
    } else if (leagueId == 'cwc') {
      teamsData = TeamsDataService.getNationalTeams();
      // Most major cricket teams are in the list.
    } else {
      teamsData = TeamsDataService.getClubTeams(leagueId);
    }

    if (teamsData.isEmpty) {
      throw Exception('No teams found for this league. Please select Custom.');
    }

    List<TeamModel> createdTeams = [];
    for (var t in teamsData) {
      if (t['name'] == null || t['code'] == null) continue;

      final team = TeamModel(
        id: const Uuid().v4(),
        name: t['name']!,
        shortName: t['code']!,
        logoUrl: t['logo'],
        competitionId: competitionId,
        createdAt: DateTime.now(),
      );
      await firestore.createTeam(team);
      createdTeams.add(team);
    }

    try {
      final matches = await TournamentDataService.getTournamentFixtures(
        competitionId,
        leagueId,
        createdTeams,
      );

      if (matches.isNotEmpty) {
        await firestore.createBatchMatches(matches);
      }

      // Initialize standings with 0 points for all teams
      await firestore.recalculateStandings(competitionId);
    } catch (e) {
      debugPrint('Error generating fixtures: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Select Tournament'),
      ),
      body: _isLoading
          ? Container(
              color: AppColors.backgroundDark,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingSpinner(size: 50),
                    SizedBox(height: 20),
                    Text(
                      'Setting up tournament...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                children: [
                  // Custom option removed per user request
                  const SizedBox(height: 16),
                  _buildAnimatedItem(0, _buildSearchDictionaryCard()),
                  const SizedBox(height: 24),
                  _buildAnimatedItem(
                    1,
                    const Text(
                      'Official Tournaments',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: _filteredTournaments.length,
                    itemBuilder: (context, index) {
                      final t = _filteredTournaments[index];
                      // Staggered animation index starts after the header items
                      return _buildAnimatedItem(
                        index + 2,
                        _buildTournamentCard(t),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Interval(
          (0.1 + index * 0.05).clamp(0.0, 1.0),
          1.0,
          curve: Curves.easeOut,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  (0.1 + index * 0.05).clamp(0.0, 1.0),
                  1.0,
                  curve: Curves.easeOutQuad,
                ),
              ),
            ),
        child: child,
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final List<Color> gradientColors =
        tournament['gradient'] ?? [Colors.grey, Colors.black];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTournament(tournament),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors
                    .map((c) => c.withValues(alpha: 0.8))
                    .toList(),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                if (tournament['trophyUrl'] != null)
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.15,
                      child: CachedNetworkImage(
                        imageUrl: tournament['trophyUrl'],
                        height: 140,
                        width: 140,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              tournament['country'] == 'International'
                                  ? '🌍'
                                  : tournament['country'] == 'Europe'
                                  ? '🇪🇺'
                                  : '',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          if (tournament['trophyUrl'] != null)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: tournament['trophyUrl'],
                                height: 32,
                                width: 32,
                                fit: BoxFit.contain,
                                errorWidget: (context, error, stackTrace) {
                                  debugPrint(
                                    'Error loading trophy for ${tournament['name']}: $error',
                                  );
                                  return const Icon(
                                    Icons.emoji_events,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          else if (tournament['disabled'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Soon',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Removed Spacer() as parent Column handles spaceBetween
                          Container(
                            constraints: const BoxConstraints(
                              maxWidth: 140,
                            ), // Prevent unbounded width for FittedBox
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                tournament['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tournament['country'],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDictionaryCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentGreen, Color(0xFF00C853)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withAlpha(76),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OfficialTournamentSearchScreen(
                  competitionPrototype: widget.competitionPrototype,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournament Dictionary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Search and import any official league',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
