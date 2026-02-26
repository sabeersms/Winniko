import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/allsports_api_service.dart';
import '../constants/app_constants.dart';

/// Tournament Discovery Screen
///
/// Helps you find tournament IDs, season IDs, and explore available sports/competitions
class TournamentDiscoveryScreen extends StatefulWidget {
  const TournamentDiscoveryScreen({super.key});

  @override
  State<TournamentDiscoveryScreen> createState() =>
      _TournamentDiscoveryScreenState();
}

class _TournamentDiscoveryScreenState extends State<TournamentDiscoveryScreen> {
  final AllSportsApiService _apiService = AllSportsApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _sports = [];
  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _loadingSports = false;
  bool _loadingTournaments = false;
  bool _loadingSeasons = false;
  bool _searching = false;

  int? _selectedSportId;
  String? _selectedTournamentId;
  String? _selectedTournamentName;

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    setState(() => _loadingSports = true);
    try {
      final sports = await _apiService.getSports();
      setState(() {
        _sports = sports;
        _loadingSports = false;
      });
    } catch (e) {
      setState(() => _loadingSports = false);
      _showError('Failed to load sports: $e');
    }
  }

  Future<void> _loadTournaments(int sportId) async {
    setState(() {
      _loadingTournaments = true;
      _selectedSportId = sportId;
      _tournaments = [];
      _seasons = [];
      _selectedTournamentId = null;
    });

    try {
      final tournaments = await _apiService.getTournamentsBySport(sportId);
      setState(() {
        _tournaments = tournaments;
        _loadingTournaments = false;
      });
    } catch (e) {
      setState(() => _loadingTournaments = false);
      _showError('Failed to load tournaments: $e');
    }
  }

  Future<void> _loadSeasons(String tournamentId, String tournamentName) async {
    setState(() {
      _loadingSeasons = true;
      _selectedTournamentId = tournamentId;
      _selectedTournamentName = tournamentName;
      _seasons = [];
    });

    try {
      final seasons = await _apiService.getTournamentSeasons(tournamentId);
      setState(() {
        _seasons = seasons;
        _loadingSeasons = false;
      });
    } catch (e) {
      setState(() => _loadingSeasons = false);
      _showError('Failed to load seasons: $e');
    }
  }

  Future<void> _searchTournaments(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _apiService.searchTournaments(query);
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
      _showError('Search failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Tournament Discovery'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSports,
            tooltip: 'Refresh Sports',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Content
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildBrowseView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cardBackground,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search tournaments (e.g., "Premier League", "IPL")',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.accentGreen),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          if (value.length >= 3) {
            _searchTournaments(value);
          } else {
            setState(() => _searchResults = []);
          }
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No results found. Try a different search term.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultCard(result);
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> result) {
    final type = result['type'] ?? 'unknown';
    final entity = result['entity'];

    if (entity == null) return const SizedBox.shrink();

    final name = entity['name'] ?? 'Unknown';
    final id = entity['id']?.toString() ?? 'N/A';

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accentGreen,
          child: Text(
            type[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Type: $type | ID: $id',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, color: AppColors.accentGreen),
          onPressed: () => _copyToClipboard(id, 'ID'),
        ),
        onTap: () {
          if (type == 'uniqueTournament') {
            _loadSeasons(id, name);
          }
        },
      ),
    );
  }

  Widget _buildBrowseView() {
    return Row(
      children: [
        // Sports List
        Expanded(flex: 1, child: _buildSportsList()),

        // Tournaments List
        if (_selectedSportId != null)
          Expanded(flex: 2, child: _buildTournamentsList()),

        // Seasons List
        if (_selectedTournamentId != null)
          Expanded(flex: 2, child: _buildSeasonsList()),
      ],
    );
  }

  Widget _buildSportsList() {
    return Container(
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sports',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _loadingSports
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sports.length,
                    itemBuilder: (context, index) {
                      final sport = _sports[index];
                      final sportId = sport['id'];
                      final sportName = sport['name'] ?? 'Unknown';
                      final isSelected = _selectedSportId == sportId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryGreen,
                        title: Text(
                          sportName,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'ID: $sportId',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _loadTournaments(sportId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsList() {
    return Container(
      color: AppColors.backgroundDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tournaments',
              style: const TextStyle(
                color: AppColors.accentGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: _loadingTournaments
                ? const Center(child: CircularProgressIndicator())
                : _tournaments.isEmpty
                ? const Center(
                    child: Text(
                      'No tournaments found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tournaments.length,
                    itemBuilder: (context, index) {
                      final tournament = _tournaments[index];
                      final tournamentId = tournament['id']?.toString() ?? '';
                      final tournamentName = tournament['name'] ?? 'Unknown';
                      final category = tournament['category']?['name'] ?? '';
                      final isSelected = _selectedTournamentId == tournamentId;

                      return Card(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.cardBackground,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            tournamentName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (category.isNotEmpty)
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              Text(
                                'ID: $tournamentId',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.accentGreen,
                            ),
                            onPressed: () =>
                                _copyToClipboard(tournamentId, 'Tournament ID'),
                          ),
                          onTap: () =>
                              _loadSeasons(tournamentId, tournamentName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonsList() {
    return Container(
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seasons',
                  style: const TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedTournamentName != null)
                  Text(
                    _selectedTournamentName!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loadingSeasons
                ? const Center(child: CircularProgressIndicator())
                : _seasons.isEmpty
                ? const Center(
                    child: Text(
                      'No seasons found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _seasons.length,
                    itemBuilder: (context, index) {
                      final season = _seasons[index];
                      final seasonId = season['id']?.toString() ?? '';
                      final seasonName =
                          season['name'] ??
                          season['year']?.toString() ??
                          'Unknown';
                      final year = season['year']?.toString() ?? '';

                      return Card(
                        color: AppColors.backgroundDark,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.accentGreen,
                            child: Text(
                              year.isNotEmpty
                                  ? year.substring(year.length - 2)
                                  : '??',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            seasonName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Season ID: $seasonId',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  color: AppColors.accentGreen,
                                ),
                                onPressed: () =>
                                    _copyToClipboard(seasonId, 'Season ID'),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.code,
                                  color: AppColors.accentGreen,
                                ),
                                onPressed: () => _showCodeSnippet(
                                  _selectedTournamentId!,
                                  seasonId,
                                  _selectedTournamentName!,
                                  seasonName,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCodeSnippet(
    String tournamentId,
    String seasonId,
    String tournamentName,
    String seasonName,
  ) {
    final code =
        '''
// $tournamentName - $seasonName
final events = await AllSportsApiService().getSeasonTeamEventsAway(
  tournamentId: '$tournamentId',
  seasonId: '$seasonId',
);

// Or get standings
final standings = await AllSportsApiService().getTournamentStandings(
  tournamentId: '$tournamentId',
  seasonId: '$seasonId',
);
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Code Snippet',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            code,
            style: const TextStyle(
              color: AppColors.accentGreen,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
