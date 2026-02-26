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
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    // Pre-filter based on the sport selected during competition creation
    if (widget.competitionPrototype.sport == AppConstants.sportFootball) {
      _selectedSport = 'Football';
    } else if (widget.competitionPrototype.sport == AppConstants.sportCricket) {
      _selectedSport = 'Cricket';
    }

    _performSearch('');
    _loadFeaturedMatches();

    // Trigger auto-discovery of new tournaments (throttled internally)
    // RESTRICTED: Only Master Admins should trigger scraping/syncing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAdmin) {
        final firestoreService = context.read<FirestoreService>();
        SportsApiService.syncNewlyAvailableTournaments(firestoreService);
      }
    });
  }

  void _checkAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      if (AppConstants.adminEmails.contains(user.email!.toLowerCase())) {
        _isAdmin =
            true; // No setState needed in initState usually, but safe to set var
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _loadFeaturedMatches() async {
    try {
      // Logic for featured leagues
      final List<String> footballIds = [
        'epl-2025',
        'champions-league-2025',
        'la-liga-2025',
        'isl-2025',
      ];
      final List<String> cricketIds = ['ipl-2025', 'bbl-2025'];

      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final blacklist = await firestore.getBlacklistedTournamentIds();

      List<String> featuredIds = [];
      if (_selectedSport == 'Football') {
        featuredIds = footballIds;
      } else if (_selectedSport == 'Cricket') {
        featuredIds = cricketIds;
      } else {
        featuredIds = [...footballIds, ...cricketIds];
      }

      // Filter out master deleted tournaments
      featuredIds.removeWhere((id) => blacklist.contains(id));

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var results = await SportsApiService.searchTournaments(query);

      // Apply sport filter — simple case-insensitive match
      if (_selectedSport != 'All') {
        results = results
            .where((t) => t.sport.toLowerCase() == _selectedSport.toLowerCase())
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

  Future<void> _handleMasterDelete(OfficialTournamentModel tournament) async {
    final TextEditingController deleteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Master Delete?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove "${tournament.name}" from the global database for ALL users. Use with extreme caution.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type "DELETE" to confirm:',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: deleteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
              if (deleteController.text == 'DELETE') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verification failed. Type DELETE.'),
                  ),
                );
              }
            },
            child: const Text(
              'Confirm Master Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestore = context.read<FirestoreService>();
        await firestore.masterDeleteTournament(tournament.id);
        _performSearch(_searchController.text); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tournament removed from master database'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
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
      final teamsData = await SportsApiService.importTeams(
        tournament.externalId ?? tournament.id,
        source: tournament.source,
      );
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
        title: const Text('Official Tournaments'),
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
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final t = _results[index];
                          return _buildTournamentCard(t);
                        },
                      ),
              ),
            ],
          ),
          if (_isImporting) _buildImportingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(OfficialTournamentModel t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _importTournament(t),
            onLongPress: _isAdmin ? () => _handleMasterDelete(t) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Logo with glow
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: t.logoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: t.logoUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) => const Icon(
                              Icons.emoji_events,
                              color: AppColors.accentGreen,
                            ),
                          )
                        : const Icon(
                            Icons.emoji_events,
                            color: AppColors.accentGreen,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              t.sport.toLowerCase() == 'cricket'
                                  ? Icons.sports_cricket
                                  : Icons.sports_soccer,
                              size: 14,
                              color: AppColors.accentGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${t.country} • ${t.sport}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.accentGreen.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tournament Not Found?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isAdmin
                  ? 'Try syncing new real-time tournaments from our global sports feed.'
                  : 'Official tournaments are added by our team periodically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingSpinner(size: 80),
            const SizedBox(height: 32),
            Text(
              _statusText ?? 'Processing...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aligning teams, logos, and match schedules',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                color: AppColors.accentGreen,
              ),
            ),
          ],
        ),
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
