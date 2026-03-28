import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/loading_spinner.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../services/firestore_service.dart';
import '../services/teams_data_service.dart';
import 'competition_detail_screen.dart';

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

  Set<String> _blacklist = {};

  bool _isBlacklisted(String id) {
    if (_blacklist.contains(id)) return true;
    return false;
  }

  bool _isLoadingData = true;
  List<Map<String, dynamic>> _dynamicTournaments = [];

  List<Map<String, dynamic>> get _allTournaments => _dynamicTournaments;

  List<Map<String, dynamic>> get _filteredTournaments {
    debugPrint(
      '--- Filtering for competition sport: "${widget.competitionPrototype.sport}" ---',
    );
    final results = _allTournaments.where((t) {
      final String tSport = (t['sport'] ?? '').toString().toLowerCase();
      final String compSport = (widget.competitionPrototype.sport)
          .toString()
          .toLowerCase();

      bool sportMatches = tSport == compSport;

      // 🔍 Better detection: If saved sport doesn't match, try guessing from ID and Name
      if (!sportMatches) {
        final String guessedSport = _guessSport(
          t['id'] ?? '',
          t['name'] ?? '',
        ).toLowerCase();
        if (guessedSport == compSport) {
          sportMatches = true;
          debugPrint(
            '🔍 Note: Showing "${t['name']}" because Name/ID matches "$compSport" even though saved sport is "$tSport"',
          );
        }
      }

      // Final fallback: If name contains the sport name exactly
      if (!sportMatches && t['name'].toString().toLowerCase().contains(compSport)) {
        sportMatches = true;
        debugPrint('🔍 Final Fallback: Matched "${t['name']}" because it contains "$compSport"');
      }

      final bool notBlacklisted = !_isBlacklisted(t['id']?.toString() ?? '');

      if (!sportMatches) {
        debugPrint(
          '🔍 Filter: Skipping "${t['name']}" (ID: ${t['id']}) because its sport is "$tSport", but we need "$compSport"',
        );
      }
      if (!notBlacklisted) {
        debugPrint(
          '🔍 Filter: Skipping "${t['name']}" (ID: ${t['id']}) because it is BLACKLISTED.',
        );
      }

      return sportMatches && notBlacklisted;
    }).toList();

    debugPrint(
      'Filtering for ${widget.competitionPrototype.sport}: Found ${results.length} out of ${_allTournaments.length}',
    );
    return results;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
    _refreshData();
  }

  Future<void> _refreshData() async {
    // Sequentially load to avoid race conditions in SnackBar calculation vs UI filter
    await _loadBlacklist();
    await _loadGlobalTournaments();
  }

  Future<void> _loadBlacklist() async {
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final blacklist = await firestore.getBlacklistedTournamentIds();
      if (mounted) {
        setState(() {
          _blacklist = blacklist;
        });
      }
    } catch (e) {
      debugPrint('Error loading blacklist: $e');
    }
  }

  String _guessSport(String id, [String? name]) {
    final lowerId = id.toLowerCase();
    final lowerName = (name ?? '').toLowerCase();
    final combined = '$lowerId $lowerName';

    // ✅ Specific short IDs
    if (lowerId == 'mc') return AppConstants.sportCricket;
    if (lowerId == 'mf') return AppConstants.sportFootball;

    // 🏆 Tier 1: Absolute Cricket Keywords (Always Cricket)
    if (combined.contains('cricket') ||
        combined.contains('cric') ||
        combined.contains('crik') ||
        combined.contains('ipl') ||
        combined.contains('indian premier league') ||
        combined.contains('indian-premier-league') ||
        combined.contains('t20') ||
        combined.contains('t10') ||
        combined.contains('bbl') ||
        combined.contains('psl') ||
        combined.contains('cpl') ||
        combined.contains('bpl') ||
        combined.contains('icc') ||
        combined.contains('bcci') ||
        combined.contains('blast') || // e.g. T20 Blast
        combined.contains('smash') || // e.g. Super Smash
        combined.contains('hundred') || // e.g. The Hundred
        combined.contains('ranji') ||
        combined.contains('duleep') ||
        combined.contains('sheffield') ||
        combined.contains('county') ||
        combined.contains('asiacup') ||
        combined.contains('asia-cup') ||
        combined.contains('cwc') ||
        combined.contains('odi') ||
        combined.contains('ashes') ||
        combined.contains('test-match') ||
        combined.contains('test match') ||
        combined.contains('test-series') ||
        combined.contains('world-cup') ||
        combined.contains('world cup') ||
        combined.contains('worldcup')) {
      // Exclusion: Only switch to Football if it has a strong Football keyword AND doesn't have Tier 1 Cricket terms
      if ((combined.contains('fifa') ||
              combined.contains('uefa') ||
              combined.contains('laliga') ||
              combined.contains('premier-league')) &&
          !combined.contains('cricket')) {
        return AppConstants.sportFootball;
      }

      return AppConstants.sportCricket;
    }

    // 🏏 Tier 2: General Sports Terms
    if (combined.contains('series') ||
        combined.contains('tour') ||
        combined.contains('trophy') ||
        combined.contains('cup') ||
        combined.contains('league') ||
        combined.contains('match') ||
        combined.contains('vs') ||
        combined.contains('wc')) {
      if (combined.contains('football') ||
          combined.contains('soccer') ||
          combined.contains('champions-league')) {
        return AppConstants.sportFootball;
      }
      return AppConstants.sportCricket;
    }

    // ⚽ Tier 3: General Football Terms
    if (combined.contains('soccer') ||
        combined.contains('football') ||
        combined.contains('laliga') ||
        combined.contains('premier-league') ||
        combined.contains('champions-league') ||
        combined.contains('uefa') ||
        combined.contains('fifa') ||
        combined.contains('bundesliga')) {
      return AppConstants.sportFootball;
    }

    return '';
  }

  Future<void> _loadGlobalTournaments() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final majorTournaments = await firestore.getMajorTournaments();

      debugPrint(
        'Fetched ${majorTournaments.length} verified tournaments from Firestore',
      );
      for (var t in majorTournaments) {
        debugPrint(
          'Tournament: ${t.name} (ID: ${t.id}), Sport: "${t.sport}", isMajor: ${t.isMajor}',
        );
      }

      final List<Map<String, dynamic>> fetched = [];
      for (var t in majorTournaments) {
        // Try to find hardcoded visual metadata if any
        final localData = _tournaments.firstWhere(
          (l) => l['id'] == t.id,
          orElse: () => {},
        );

        String sport = t.sport;
        if (sport.isEmpty) {
          sport = localData['sport'] ?? _guessSport(t.id, t.name);
        }

        fetched.add({
          'id': t.id,
          'name': t.name.isNotEmpty
              ? t.name
              : (localData['name'] ?? t.id.replaceAll('-', ' ').toUpperCase()),
          'country': t.country.isNotEmpty
              ? t.country
              : (localData['country'] ?? 'International'),
          'sport': sport,
          'trophyUrl': t.logoUrl ?? localData['trophyUrl'],
          'color': localData['color'] ?? const Color(0xFF1B5E20),
          'gradient':
              localData['gradient'] ??
              [const Color(0xFF1B5E20), const Color(0xFF4CAF50)],
          'isGlobal': true,
        });
      }

      if (mounted) {
        setState(() {
          _dynamicTournaments = fetched;
          _isLoadingData = false;
        });

        // Diagnostic SnackBar
        final filteredOut = fetched
            .where(
              (t) => !_filteredTournaments.any((ft) => ft['id'] == t['id']),
            )
            .toList();
        final filteredCount = _filteredTournaments.length;
        String message =
            'Loaded ${fetched.length} verified. Filtered to $filteredCount for "${widget.competitionPrototype.sport}".';
        if (filteredOut.isNotEmpty) {
          final skippedInfo = filteredOut
              .take(5)
              .map((e) => '"${e['name']}" (${e['id']})')
              .join(', ');
          message += ' Skipped: $skippedInfo';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading global tournaments: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tournaments: $e')),
        );
      }
    }
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
      final selectedTournament = _allTournaments.firstWhere(
        (t) => t['id'] == leagueId,
        orElse: () => {},
      );
      final String tournamentSport =
          selectedTournament['sport'] ?? widget.competitionPrototype.sport;

      final updatedComp = widget.competitionPrototype.copyWith(
        leagueId: leagueId,
        sport: tournamentSport,
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
      // 🕵️ Discovery: Try to find teams from verified official matches
      teamsData = await TournamentDataService.discoverTeamsFromOfficialLeagues(
        leagueId,
      );
    }

    if (teamsData.isEmpty) {
      throw Exception('No teams found for this league. Please select Custom.');
    }

    List<TeamModel> createdTeams = [];
    for (var t in teamsData) {
      if (t['name'] == null || t['code'] == null) continue;

      String? resolvedLogo = t['logo'];
      if ((resolvedLogo == null || resolvedLogo.isEmpty) && t['flag'] != null) {
        resolvedLogo = 'https://flagcdn.com/w320/${t['flag']}.png';
      }
      
      // Still empty? Fallback to null to use default logo correctly.
      if (resolvedLogo != null && resolvedLogo.isEmpty) {
        resolvedLogo = null;
      }

      final team = TeamModel(
        id: const Uuid().v4(),
        name: t['name']!,
        shortName: t['code']!,
        logoUrl: resolvedLogo,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: LoadingSpinner(size: 40, color: AppColors.accentGreen),
            )
          : _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoadingSpinner(size: 40, color: AppColors.accentGreen),
                  SizedBox(height: 16),
                  Text(
                    'Setting up tournament...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Fancy Background
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0A1F0F), Colors.black],
                      ),
                    ),
                  ),
                ),
                CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    if (_filteredTournaments.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final t = _filteredTournaments[index];
                            return _buildAnimatedItem(
                              index,
                              _buildTournamentCard(t),
                            );
                          }, childCount: _filteredTournaments.length),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Verified Tournaments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only tournaments pinned (Star icon) or verified matches by the Master Admin will appear here. Also check if the tournament sport matches "${widget.competitionPrototype.sport}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Try Refresh'),
          ),
        ],
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
                          if (tournament['isGlobal'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.accentGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: AppColors.accentGreen,
                                    size: 10,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'OFFICIAL',
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
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
}
