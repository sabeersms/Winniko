import 'package:flutter/material.dart';
import '../widgets/loading_spinner.dart';
import '../constants/app_constants.dart';
import '../services/sports_api_service.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../models/official_tournament_model.dart';
import '../services/firestore_service.dart';
import '../services/tournament_data_service.dart';
import 'competition_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class OfficialTournamentSearchScreen extends StatefulWidget {
  final CompetitionModel competitionPrototype;

  const OfficialTournamentSearchScreen({
    super.key,
    required this.competitionPrototype,
  });

  @override
  State<OfficialTournamentSearchScreen> createState() =>
      _OfficialTournamentSearchScreenState();
}

class _OfficialTournamentSearchScreenState
    extends State<OfficialTournamentSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<OfficialTournamentModel> _results = [];
  bool _isLoading = false;
  bool _isImporting = false;
  String? _statusText;
  List<Map<String, dynamic>> _upcomingMatches = [];
  String _selectedSport = 'All'; // 'All', 'Football', 'Cricket'

  @override
  void initState() {
    super.initState();
    // Pre-filter based on the sport selected during competition creation
    if (widget.competitionPrototype.sport == AppConstants.sportFootball) {
      _selectedSport = 'Football';
    } else if (widget.competitionPrototype.sport == AppConstants.sportCricket) {
      _selectedSport = 'Cricket';
    }

    _performSearch('');
    _loadFeaturedMatches();

    // Trigger auto-discovery of new tournaments (throttled internally)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firestoreService = context.read<FirestoreService>();
      SportsApiService.syncNewlyAvailableTournaments(firestoreService);
    });
  }

  Future<void> _loadFeaturedMatches() async {
    try {
      // Logic for featured leagues
      final List<String> footballIds = [
        'epl-2025',
        'champions-league-2025',
        'la-liga-2025',
      ];
      final List<String> cricketIds = ['ipl-2025', 'bbl-2025'];

      List<String> featuredIds = [];
      if (_selectedSport == 'Football') {
        featuredIds = footballIds;
      } else if (_selectedSport == 'Cricket') {
        featuredIds = cricketIds;
      } else {
        featuredIds = [...footballIds, ...cricketIds];
      }

      final List<Map<String, dynamic>> allMatches = [];

      for (var id in featuredIds) {
        final matches = await SportsApiService.getUpcomingMatches(id);
        allMatches.addAll(matches);
      }

      allMatches.sort(
        (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _upcomingMatches = allMatches.take(10).toList();
        });
      }
    } catch (e) {
      // Ignore errors in background match load
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      var results = await SportsApiService.searchTournaments(query);

      // Apply sport filter
      if (_selectedSport != 'All') {
        results = results
            .where(
              (t) =>
                  t.sport.toLowerCase() == _selectedSport.toLowerCase() ||
                  (t.sport == AppConstants.sportFootball &&
                      _selectedSport == 'Football') ||
                  (t.sport == AppConstants.sportCricket &&
                      _selectedSport == 'Cricket'),
            )
            .toList();
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importTournament(OfficialTournamentModel tournament) async {
    setState(() {
      _isImporting = true;
      _statusText = 'Fetching official teams...';
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final competitionId = widget.competitionPrototype.id;

      // 1. Update Competition Info (preserve user's custom name)
      final updatedComp = widget.competitionPrototype.copyWith(
        leagueId: tournament.id,
        logoUrl: tournament.logoUrl,
        status: 'active', // Ensure imported tournaments are active
        participantCount: 1, // Fix: Ensure count is 1 (Organizer) not 0
      );
      await firestore.updateCompetition(updatedComp);

      // 2. Import Teams
      final teamsData = await SportsApiService.importTeams(tournament.id);
      setState(() => _statusText = 'Creating ${teamsData.length} teams...');

      final List<TeamModel> createdTeams = [];
      for (var t in teamsData) {
        final team = TeamModel(
          id: const Uuid().v4(),
          name: t['name']!,
          shortName: t['code']!,
          logoUrl: (t['logoUrl'] != null && t['logoUrl']!.isNotEmpty)
              ? t['logoUrl']
              : null,
          competitionId: competitionId,
          createdAt: DateTime.now(),
        );
        await firestore.createTeam(team);
        createdTeams.add(team);
      }

      // 3. Import Fixtures
      setState(() => _statusText = 'Importing official match schedule...');
      final matches = await TournamentDataService.getTournamentFixtures(
        competitionId,
        tournament.id,
        createdTeams,
      );

      if (matches.isNotEmpty) {
        await firestore.createBatchMatches(matches);
      }

      await firestore.recalculateStandings(competitionId);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionDetailScreen(competitionId: competitionId),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Tournament Dictionary'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Search (e.g. Euro, Premier, World Cup)',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.accentGreen,
                    ),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Only show sport filters if we haven't already locked into a specific sport
              if (_selectedSport == 'All') _buildSportFilters(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_upcomingMatches.isNotEmpty) _buildUpcomingMatchesSection(),
              Expanded(
                child: _isLoading
                    ? const Center(child: LoadingSpinner())
                    : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'No tournaments found. Try another search.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final t = _results[index];
                          return Card(
                            color: AppColors.cardBackground,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.accentGreen.withAlpha(51),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 50,
                                height: 50,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: t.logoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: t.logoUrl!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.emoji_events,
                                        color: AppColors.accentGreen,
                                      ),
                              ),
                              title: Text(
                                t.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${t.country} • ${t.sport}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onTap: () => _importTournament(t),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_isImporting)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingSpinner(size: 60),
                    const SizedBox(height: 24),
                    Text(
                      _statusText ?? 'Importing data...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This sets up all teams and fixtures automatically.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMatchesSection() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'RECENT & UPCOMING',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _upcomingMatches.length,
              itemBuilder: (context, index) {
                final match = _upcomingMatches[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${match['team1']} vs ${match['team2']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEE, MMM d • h:mm a').format(match['time']),
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        match['leagueId'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('All'),
          const SizedBox(width: 8),
          _buildFilterChip('Football'),
          const SizedBox(width: 8),
          _buildFilterChip('Cricket'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedSport == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedSport = label;
          });
          _performSearch(_searchController.text);
        }
      },
      backgroundColor: AppColors.cardBackground,
      selectedColor: AppColors.accentGreen.withAlpha(51),
      checkmarkColor: AppColors.accentGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.accentGreen : AppColors.dividerColor,
        ),
      ),
    );
  }
}
