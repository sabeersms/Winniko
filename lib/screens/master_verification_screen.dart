import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/tournament_data_service.dart';
import '../services/sports_api_service.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../constants/app_constants.dart';
import '../widgets/loading_spinner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dialogs/tournament_discovery_dialog.dart';
import 'competition_teams_screen.dart';
import '../models/competition_model.dart';

class MasterVerificationScreen extends StatefulWidget {
  const MasterVerificationScreen({super.key});

  @override
  State<MasterVerificationScreen> createState() =>
      _MasterVerificationScreenState();
}

class _MasterVerificationScreenState extends State<MasterVerificationScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedLeagueId;
  bool _isLoading = false;
  List<MatchModel> _softMatches = [];

  // Manual list of important leagues if not fully exposed,
  // but we added supportedLeagues to TournamentDataService.
  // Mapping of League ID to Display Name
  final Map<String, String> _baseLeagues = {};
  final Map<String, String> _leagueSports = {};
  Map<String, String> _leagues = {};
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  bool _isSuperAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    return AppConstants.adminEmails.contains(user.email!.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    for (var l in TournamentDataService.supportedLeagues) {
      _baseLeagues[l] = l.toUpperCase();
      if (l == 'pl' ||
          l == 'laliga' ||
          l == 'bundesliga' ||
          l == 'seriea' ||
          l == 'ligue1' ||
          l == 'ucl' ||
          l == 'wc2026') {
        _leagueSports[l] = AppConstants.sportFootball;
      } else {
        _leagueSports[l] = AppConstants.sportCricket;
      }
    }
    _baseLeagues['epl-2025'] = 'Premier League 25/26';
    _leagueSports['epl-2025'] = AppConstants.sportFootball;

    _baseLeagues['la-liga-2025'] = 'La Liga 25/26';
    _leagueSports['la-liga-2025'] = AppConstants.sportFootball;

    _baseLeagues['champions-league-2025'] = 'UEFA Champions League 25/26';
    _leagueSports['champions-league-2025'] = AppConstants.sportFootball;

    _baseLeagues['isl-2025'] = 'ISL 2025';
    _leagueSports['isl-2025'] = AppConstants.sportFootball;

    _baseLeagues['ipl'] = 'IPL 2025';
    _leagueSports['ipl'] = AppConstants.sportCricket;

    _baseLeagues['mens-t20-world-cup-2026'] = 'T20 World Cup';
    _leagueSports['mens-t20-world-cup-2026'] = AppConstants.sportCricket;

    _baseLeagues['cwc'] = 'Cricket World Cup';
    _leagueSports['cwc'] = AppConstants.sportCricket;

    _baseLeagues['asiacup'] = 'Asia Cup';
    _leagueSports['asiacup'] = AppConstants.sportCricket;

    _leagues = Map.from(_baseLeagues);

    _tabController = TabController(length: 2, vsync: this);

    _loadCustomLeaguePreferences();
  }

  Future<void> _loadCustomLeaguePreferences() async {
    try {
      final firestore = context.read<FirestoreService>();
      final blacklist = await firestore.getBlacklistedTournamentIds();

      final prefs = await SharedPreferences.getInstance();

      final removed = prefs.getStringList('verification_removed_leagues') ?? [];

      // Filter out blacklist from base leagues
      _baseLeagues.removeWhere((id, name) => blacklist.contains(id));

      for (var rId in removed) {
        _baseLeagues.remove(rId);
      }

      final added = prefs.getStringList('verification_added_leagues') ?? [];
      for (var a in added) {
        final parts = a.split('||');
        if (parts.length >= 2) {
          final id = parts[0];
          if (!blacklist.contains(id)) {
            _baseLeagues[id] = parts[1];
            if (parts.length >= 3) {
              _leagueSports[id] = parts[2];
            }
          }
        }
      }

      // 🔥 Global Sync: Load Major Tournaments from Firestore
      final globalMajors = await firestore.getMajorTournaments();
      for (var major in globalMajors) {
        if (!blacklist.contains(major.id)) {
          _baseLeagues[major.id] = major.name;
          _leagueSports[major.id] = major.sport;
        }
      }

      if (mounted && _searchController.text.isEmpty) {
        setState(() {
          _leagues = Map.from(_baseLeagues);
        });
      }
    } catch (e) {
      debugPrint('Error loading custom leagues: $e');
    }
  }

  Future<void> _toggleLeaguePin(String id, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final removed = prefs.getStringList('verification_removed_leagues') ?? [];
      final added = prefs.getStringList('verification_added_leagues') ?? [];

      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      final bool isCurrentlyPinned = _baseLeagues.containsKey(id);
      final bool willBePinned = !isCurrentlyPinned;

      setState(() {
        if (isCurrentlyPinned) {
          // Unpin
          _baseLeagues.remove(id);
          added.removeWhere((item) => item.startsWith('$id||'));
          if (!removed.contains(id)) {
            removed.add(id);
          }
        } else {
          // Pin
          _baseLeagues[id] = name;
          removed.remove(id);
          final entry = '$id||$name';
          if (!added.contains(entry)) {
            added.add(entry);
          }
        }
      });

      // 🔥 Global Sync
      await firestoreService.toggleMajorStatus(
        id,
        willBePinned,
        name: name,
        sport: _leagueSports[id] ?? _getSportForLeague(id, name),
      );

      await prefs.setStringList('verification_removed_leagues', removed);
      await prefs.setStringList('verification_added_leagues', added);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pin league: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _leagues = Map.from(_baseLeagues));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await SportsApiService.searchTournaments(query);
      if (mounted) {
        setState(() {
          _leagues = {for (var t in results) t.id: t.name};
          for (var t in results) {
            _leagueSports[t.id] = t.sport;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _handleMasterDelete(String id, String name) async {
    final TextEditingController deleteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Master Delete Tournament?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove "$name" from the global discovery database. Predictions and results for active competitions using this tournament ID might be affected.',
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
        await firestore.masterDeleteTournament(id);

        if (mounted) {
          setState(() {
            _leagues.remove(id);
            _baseLeagues.remove(id);
            _leagueSports.remove(id);
            if (_selectedLeagueId == id) _selectedLeagueId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tournament deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Future<void> _showAddTournamentDialog() async {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    String selectedSport = AppConstants.sportCricket;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Add Tournament Manually',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tournament Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. IPL 2025',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: idController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tournament ID (Slug)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. ipl-2025',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  helperText: 'Must be unique, lowercase, no spaces',
                  helperStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSport,
                dropdownColor: AppColors.cardBackground,
                style: const TextStyle(color: Colors.white),
                items: [AppConstants.sportCricket, AppConstants.sportFootball]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSport = v!),
                decoration: InputDecoration(
                  labelText: 'Sport',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final id = idController.text.trim().toLowerCase().replaceAll(
                  ' ',
                  '-',
                );

                if (name.isEmpty || id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                try {
                  // 1. Save to SharedPreferences (for the list)
                  final prefs = await SharedPreferences.getInstance();
                  final added =
                      prefs.getStringList('verification_added_leagues') ?? [];
                  final entry = '$id||$name||$selectedSport';

                  if (!added.contains(entry)) {
                    // Remove any old entry for this ID if format was different
                    added.removeWhere((e) => e.startsWith('$id||'));
                    added.add(entry);
                    await prefs.setStringList(
                      'verification_added_leagues',
                      added,
                    );
                  }

                  // 2. Register in Firestore discovered_tournaments
                  await FirebaseFirestore.instance
                      .collection('discovered_tournaments')
                      .doc(id)
                      .set({
                        'id': id,
                        'name': name,
                        'sport': selectedSport,
                        'discoveredAt': FieldValue.serverTimestamp(),
                        'status': 'active',
                        'source': 'manual',
                        'isMajor': true, // Auto-pin for visibility
                      }, SetOptions(merge: true));

                  // 3. Update local state
                  await _loadCustomLeaguePreferences();

                  if (mounted) {
                    setState(() {
                      _selectedLeagueId = id;
                      _leagues[id] = name;
                      _leagueSports[id] = selectedSport;
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tournament "$name" added successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Tournament'),
            ),
          ],
        ),
      ),
    );
  }

  void _openDiscovery() {
    showDialog(
      context: context,
      builder: (ctx) => const TournamentDiscoveryDialog(),
    ).then((_) {
      // Reload custom leagues in case new discovery results were pinned
      _loadCustomLeaguePreferences();
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    });
  }

  Future<void> _loadSoftMatches(String leagueId) async {
    setState(() {
      _isLoading = true;
      _selectedLeagueId = leagueId;
      _softMatches = [];
    });
    _tabController.animateTo(1);

    try {
      final matches = await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).getSoftMatches(leagueId);

      // Filter out warm-up matches AND matches before Feb 7, 2025
      final cutoffDate = DateTime(2025, 2, 7);
      final filteredMatches = matches.where((m) {
        // Cutoff check
        if (m.scheduledTime.isBefore(cutoffDate)) return false;

        final round = (m.round ?? '').toLowerCase();
        final group = (m.group ?? '').toLowerCase();
        final isWarmup =
            round.contains('warm-up') ||
            round.contains('warmup') ||
            round.contains('warm up') ||
            group.contains('warm-up') ||
            group.contains('warmup') ||
            group.contains('warm up');
        return !isWarmup;
      }).toList();

      // Sort by Match Number (Primary), then Time
      filteredMatches.sort((a, b) {
        final aNum = a.matchNumber ?? 0;
        final bNum = b.matchNumber ?? 0;
        if (aNum != 0 || bNum != 0) {
          if (aNum != bNum) return aNum.compareTo(bNum);
        }
        return a.scheduledTime.compareTo(b.scheduledTime);
      });

      setState(() {
        _softMatches = filteredMatches;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading soft matches: $e')),
        );
      }
    }
  }

  Future<void> _promoteToHardCopy() async {
    if (!_isSuperAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only super admins can verify and promote matches.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedLeagueId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify & Promote?'),
        content: Text(
          'This will overwrite the OFFICIAL matches for $_selectedLeagueId with these ${_softMatches.length} soft copy matches. '
          'Users will see this data immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'VERIFY',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final leagueName = _leagues[_selectedLeagueId] ?? _selectedLeagueId!;
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).promoteSoftToHardCopy(
        _selectedLeagueId!,
        sport: _getSportForLeague(_selectedLeagueId!, leagueName),
        name: leagueName,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Data Verified & Published! Users are being updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error ensuring hard copy: $e')));
      }
    }
  }

  Future<void> _cleanHardCopies() async {
    if (!_isSuperAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only super admins can clean hard copies.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedLeagueId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete ALL Hard Copies?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will PERMANENTLY delete all verified matches for $_selectedLeagueId from the database. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'DELETE ALL',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).cleanHardCopy(_selectedLeagueId!);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All verified matches deleted for this league.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cleaning hard copy: $e')));
      }
    }
  }

  Future<void> _cleanSoftMatches() async {
    if (!_isSuperAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only super admins can clean soft matches.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedLeagueId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete ALL Soft Matches?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will PERMANENTLY delete all unverified draft matches for $_selectedLeagueId. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'DELETE SOFT',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await Provider.of<FirestoreService>(
        context,
        listen: false,
      ).cleanSoftCopy(_selectedLeagueId!);

      await _loadSoftMatches(_selectedLeagueId!);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All soft matches deleted for this league.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cleaning soft matches: $e')),
        );
      }
    }
  }

  // Method to trigger a Fetch manually (as if the Script ran)
  // Useful for testing the flow without waiting 2 hours.
  Future<void> _manualFetch() async {
    if (_selectedLeagueId == null) return;

    setState(() => _isLoading = true);
    try {
      List<TeamModel> dummyTeams = [];
      try {
        final importedTeamsData = await SportsApiService.importTeams(
          _selectedLeagueId!,
        );
        final firestore = Provider.of<FirestoreService>(context, listen: false);
        final dummyCompId = 'master_override_$_selectedLeagueId';

        for (var e in importedTeamsData) {
          final t = TeamModel(
            id: e['name']!.toLowerCase().replaceAll(' ', '_'),
            name: e['name']!,
            shortName: e['code']!,
            logoUrl: e['logoUrl']!,
            competitionId: dummyCompId,
            createdAt: DateTime.now(),
            competitionName: _baseLeagues[_selectedLeagueId],
          );
          dummyTeams.add(t);
          await firestore.createTeam(t);
        }
      } catch (e) {
        debugPrint('Could not import teams for $_selectedLeagueId: $e');
      }

      await TournamentDataService.fetchAndSaveSoftCopy(
        'master_override_$_selectedLeagueId', // Dummy Comp ID
        _selectedLeagueId!,
        dummyTeams,
      );

      await _loadSoftMatches(_selectedLeagueId!);
    } catch (e) {
      // Ignore mapping errors, just refresh list
      if (mounted) {
        _loadSoftMatches(_selectedLeagueId!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fetch triggered (check logs for mapping issues): $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSoftMatch(MatchModel match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Match?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete match #${match.matchNumber} (${match.team1Name} vs ${match.team2Name}) from soft copy?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final firestore = Provider.of<FirestoreService>(context, listen: false);
        await firestore.deleteSoftMatch(_selectedLeagueId!, match.id);
        await _loadSoftMatches(_selectedLeagueId!);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Future<void> _showEditSoftMatchDialog(MatchModel match) async {
    if (!_isSuperAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only super admins can edit soft matches.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    DateTime selectedTime = match.scheduledTime;
    final t1ScoreCtrl = TextEditingController(
      text: (match.actualScore?['team1'] ?? match.actualScore?['t1Runs'])?.toString() ?? '',
    );
    final t2ScoreCtrl = TextEditingController(
      text: (match.actualScore?['team2'] ?? match.actualScore?['t2Runs'])?.toString() ?? '',
    );
    // Remove forced 0s for upcoming matches in the UI
    if (match.isUpcoming) {
      if (t1ScoreCtrl.text == '0') t1ScoreCtrl.text = '';
      if (t2ScoreCtrl.text == '0') t2ScoreCtrl.text = '';
    }
    final t1NameCtrl = TextEditingController(text: match.team1Name);
    final t2NameCtrl = TextEditingController(text: match.team2Name);
    String selectedStatus = match.status.toLowerCase();
    if (!['upcoming', 'progressing', 'finished'].contains(selectedStatus)) {
      if (selectedStatus == 'live') {
        selectedStatus = 'progressing';
      } else if (selectedStatus == 'completed') {
        selectedStatus = 'finished';
      } else {
        selectedStatus = 'upcoming';
      }
    }
    final t1WicketsCtrl = TextEditingController(
      text: match.actualScore?['t1Wickets']?.toString() ?? '',
    );
    final t2WicketsCtrl = TextEditingController(
      text: match.actualScore?['t2Wickets']?.toString() ?? '',
    );
    final t1OversCtrl = TextEditingController(
      text: match.actualScore?['t1Overs']?.toString() ?? '',
    );
    final t2OversCtrl = TextEditingController(
      text: match.actualScore?['t2Overs']?.toString() ?? '',
    );

    // Filter out default 0s/0.0s for upcoming matches to keep UI clean
    if (match.isUpcoming) {
      if (t1WicketsCtrl.text == '0') t1WicketsCtrl.text = '';
      if (t2WicketsCtrl.text == '0') t2WicketsCtrl.text = '';
      if (t1OversCtrl.text == '0' || t1OversCtrl.text == '0.0') t1OversCtrl.text = '';
      if (t2OversCtrl.text == '0' || t2OversCtrl.text == '0.0') t2OversCtrl.text = '';
    }

    final marginValueCtrl = TextEditingController(
      text: match.actualScore?['marginValue']?.toString() ?? '',
    );

    final matchNumCtrl = TextEditingController(
      text: match.matchNumber?.toString() ?? '',
    );

    String? selectedWinnerId = match.actualScore?['winnerId']?.toString();
    if (![
      null,
      'tied',
      'draw',
      'no_result',
      match.team1Id,
      match.team2Id,
    ].contains(selectedWinnerId)) {
      selectedWinnerId = null;
    }

    String? selectedBattingFirstId = match.actualScore?['battingFirstId']
        ?.toString();
    if (![
      null,
      match.team1Id,
      match.team2Id,
    ].contains(selectedBattingFirstId)) {
      selectedBattingFirstId = null;
    }

    String selectedMarginType =
        match.actualScore?['marginType']?.toString() ?? 'runs';
    if (!['runs', 'wickets', 'goals'].contains(
      selectedMarginType,
    )) {
      selectedMarginType = 'runs';
    }

    String? selectedTieBreakerWinnerId =
        match.actualScore?['tieBreakerWinnerId']?.toString();
    if (![match.team1Id, match.team2Id].contains(selectedTieBreakerWinnerId)) {
      selectedTieBreakerWinnerId = null;
    }

    final sport = _getSportForLeague(
      _selectedLeagueId ?? '',
      _leagues[_selectedLeagueId] ?? _baseLeagues[_selectedLeagueId],
    );

    void calculateCricketResult(void Function(void Function()) setDialogState) {
      if (sport != AppConstants.sportCricket) return;

      final t1RunsStr = t1ScoreCtrl.text;
      final t2RunsStr = t2ScoreCtrl.text;
      if (t1RunsStr.isEmpty || t2RunsStr.isEmpty) return;

      final int t1Runs = int.tryParse(t1RunsStr) ?? 0;
      final int t2Runs = int.tryParse(t2RunsStr) ?? 0;
      final int t1Wkts = int.tryParse(t1WicketsCtrl.text) ?? 0;
      final int t2Wkts = int.tryParse(t2WicketsCtrl.text) ?? 0;

      String? calculatedWinner;
      String? calculatedMarginType;
      String? calculatedMarginValue;

      if (t1Runs > t2Runs) {
        calculatedWinner = match.team1Id;
      } else if (t2Runs > t1Runs) {
        calculatedWinner = match.team2Id;
      } else {
        calculatedWinner = 'tied';
      }

      if (calculatedWinner != 'tied' &&
          calculatedWinner != 'no_result') {
        if (calculatedWinner == selectedBattingFirstId) {
          calculatedMarginType = 'runs';
          calculatedMarginValue = (t1Runs - t2Runs).abs().toString();
        } else if (selectedBattingFirstId != null) {
          calculatedMarginType = 'wickets';
          final winnerWickets = calculatedWinner == match.team1Id
              ? t1Wkts
              : t2Wkts;
          final wicketsLeft = (10 - winnerWickets).clamp(0, 10);
          calculatedMarginValue = wicketsLeft.toString();
        }
      }

      setDialogState(() {
        if (calculatedWinner != null) selectedWinnerId = calculatedWinner;
        if (calculatedMarginType != null) {
          selectedMarginType = calculatedMarginType;
        }
        if (calculatedMarginValue != null) {
          marginValueCtrl.text = calculatedMarginValue;
        }
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            match.id.isEmpty ? 'Add New Match' : 'Edit Match Details',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: t1NameCtrl,
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Team 1',
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) => setDialogState(() {}),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          'vs',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: t2NameCtrl,
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Team 2',
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Date & Time Picker
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedTime,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2027),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedTime),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat(
                            'EEE, MMM d, yyyy | h:mm a',
                          ).format(selectedTime),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: matchNumCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Match #',
                          labelStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          hintText: 'e.g. 1',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()), // Placeholder
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: t1ScoreCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  sport == AppConstants.sportCricket
                                  ? 'Runs'
                                  : 'Goals',
                              labelStyle: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 11,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                calculateCricketResult(setDialogState),
                          ),
                          if (sport == AppConstants.sportCricket) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: t1WicketsCtrl,
                                    onChanged: (_) =>
                                        calculateCricketResult(setDialogState),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Wic',
                                      labelStyle: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: t1OversCtrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Ov',
                                      labelStyle: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: t2ScoreCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: sport == AppConstants.sportCricket
                                  ? 'Runs'
                                  : 'Goals',
                              labelStyle: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 11,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                calculateCricketResult(setDialogState),
                          ),
                          if (sport == AppConstants.sportCricket) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: t2WicketsCtrl,
                                    onChanged: (_) =>
                                        calculateCricketResult(setDialogState),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Wic',
                                      labelStyle: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: t2OversCtrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Ov',
                                      labelStyle: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (sport == AppConstants.sportCricket) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBattingFirstId,
                    dropdownColor: AppColors.cardBackground,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Batted First',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: const Text('Unknown'),
                      ),
                      DropdownMenuItem(
                        value: match.team1Id,
                        child: Text(t1NameCtrl.text),
                      ),
                      DropdownMenuItem(
                        value: match.team2Id,
                        child: Text(t2NameCtrl.text),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedBattingFirstId = val);
                      calculateCricketResult(setDialogState);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // winner selection
                DropdownButtonFormField<String>(
                  value: selectedWinnerId,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Match Outcome',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: const Text('None')),
                    if (sport == AppConstants.sportCricket) ...[
                      DropdownMenuItem(
                        value: 'tied',
                        child: const Text('Tied'),
                      ),
                      DropdownMenuItem(
                        value: 'no_result',
                        child: const Text('No Result'),
                      ),
                    ] else ...[
                      DropdownMenuItem(
                        value: 'draw',
                        child: const Text('Draw'),
                      ),
                    ],
                    DropdownMenuItem(
                      value: match.team1Id,
                      child: Text(t1NameCtrl.text),
                    ),
                    DropdownMenuItem(
                      value: match.team2Id,
                      child: Text(t2NameCtrl.text),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedWinnerId = val);
                    calculateCricketResult(setDialogState);
                  },
                ),
                if (selectedWinnerId == 'tied' || selectedWinnerId == 'draw') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedTieBreakerWinnerId,
                    dropdownColor: AppColors.cardBackground,
                    style: const TextStyle(color: AppColors.accentGreen),
                    decoration: const InputDecoration(
                      labelText: 'Tie Breaker / Special Winner',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.emoji_events, color: AppColors.accentGreen, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Tie Breaker')),
                      DropdownMenuItem(
                        value: match.team1Id,
                        child: Text('${t1NameCtrl.text} Wins'),
                      ),
                      DropdownMenuItem(
                        value: match.team2Id,
                        child: Text('${t2NameCtrl.text} Wins'),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedTieBreakerWinnerId = val);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (selectedWinnerId != 'tied' &&
                    selectedWinnerId != 'no_result' &&
                    selectedWinnerId != 'draw' &&
                    selectedWinnerId != null)
                  if (sport == AppConstants.sportCricket) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedMarginType,
                          dropdownColor: AppColors.cardBackground,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'runs',
                              child: Text('Runs'),
                            ),
                            DropdownMenuItem(
                              value: 'wickets',
                              child: Text('Wickets'),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedMarginType = val!);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: marginValueCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              calculateCricketResult(setDialogState),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'upcoming',
                      child: Text('upcoming'),
                    ),
                    DropdownMenuItem(
                      value: 'progressing',
                      child: Text('progressing'),
                    ),
                    DropdownMenuItem(
                      value: 'finished',
                      child: Text('finished'),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedStatus = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // First update the draft values locally in the match object
                final newScore = Map<String, dynamic>.from(
                  match.actualScore ?? {},
                );
                newScore['verified'] = true;
                newScore['manuallyScored'] = true;

                if (t1ScoreCtrl.text.isNotEmpty) {
                  int val = int.tryParse(t1ScoreCtrl.text) ?? 0;
                  newScore['team1'] = val;
                  if (sport == AppConstants.sportCricket) {
                    newScore['t1Runs'] = val;
                  }
                }
                if (t2ScoreCtrl.text.isNotEmpty) {
                  int val = int.tryParse(t2ScoreCtrl.text) ?? 0;
                  newScore['team2'] = val;
                  if (sport == AppConstants.sportCricket) {
                    newScore['t2Runs'] = val;
                  }
                }

                if (sport == AppConstants.sportCricket) {
                  if (t1ScoreCtrl.text.isNotEmpty) {
                    newScore['t1Runs'] = int.tryParse(t1ScoreCtrl.text) ?? 0;
                  }
                  if (t2ScoreCtrl.text.isNotEmpty) {
                    newScore['t2Runs'] = int.tryParse(t2ScoreCtrl.text) ?? 0;
                  }
                  if (t1WicketsCtrl.text.isNotEmpty) {
                    newScore['t1Wickets'] = int.tryParse(t1WicketsCtrl.text) ?? 0;
                  }
                  if (t2WicketsCtrl.text.isNotEmpty) {
                    newScore['t2Wickets'] = int.tryParse(t2WicketsCtrl.text) ?? 0;
                  }
                  if (t1OversCtrl.text.isNotEmpty) {
                    newScore['t1Overs'] = double.tryParse(t1OversCtrl.text) ?? 0.0;
                  }
                  if (t2OversCtrl.text.isNotEmpty) {
                    newScore['t2Overs'] = double.tryParse(t2OversCtrl.text) ?? 0.0;
                  }
                  newScore['battingFirstId'] = selectedBattingFirstId;

                  // Handled by calculateCricketResult on change
                newScore['winnerId'] = selectedWinnerId;
                newScore['tieBreakerWinnerId'] = selectedTieBreakerWinnerId;
                newScore['marginType'] = selectedMarginType;
                newScore['marginValue'] = marginValueCtrl.text;
              }

              newScore['winnerId'] = selectedWinnerId;
              newScore['tieBreakerWinnerId'] = selectedTieBreakerWinnerId;

                // Respect the user's selected status — do NOT auto-override to 'finished'
                final updatedMatch = match.copyWith(
                  status: selectedStatus,
                  team1Name: t1NameCtrl.text,
                  team2Name: t2NameCtrl.text,
                  scheduledTime: selectedTime,
                  actualScore: newScore,
                  winnerId: selectedWinnerId,
                  matchNumber: int.tryParse(matchNumCtrl.text),
                );

                Navigator.pop(ctx); // Close dialog
                _verifyAndPushSingle(updatedMatch); // Trigger external sync
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Verify & Push'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTeamsScreen() {
    if (_selectedLeagueId == null) return;

    final name =
        _leagues[_selectedLeagueId!] ??
        _baseLeagues[_selectedLeagueId!] ??
        _selectedLeagueId!;
    final sport = _getSportForLeague(_selectedLeagueId!, name);
    final user = FirebaseAuth.instance.currentUser;
    final dummyCompId = 'master_override_$_selectedLeagueId';

    final dummyComp = CompetitionModel(
      id: dummyCompId,
      organizerId: user?.uid ?? 'master_system',
      organizerName: 'System Master',
      name: name,
      sport: sport,
      format: 'League',
      isPublic: true,
      joinCode: '000000',
      locationRestrictionType: 'none',
      rules: {'correctWinner': 3, 'correctScore': 1},
      isPaid: false,
      participantCount: 0,
      createdAt: DateTime.now(),
      status: 'active',
      leagueId: _selectedLeagueId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompetitionTeamsScreen(competition: dummyComp),
      ),
    ).then((result) {
      if (result == 'add_match') {
        _showMatchPairingDialog();
      } else {
        _loadSoftMatches(_selectedLeagueId!);
      }
    });
  }

  Future<void> _showMatchPairingDialog() async {
    // We need teams to select from
    setState(() => _isLoading = true);
    try {
      final dummyCompId = 'master_override_$_selectedLeagueId';
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      List<TeamModel> teams = await firestore.getTeams(dummyCompId).first;

      if (teams.length < 2) {
        // Try importing teams if none found
        final imported = await SportsApiService.importTeams(_selectedLeagueId!);
        if (imported.isNotEmpty) {
          for (var tData in imported) {
            final t = TeamModel(
              id: (tData['id'] ?? tData['name'] ?? '').toLowerCase().replaceAll(
                ' ',
                '_',
              ),
              name: tData['name'] ?? 'Unknown',
              shortName: tData['code'] ?? '',
              logoUrl: tData['logoUrl'] ?? '',
              competitionId: dummyCompId,
              createdAt: DateTime.now(),
              competitionName: _baseLeagues[_selectedLeagueId],
            );
            await firestore.createTeam(t);
          }
          // Re-fetch
          teams = await firestore.getTeams(dummyCompId).first;
        }
      }

      setState(() => _isLoading = false);

      if (teams.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough teams found for this league.'),
            ),
          );
        }
        return;
      }

      TeamModel? t1 = teams[0];
      TeamModel? t2 = teams[1];

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text('New Match: Select Teams'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TeamModel>(
                  initialValue: t1,
                  dropdownColor: AppColors.cardBackground,
                  items: teams
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => t1 = v),
                  decoration: const InputDecoration(labelText: 'Team 1'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TeamModel>(
                  initialValue: t2,
                  dropdownColor: AppColors.cardBackground,
                  items: teams
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => t2 = v),
                  decoration: const InputDecoration(labelText: 'Team 2'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (t1 == null || t2 == null || t1!.id == t2!.id) return;
                  Navigator.pop(ctx);
                  _showEditSoftMatchDialog(
                    MatchModel(
                      id: '', // Signal new match
                      competitionId: 'master_override_$_selectedLeagueId',
                      team1Id: t1!.id,
                      team1Name: t1!.name,
                      team1LogoUrl: t1!.logoUrl,
                      team2Id: t2!.id,
                      team2Name: t2!.name,
                      team2LogoUrl: t2!.logoUrl,
                      scheduledTime: DateTime.now(),
                      status: 'upcoming',
                      round: 'Group Stage',
                    ),
                  );
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error preparing add match: $e');
    }
  }

  Future<void> _verifyAndPushSingle(MatchModel match) async {
    if (_selectedLeagueId == null) return;
    setState(() => _isLoading = true);
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.verifyAndPushMatch(_selectedLeagueId!, match);

      if (mounted) {
        await _loadSoftMatches(_selectedLeagueId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Match verified and pushed to all competitions!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Master Verification'),
        backgroundColor: AppColors.cardBackground,
        actions: [
          if (_selectedLeagueId != null && _softMatches.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadSoftMatches(_selectedLeagueId!),
              tooltip: 'Refresh List',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGreen,
          labelColor: AppColors.accentGreen,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Tournaments'),
            Tab(text: 'Matches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tournaments List
          Stack(
            children: [
              Container(
                color: AppColors.cardBackground,
                padding: const EdgeInsets.only(
                  bottom: 140,
                ), // Room for bottom buttons
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search Tournaments...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: _performSearch,
                      ),
                    ),
                    Expanded(
                      child:
                          _leagues.isEmpty && _searchController.text.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No local matches for this search.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Try searching globally with the "Discover" tool below.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: _showAddTournamentDialog,
                                      icon: const Icon(
                                        Icons.add,
                                        color: AppColors.accentGreen,
                                      ),
                                      label: const Text(
                                        'Add Manually',
                                        style: TextStyle(
                                          color: AppColors.accentGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _leagues.length,
                              itemBuilder: (context, index) {
                                final leagueId = _leagues.keys.elementAt(index);
                                final leagueName = _leagues[leagueId]!;
                                final isSelected =
                                    leagueId == _selectedLeagueId;
                                final isPinned = _baseLeagues.containsKey(
                                  leagueId,
                                );

                                return ListTile(
                                  title: Text(
                                    leagueName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    leagueId,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isPinned
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: isPinned
                                              ? AppColors.accentGreen
                                              : AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () => _toggleLeaguePin(
                                          leagueId,
                                          leagueName,
                                        ),
                                        tooltip: isPinned
                                            ? 'Remove from Major Tournaments'
                                            : 'Add to Major Tournaments',
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                          size: 20,
                                        ),
                                        onPressed: () => _handleMasterDelete(
                                          leagueId,
                                          leagueName,
                                        ),
                                        tooltip: 'Master Delete Tournament',
                                      ),
                                    ],
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.accentGreen
                                      .withOpacity(0.05),
                                  onTap: () => _loadSoftMatches(leagueId),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom Buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openDiscovery,
                            icon: const Icon(Icons.sync),
                            label: const Text('Discover New Tournaments'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _showAddTournamentDialog,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.accentGreen,
                              size: 18,
                            ),
                            label: const Text(
                              'Add Tournament Manually',
                              style: TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.accentGreen,
                              ),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Tab 2: Matches Content
          _selectedLeagueId == null
              ? const Center(
                  child: Text(
                    'Select a League to Verify',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    // Header Actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _leagues[_selectedLeagueId] ??
                                      _selectedLeagueId!.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Sync Status / Pause Toggle
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('official_leagues')
                                    .doc(_selectedLeagueId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists) {
                                    return const SizedBox.shrink();
                                  }
                                  final data =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>;
                                  final bool isPaused =
                                      data['syncPaused'] == true;
                                  final lastCleaned =
                                      data['lastCleanedAt'] as Timestamp?;

                                  return Row(
                                    children: [
                                      if (lastCleaned != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: Tooltip(
                                            message:
                                                'Last Cleaned: ${DateFormat('MMM d, h:mm a').format(lastCleaned.toDate())}. Sync will skip matches before this.',
                                            child: const Icon(
                                              Icons.history_toggle_off,
                                              size: 16,
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                      Switch(
                                        value: !isPaused,
                                        activeThumbColor: AppColors.accentGreen,
                                        onChanged: (val) async {
                                          await FirebaseFirestore.instance
                                              .collection('official_leagues')
                                              .doc(_selectedLeagueId)
                                              .set({'syncPaused': !val}, SetOptions(merge: true));
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                val
                                                    ? 'Sync Resumed'
                                                    : 'Sync Paused',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        isPaused ? 'PAUSED' : 'SYNC ON',
                                        style: TextStyle(
                                          color: isPaused
                                              ? Colors.redAccent
                                              : AppColors.accentGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          Text(
                            '${_softMatches.length} soft matches pending verification',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Button row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _manualFetch,
                                  icon: const Icon(
                                    Icons.cloud_download,
                                    size: 16,
                                  ),
                                  label: const Text('Fetch'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _navigateToTeamsScreen,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Match'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _isLoading || _softMatches.isEmpty
                                      ? null
                                      : _promoteToHardCopy,
                                  icon: const Icon(Icons.verified, size: 16),
                                  label: const Text('Publish All'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGreen,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _cleanHardCopies,
                                  icon: const Icon(
                                    Icons.delete_sweep,
                                    size: 16,
                                  ),
                                  label: const Text('Clean'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _cleanSoftMatches,
                                  icon: const Icon(
                                    Icons.layers_clear,
                                    size: 16,
                                  ),
                                  label: const Text('Clean Soft'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orangeAccent,
                                    side: const BorderSide(
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                                if (_selectedLeagueId ==
                                    'mens-t20-world-cup-2026') ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor:
                                                    AppColors.cardBackground,
                                                title: const Text(
                                                  'DEEP CLEAN ALL T20?',
                                                ),
                                                content: const Text(
                                                  'This will delete matches from EVERY competition using this league and reset all scores. It will also block automatic re-population of these matches unless they are in the future. CRITICAL ACTION.',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'CLEAN EVERYTHING',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              setState(() => _isLoading = true);
                                              try {
                                                final fs =
                                                    Provider.of<
                                                      FirestoreService
                                                    >(context, listen: false);

                                                await fs.cleanHardCopy(
                                                  _selectedLeagueId!,
                                                );
                                                await fs.cleanSoftCopy(
                                                  _selectedLeagueId!,
                                                );

                                                final db =
                                                    FirebaseFirestore.instance;
                                                final compsSnap = await db
                                                    .collection('competitions')
                                                    .where(
                                                      'leagueId',
                                                      isEqualTo:
                                                          _selectedLeagueId,
                                                    )
                                                    .get();

                                                for (var doc
                                                    in compsSnap.docs) {
                                                  await fs
                                                      .deleteCompetitionMatches(
                                                        doc.id,
                                                      );
                                                }

                                                if (mounted) {
                                                  setState(
                                                    () => _isLoading = false,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        '✅ Deep cleanup complete!',
                                                      ),
                                                    ),
                                                  );
                                                  await _loadSoftMatches(
                                                    _selectedLeagueId!,
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  setState(
                                                    () => _isLoading = false,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Deep Clean ALL'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),

                    // Match List
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: LoadingSpinner(
                                color: AppColors.accentGreen,
                              ),
                            )
                          : _softMatches.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No soft matches found.\nRun the fetch script first.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _navigateToTeamsScreen,
                                    icon: const Icon(Icons.group_add),
                                    label: const Text('Add Teams & Matches'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentGreen,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                              itemCount: _softMatches.length,
                              itemBuilder: (context, index) {
                                final match = _softMatches[index];
                                final hasScore =
                                    match.actualScore != null &&
                                    (match.actualScore!['team1'] != null ||
                                        match.actualScore!['team2'] != null ||
                                        match.actualScore!['winnerId'] !=
                                            null ||
                                        match.actualScore!['marginValue'] !=
                                            null);

                                return Card(
                                  color: AppColors.cardBackground,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: match.isVerified
                                          ? AppColors.accentGreen.withOpacity(
                                              0.3,
                                            )
                                          : Colors.white10,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            _showEditSoftMatchDialog(match),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            12,
                                            12,
                                            8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Status + Date
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          match.status ==
                                                              'upcoming'
                                                          ? Colors.blue
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                          : AppColors
                                                                .accentGreen
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      match.status
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color:
                                                            match.status ==
                                                                'upcoming'
                                                            ? Colors.blue[300]
                                                            : AppColors
                                                                  .accentGreen,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                      'EEE, MMM d | h:mm a',
                                                    ).format(
                                                      match.scheduledTime,
                                                    ),
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Teams and Score
                                              _buildMatchContent(match),
                                              const SizedBox(height: 8),
                                              // Metadata row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    (match.round ?? '').trim(),
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  if (match.isVerified)
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.check_circle,
                                                          color: AppColors
                                                              .accentGreen,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const Text(
                                                          'VERIFIED',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .accentGreen,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Action Bar
                                      const Divider(
                                        color: Colors.white10,
                                        height: 1,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'M#${match.matchNumber ?? index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white24,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              onPressed: () =>
                                                  _deleteSoftMatch(match),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppColors.error,
                                                size: 18,
                                              ),
                                              tooltip: 'Delete Draft',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _showEditSoftMatchDialog(
                                                    match,
                                                  ),
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 16,
                                              ),
                                              label: const Text('Edit'),
                                              style: TextButton.styleFrom(
                                                minimumSize: Size.zero,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                            ),
                                            if (!match.isVerified && hasScore)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _verifyAndPushSingle(
                                                        match,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.verified,
                                                    size: 14,
                                                  ),
                                                  label: const Text('Verify'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.accentGreen,
                                                    foregroundColor:
                                                        Colors.black,
                                                    minimumSize: Size.zero,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
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
        ],
      ),
    );
  }

  Widget _buildMatchContent(MatchModel match) {
    final orderedTeams = _getTeamsInBattingOrder(match);
    final hasScore =
        match.actualScore != null &&
        (match.actualScore!['team1'] != null ||
            match.actualScore!['team2'] != null);

    return Row(
      children: [
        // Left Team
        Expanded(
          child: Column(
            children: [
              Text(
                orderedTeams['leftTeamName']!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Score Middle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: hasScore
              ? _buildMatchScoreDisplay(match)
              : const Text(
                  'vs',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),

        // Right Team
        Expanded(
          child: Column(
            children: [
              Text(
                orderedTeams['rightTeamName']!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSportForLeague(String leagueId, [String? name]) {
    // 🔥 First priority: Check the explicit sports map
    if (_leagueSports.containsKey(leagueId)) {
      return _leagueSports[leagueId]!;
    }

    final String leagueName =
        name ?? _leagues[leagueId] ?? _baseLeagues[leagueId] ?? '';
    final lowerId = leagueId.toLowerCase();
    final lowerName = leagueName.toLowerCase();
    final combined = '$lowerId $lowerName';

    // ✅ Specific short IDs
    if (lowerId == 'mc') return AppConstants.sportCricket;
    if (lowerId == 'mf') return AppConstants.sportFootball;

    // 🏆 Tier 1: Absolute Cricket Keywords (Always Cricket)
    if (combined.contains('cricket') ||
        combined.contains('cric') ||
        combined.contains('crik') ||
        combined.contains('ipl') ||
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

    return AppConstants.sportFootball;
  }

  Widget _buildMatchScoreDisplay(MatchModel match) {
    final sport = _getSportForLeague(_selectedLeagueId ?? '');

    if (sport == AppConstants.sportCricket) {
      final winnerId = match.actualScore?['winnerId']?.toString() ?? '';

      // Robust score extraction: handle both 'team1/2' and 't1Runs/t2Runs'
      final t1Score =
          match.actualScore?['t1Runs'] ?? match.actualScore?['team1'];
      final t2Score =
          match.actualScore?['t2Runs'] ?? match.actualScore?['team2'];

      int t1Runs = int.tryParse(t1Score?.toString() ?? '0') ?? 0;
      int t2Runs = int.tryParse(t2Score?.toString() ?? '0') ?? 0;

      if (winnerId == 'tied' || winnerId == 'no_result') {
        return Text(
          winnerId.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        final String marginType =
            match.actualScore?['marginType']?.toString() ?? '';
        final int marginVal =
            int.tryParse(
              match.actualScore?['marginValue']?.toString() ?? '0',
            ) ??
            0;

        // Infer missing score if won by runs (Matching MatchesListScreen logic)
        if (marginType == 'runs' && marginVal > 0) {
          if (t1Runs > 0 && t2Runs == 0 && winnerId == match.team1Id) {
            t2Runs = t1Runs - marginVal;
          } else if (t2Runs > 0 && t1Runs == 0 && winnerId == match.team2Id) {
            t1Runs = t2Runs - marginVal;
          }
        }

        final battingFirstId = match.actualScore?['battingFirstId'];
        final t1Wickets = match.actualScore?['t1Wickets'] ?? 0;
        final t2Wickets = match.actualScore?['t2Wickets'] ?? 0;

        String scoreText;
        if (battingFirstId == null || battingFirstId == match.team1Id) {
          scoreText = '$t1Runs/$t1Wickets - $t2Runs/$t2Wickets';
        } else {
          scoreText = '$t2Runs/$t2Wickets - $t1Runs/$t1Wickets';
        }

        return Column(
          children: [
            Text(
              scoreText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (match.actualScore?['marginValue'] != null &&
                match.actualScore!['marginValue'].toString().isNotEmpty &&
                match.actualScore!['marginValue'].toString() != '0')
              Text(
                'by ${match.actualScore!['marginValue']} ${match.actualScore!['marginType'] ?? ''}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        );
      }
    } else {
      return Text(
        '${match.actualScore!['team1'] ?? 0} - ${match.actualScore!['team2'] ?? 0}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      );
    }
  }

  Map<String, String> _getTeamsInBattingOrder(MatchModel match) {
    final sport = _getSportForLeague(_selectedLeagueId ?? '');

    // Only swap for Cricket based on batting order.
    // Football/Other should stay in the order they were created (T1 vs T2)
    if (sport != AppConstants.sportCricket) {
      return {
        'leftTeamName': match.team1Name,
        'rightTeamName': match.team2Name,
      };
    }

    final battingFirstId = match.actualScore?['battingFirstId'];

    if (battingFirstId == null || battingFirstId == match.team1Id) {
      return {
        'leftTeamName': match.team1Name,
        'rightTeamName': match.team2Name,
      };
    } else {
      return {
        'leftTeamName': match.team2Name,
        'rightTeamName': match.team1Name,
      };
    }
  }
}
