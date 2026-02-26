import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/cric_api_service.dart';
import '../../constants/app_constants.dart';
import '../../models/match_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../services/sports_api_service.dart';
import '../../services/tournament_data_service.dart';
import '../../models/team_model.dart';
import '../../models/official_tournament_model.dart';

class TournamentDiscoveryDialog extends StatefulWidget {
  const TournamentDiscoveryDialog({super.key});

  @override
  State<TournamentDiscoveryDialog> createState() =>
      _TournamentDiscoveryDialogState();
}

class _TournamentDiscoveryDialogState extends State<TournamentDiscoveryDialog> {
  final CricApiService _cricService = CricApiService();

  bool _loading = true;
  List<dynamic> _seriesList = []; // Can be Map or OfficialTournamentModel
  final Set<String> _importingIds = {};
  String _selectedSport = AppConstants.sportCricket;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSeries();
  }

  Future<void> _fetchSeries() async {
    setState(() {
      _loading = true;
      _seriesList = [];
    });

    try {
      final query = _searchController.text.trim().toLowerCase();

      if (_selectedSport == AppConstants.sportCricket) {
        final list = await _cricService.getSeriesList();
        final relevant = list.where((s) {
          final name = (s['name'] as String).toLowerCase();
          if (query.isNotEmpty) {
            return name.contains(query);
          }
          return name.contains('cup') ||
              name.contains('league') ||
              name.contains('trophy') ||
              name.contains('series') ||
              name.contains('tour');
        }).toList();

        relevant.sort((a, b) {
          final d1 = DateTime.tryParse(a['startDate'] ?? '') ?? DateTime(2000);
          final d2 = DateTime.tryParse(b['startDate'] ?? '') ?? DateTime(2000);
          return d2.compareTo(d1);
        });

        if (mounted) setState(() => _seriesList = relevant);
      } else {
        // Football Discovery - search both our database and the global source index
        final localList = await SportsApiService.searchTournaments(query);
        final externalList =
            await SportsApiService.discoverNewTournamentsExternal(query);

        // Merge and deduplicate by ID
        final seenIds = localList.map((e) => e.id).toSet();
        final merged = [...localList];
        for (var t in externalList) {
          if (!seenIds.contains(t.id)) {
            merged.add(t);
            seenIds.add(t.id);
          }
        }

        if (mounted) setState(() => _seriesList = merged);
      }
    } catch (e) {
      debugPrint('Error fetching series: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importSeries(dynamic series) async {
    // Determine ID and Name based on type
    String seriesId;
    String seriesName;

    if (series is Map) {
      seriesId = series['id'];
      seriesName = series['name'];
    } else if (series is OfficialTournamentModel) {
      seriesId = series.id;
      seriesName = series.name;
    } else {
      return;
    }

    setState(() => _importingIds.add(seriesId));

    try {
      final uuid = const Uuid();
      final batch = FirebaseFirestore.instance.batch();
      // Use seriesId as basis for ID to stay consistent with API lookups
      final slug = seriesId.toLowerCase().trim();

      // Register tournament metadata for discovery/search
      await FirebaseFirestore.instance
          .collection('discovered_tournaments')
          .doc(slug)
          .set({
            'id': slug,
            'name': seriesName,
            'country': _selectedSport == AppConstants.sportFootball
                ? 'Global'
                : 'International',
            'sport': _selectedSport,
            'logoUrl': series is OfficialTournamentModel
                ? series.logoUrl
                : null,
            'source': _selectedSport == AppConstants.sportFootball
                ? 'fixturedownload'
                : 'cricapi',
            'externalId':
                seriesId, // Store original CricAPI or FixtureDownload ID
            'discoveredAt': FieldValue.serverTimestamp(),
            'hasFixtures': true,
            'status': 'active',
          }, SetOptions(merge: true));

      final collectionRef = FirebaseFirestore.instance
          .collection('official_leagues')
          .doc(slug)
          .collection('soft_matches');

      int count = 0;

      if (_selectedSport == AppConstants.sportCricket) {
        // --- EXISTING CRICKET IMPORT LOGIC ---
        final matchesData = await _cricService.getSeriesMatches(seriesId);
        if (matchesData.isEmpty) {
          throw Exception('No matches found for this series.');
        }

        final Set<String> uniqueTeams = {};
        int matchNum = 1;

        for (var m in matchesData) {
          final name = m['name'] as String? ?? '';
          final parts = name.split('vs');
          String t1 = 'Team 1';
          String t2 = 'Team 2';

          if (m['t1'] != null && m['t2'] != null) {
            t1 = m['t1'].toString();
            t2 = m['t2'].toString();
          } else if (parts.length > 1) {
            t1 = parts[0].replaceAll(RegExp(r'\[.*?\]'), '').trim();
            t2 = parts[1].replaceAll(RegExp(r'\[.*?\]'), '').trim();
          } else if (m['teams'] != null) {
            final tList = m['teams'] as List;
            if (tList.length >= 2) {
              t1 = tList[0].toString();
              t2 = tList[1].toString();
            }
          }

          // Clean up common artifacts like " (W)" or team codes in brackets
          t1 = t1.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
          t2 = t2.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();

          if (!uniqueTeams.contains(t1)) uniqueTeams.add(t1);
          if (!uniqueTeams.contains(t2)) uniqueTeams.add(t2);

          DateTime scheduledTime = DateTime.now().add(const Duration(days: 30));
          if (m['dateTimeGMT'] != null) {
            scheduledTime = DateTime.parse(m['dateTimeGMT']).toLocal();
          } else if (m['date'] != null) {
            scheduledTime = DateTime.now();
          }

          final matchDocId = 'match_$matchNum';
          final match = MatchModel(
            id: uuid.v4(),
            competitionId: 'official_$slug',
            team1Id: 'canonical_${_makeSlug(t1)}',
            team1Name: t1,
            team1LogoUrl: null,
            team2Id: 'canonical_${_makeSlug(t2)}',
            team2Name: t2,
            team2LogoUrl: null,
            scheduledTime: scheduledTime,
            status: 'upcoming',
            matchNumber: matchNum,
            location: m['venue'] ?? 'Stadium',
          );

          final data = match.toMap();
          data['homeTeamName'] = t1;
          data['awayTeamName'] = t2;
          data['homeTeamCode'] = _makeSlug(
            t1,
          ).toUpperCase().substring(0, t1.length.clamp(0, 3));
          data['awayTeamCode'] = _makeSlug(
            t2,
          ).toUpperCase().substring(0, t2.length.clamp(0, 3));

          batch.set(collectionRef.doc(matchDocId), data);
          matchNum++;
        }
        count = matchNum - 1;
      } else {
        // --- FOOTBALL IMPORT LOGIC ---
        // 1. Fetch Teams
        final teamsList = await SportsApiService.importTeams(seriesId);
        if (teamsList.isEmpty) throw Exception('No teams found.');

        // 2. Create Temp TeamModels for mapping
        final List<TeamModel> tempTeams = teamsList
            .map(
              (t) => TeamModel(
                id: 'temp_${t['code']}', // Won't be saved, just for mapping
                name: t['name']!,
                shortName: t['code']!,
                logoUrl: t['logoUrl'],
                competitionId: 'official_$slug',
                createdAt: DateTime.now(),
              ),
            )
            .toList();

        // 3. Simple map to look up logo later
        final logoMap = {for (var t in tempTeams) t.name: t.logoUrl};

        // 4. Fetch Fixtures
        final fixtures = await TournamentDataService.getLatestScores(
          'official_$slug',
          seriesId,
          tempTeams,
          isMaster: true, // Force external API fetch for discovery
        );

        if (fixtures.isEmpty) {
          debugPrint(
            'No fixtures found for $seriesId, creating tournament only.',
          );
        }

        // 5. Create Batch
        int matchNum = 1;
        for (var match in fixtures) {
          final matchDocId = 'match_$matchNum';

          // Ensure IDs are consistent for "official" use (though UUIDs are fine)
          // We need to attach team names/codes for the Firestore structure Sync expects
          final data = match.toMap();

          // Extract code from temp team list if possible, or generate on fly
          // The fixtures from getTournamentFixtures should have correct names
          data['homeTeamName'] = match.team1Name;
          data['awayTeamName'] = match.team2Name;

          // Reverse lookup codes from tempTeams logic?
          // Since we passed tempTeams to getTournamentFixtures, it used them.
          // But getTournamentFixtures assigns random IDs if we passed temp IDs.
          // We want canonical IDs for official leagues ideally, but UUIDs are okay
          // as long as teams map correctly by name next time.
          // Actually, for official leagues, we store names/codes in the match doc
          // so Sync service can re-map them to any private competition.

          // Find code
          final t1 = tempTeams.firstWhere(
            (t) => t.name == match.team1Name,
            orElse: () => tempTeams.first,
          );
          final t2 = tempTeams.firstWhere(
            (t) => t.name == match.team2Name,
            orElse: () => tempTeams.first,
          );

          data['homeTeamCode'] = t1.shortName;
          data['awayTeamCode'] = t2.shortName;

          // Add logos (MatchModel has them, but ensure they are saved)
          data['team1LogoUrl'] = logoMap[match.team1Name];
          data['team2LogoUrl'] = logoMap[match.team2Name];

          batch.set(collectionRef.doc(matchDocId), data);
          matchNum++;
        }
        count = matchNum - 1;
      }

      await batch.commit();

      // Automatically pin the imported tournament so it appears in the list immediately
      try {
        final prefs = await SharedPreferences.getInstance();
        final added = prefs.getStringList('verification_added_leagues') ?? [];
        final entry = '$slug||$seriesName';
        if (!added.contains(entry)) {
          added.add(entry);
          await prefs.setStringList('verification_added_leagues', added);
        }
      } catch (e) {
        debugPrint('Auto-pin failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "$seriesName" with $count matches!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      debugPrint('Import Error: $e');
    } finally {
      if (mounted) setState(() => _importingIds.remove(seriesId));
    }
  }

  String _makeSlug(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text(
        'Discover Tournaments',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search new tournaments...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.accentGreen),
                    onPressed: _fetchSeries,
                  ),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _fetchSeries(),
              ),
            ),

            // Sport Selector
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildSportTab(
                    AppConstants.sportCricket,
                    Icons.sports_cricket,
                  ),
                  _buildSportTab(
                    AppConstants.sportFootball,
                    Icons.sports_soccer,
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGreen,
                      ),
                    )
                  : _seriesList.isEmpty
                  ? const Center(
                      child: Text(
                        "No tournaments found.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _seriesList.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(color: Colors.white12),
                      itemBuilder: (ctx, i) {
                        final series = _seriesList[i];
                        String name = '';
                        String start = '';
                        String id = '';

                        if (series is Map) {
                          name = series['name'];
                          start = series['startDate'] ?? 'Unknown Date';
                          id = series['id'];
                        } else if (series is OfficialTournamentModel) {
                          name = series.name;
                          start = series.country;
                          id = series.id;
                        }

                        final isImporting = _importingIds.contains(id);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _selectedSport == AppConstants.sportFootball
                                ? Icons.sports_soccer
                                : Icons.sports_cricket,
                            color: AppColors.accentGreen,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _selectedSport == AppConstants.sportFootball
                                ? start
                                : 'Starts: $start',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: isImporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: AppColors.accentGreen,
                                    side: const BorderSide(
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                  onPressed: () => _importSeries(series),
                                  child: const Text('Import'),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSportTab(String sport, IconData icon) {
    final isSelected = _selectedSport == sport;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSport = sport;
          });
          _fetchSeries();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGreen.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.accentGreen)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.accentGreen : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                sport,
                style: TextStyle(
                  color: isSelected ? AppColors.accentGreen : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
