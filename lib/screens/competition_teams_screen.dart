import 'dart:io' show File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/team_model.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/fixture_generator.dart';

import '../services/teams_data_service.dart';
import '../widgets/team_logo.dart';
import '../widgets/loading_spinner.dart';
import 'match_create_screen.dart';
import 'dialogs/fixture_configuration_dialog.dart';
import 'generated_fixtures_preview_screen.dart';

class CompetitionTeamsScreen extends StatefulWidget {
  final CompetitionModel competition;

  const CompetitionTeamsScreen({super.key, required this.competition});

  @override
  State<CompetitionTeamsScreen> createState() => _CompetitionTeamsScreenState();
}

class _CompetitionTeamsScreenState extends State<CompetitionTeamsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shortNameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _logoImage;
  bool _isAdding = false;
  String? _errorMessage;

  // State for Selection Modes
  int _selectedTab = 0; // 0: Custom, 1: Library, 2: National, 3: Clubs
  String? _selectedLeagueId;
  String? _selectedGroup; // Selected group for assignment
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  // Reuse key logic for custom team
  Future<void> _addCustomTeam() async {
    await _createTeam(
      _nameController.text.trim(),
      _shortNameController.text.trim().toUpperCase(),
      logoFile: _logoImage,
    );
    // Clear form
    _nameController.clear();
    _shortNameController.clear();
    setState(() => _logoImage = null);
  }

  // Logic for standard team (National/Club)
  Future<void> _addStandardTeam(
    String name,
    String code, {
    String? logoUrl,
  }) async {
    await _createTeam(name, code, logoUrlStr: logoUrl);
  }

  Future<void> _createTeam(
    String name,
    String code, {
    XFile? logoFile,
    String? logoUrlStr,
  }) async {
    if (name.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Invalid team details');
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final storage = Provider.of<StorageService>(context, listen: false);
      const uuid = Uuid();
      final teamId = uuid.v4();

      String? finalLogoUrl = logoUrlStr;

      // Upload file if provided
      if (logoFile != null) {
        finalLogoUrl = await storage.uploadCompetitionTeamLogo(
          logoFile,
          widget.competition.id,
          teamId,
        );
      }

      final team = TeamModel(
        id: teamId,
        name: name,
        shortName: code,
        logoUrl: finalLogoUrl,
        competitionId: widget.competition.id,
        createdAt: DateTime.now(),
        group: _selectedGroup,
        competitionName: widget.competition.name, // Track origin tournament
      );

      await firestore.createTeam(team);

      // Auto-save to User Library
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final userId = authService.currentUserId;
        if (userId != null) {
          // Create a copy for the library with 'library' as competitionId
          final libraryTeam = team.copyWith(competitionId: 'library');
          await firestore.createGlobalTeam(userId, libraryTeam);
        }
      } catch (e) {
        debugPrint('Failed to auto-save team to library: $e');
        // Non-blocking error, we don't show it to user
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team added successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _pickLogo() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
    );
    if (image != null) {
      setState(() => _logoImage = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      resizeToAvoidBottomInset: false, // Prevent fab moving up
      appBar: AppBar(
        title: const Text('Add Teams'),
        actions: [
          TextButton(
            onPressed: _onFinishPressed,
            child: const Text('NEXT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector Tabs
          Container(
            color: AppColors.cardBackground,
            child: Row(
              children: [
                _buildTabItem(0, 'Custom', Icons.edit),
                _buildTabItem(1, 'Library', Icons.library_books),
                _buildTabItem(2, 'National', Icons.flag),
                _buildTabItem(3, 'Clubs', Icons.shield),
              ],
            ),
          ),

          // Group Selector (If Groups Enabled)
          if (widget.competition.groups.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.cardBackground,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedGroup,
                hint: const Text('Select Group to Assign'),
                isDense: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                ),
                dropdownColor: AppColors.cardBackground,
                style: const TextStyle(color: AppColors.textPrimary),
                items: widget.competition.groups.map((group) {
                  return DropdownMenuItem(value: group, child: Text(group));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedGroup = val);
                },
              ),
            ),

          // Input Area
          Container(
            height: 300, // Fixed height for input area
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(bottom: BorderSide(color: AppColors.dividerColor)),
            ),
            child: _buildInputArea(),
          ),

          // Team List Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.backgroundDark,
            width: double.infinity,
            child: const Text(
              'Participating Teams',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // Team List
          Expanded(
            child: StreamBuilder<List<TeamModel>>(
              stream: firestore.getTeams(widget.competition.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: LoadingSpinner());
                }

                final teams = snapshot.data!;
                if (teams.isEmpty) {
                  return const Center(
                    child: Text(
                      'No teams added yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                // Sort teams by group then name
                // Sort teams by group then name
                teams.sort((a, b) {
                  if (widget.competition.groups.isNotEmpty) {
                    final groupA = a.group;
                    final groupB = b.group;

                    final indexA = groupA == null
                        ? 999
                        : widget.competition.groups.indexOf(groupA);
                    final indexB = groupB == null
                        ? 999
                        : widget.competition.groups.indexOf(groupB);

                    // Prioritize known groups
                    final validA = indexA != -1 && indexA != 999;
                    final validB = indexB != -1 && indexB != 999;

                    if (validA && validB) {
                      final comp = indexA.compareTo(indexB);
                      if (comp != 0) return comp;
                    } else if (validA) {
                      return -1; // A comes first
                    } else if (validB) {
                      return 1; // B comes first
                    } else {
                      // Both invalid or unassigned
                      // Sort unassigned ('Z') vs unknown strings
                      final strA = groupA ?? 'Z';
                      final strB = groupB ?? 'Z';
                      final comp = strA.compareTo(strB);
                      if (comp != 0) return comp;
                    }
                  }
                  return a.name.compareTo(b.name);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final showGroupHeader =
                        index == 0 ||
                        (widget.competition.groups.isNotEmpty &&
                            team.group != teams[index - 1].group);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showGroupHeader &&
                            widget.competition.groups.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 16.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              team.group ?? 'Unassigned',
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            tileColor: AppColors.cardBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () => _showEditTeamDialog(context, team),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TeamLogo(
                                  url: team.logoUrl,
                                  teamName: team.shortName,
                                  size: 40,
                                ),
                              ],
                            ),
                            title: Text(
                              team.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              team.shortName,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () => firestore.deleteTeam(
                                    widget.competition.id,
                                    team.id,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedTab = index;
          _errorMessage = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.accentGreen : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (_selectedTab == 0) {
      return _buildCustomForm();
    } else if (_selectedTab == 1) {
      return _buildLibraryList();
    } else if (_selectedTab == 2) {
      return _buildNationalList();
    } else {
      return _buildClubList();
    }
  }

  Widget _buildLibraryList() {
    // Show library teams with "Add" button
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    return StreamBuilder<List<List<TeamModel>>>(
      stream: CombineLatestStream.list([
        firestore.getGlobalTeams(widget.competition.organizerId),
        firestore.getTeams(widget.competition.id),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LoadingSpinner());
        }

        final globalTeams = snapshot.data![0];
        final currentTeams = snapshot.data![1];

        // Filter out teams that are already added (by name check as IDs differ)
        final teams = globalTeams.where((g) {
          return !currentTeams.any(
            (c) => c.name.toLowerCase() == g.name.toLowerCase(),
          );
        }).toList();

        if (teams.isEmpty) {
          return const Center(
            child: Text(
              'No new teams in library. Add custom teams or specific club/national teams.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // Group teams by competitionName
        final Map<String, List<TeamModel>> groupedTeams = {};
        for (var team in teams) {
          final name = team.competitionName ?? 'Other';
          if (!groupedTeams.containsKey(name)) {
            groupedTeams[name] = [];
          }
          groupedTeams[name]!.add(team);
        }

        final sortedTournamentNames = groupedTeams.keys.toList()..sort();

        return ListView.builder(
          itemCount: sortedTournamentNames.length,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemBuilder: (context, index) {
            final tournamentName = sortedTournamentNames[index];
            final tournamentTeams = groupedTeams[tournamentName]!;

            return Card(
              color: AppColors.cardBackground,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                collapsedIconColor: AppColors.accentGreen,
                iconColor: AppColors.accentGreen,
                title: Text(
                  tournamentName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${tournamentTeams.length} Teams available',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                children: tournamentTeams.map((team) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: TeamLogo(
                      url: team.logoUrl,
                      teamName: team.shortName,
                      size: 32,
                    ),
                    title: Text(
                      team.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final firestore = Provider.of<FirestoreService>(
                          context,
                          listen: false,
                        );
                        try {
                          // Copy single team with selected group
                          await firestore.copyGlobalTeamsToCompetition(
                            widget.competition.id,
                            [team],
                            group: _selectedGroup,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Team added!'),
                                duration: Duration(milliseconds: 800),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        minimumSize: const Size(60, 32),
                        backgroundColor: AppColors.accentGreen.withAlpha(51),
                      ),
                      child: const Text('Add', style: TextStyle(fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Team',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGreenLight),
                  ),
                  child: _logoImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? CachedNetworkImage(
                                  imageUrl: _logoImage!.path,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: LoadingSpinner(size: 20),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                )
                              : Image.file(
                                  File(_logoImage!.path),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : const Icon(
                          Icons.add_a_photo,
                          color: AppColors.textSecondary,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Team Name',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _shortNameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        hintText: 'Code (e.g. MCI)',
                        counterText: "",
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAdding ? null : _addCustomTeam,
              child: _isAdding
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: LoadingSpinner(
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Text('Create Team'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalList() {
    // Import service
    final teams = TeamsDataService.getNationalTeams().where((t) {
      if (_searchQuery.isEmpty) return true;
      return t['name']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search Country...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.inputBackground,
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: teams.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final team = teams[index];
              final flagUrl = TeamsDataService.getFlagUrl(team['flag']!);

              return ListTile(
                leading: SizedBox(
                  width: 32,
                  height: 24,
                  child: CachedNetworkImage(
                    imageUrl: flagUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.cardBackground),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.flag, color: Colors.white),
                  ),
                ),
                title: Text(
                  team['name']!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _addStandardTeam(
                    team['name']!,
                    team['code']!,
                    logoUrl: flagUrl,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    minimumSize: const Size(60, 32),
                    backgroundColor: AppColors.accentGreen.withAlpha(51),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClubList() {
    final leagues = TeamsDataService.getLeagues();
    final teams = _selectedLeagueId == null
        ? <Map<String, String>>[]
        : TeamsDataService.getClubTeams(_selectedLeagueId!);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedLeagueId,
            items: leagues
                .map(
                  (l) =>
                      DropdownMenuItem(value: l['id'], child: Text(l['name']!)),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedLeagueId = val),
            decoration: const InputDecoration(
              hintText: 'Select a League',
              filled: true,
              fillColor: AppColors.inputBackground,
              isDense: true,
              border: OutlineInputBorder(),
            ),
            dropdownColor: AppColors.cardBackground,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: _selectedLeagueId == null
              ? const Center(
                  child: Text(
                    'Select a league to see teams',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: teams.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return ListTile(
                      leading: TeamLogo(
                        url: team['logo'],
                        teamName: team['code']!,
                        size: 32,
                      ),
                      title: Text(
                        team['name']!,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        team['code']!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _addStandardTeam(
                          team['name']!,
                          team['code']!,
                          logoUrl: team['logo'],
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          minimumSize: const Size(60, 32),
                          backgroundColor: AppColors.accentGreen.withAlpha(51),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _onFinishPressed() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    // Fetch current teams to check count
    final teams = await firestore.getTeams(widget.competition.id).first;

    if (!mounted) {
      return;
    }

    if (teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 teams to create fixtures'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show Options Dialog
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Generate Fixtures?'),
          backgroundColor: AppColors.cardBackground,
          titleTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context);

                // Open Configuration Dialog
                final config = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => FixtureConfigurationDialog(
                    competition: widget.competition,
                  ),
                );

                if (config != null) {
                  _generateAutoFixtures(teams, config);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Generate',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Configure and create matches automatically',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.dividerColor),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _openManualMatchCreation(teams);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Selection',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pick specific Team vs Team pairings',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.dividerColor),
            SimpleDialogOption(
              onPressed: () async {
                final firestore = Provider.of<FirestoreService>(
                  context,
                  listen: false,
                );
                await firestore.recalculateStandings(widget.competition.id);

                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Skip & Finish',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAutoFixtures(
    List<TeamModel> teams,
    Map<String, dynamic> config,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: LoadingSpinner()),
    );

    try {
      List<MatchModel> matches = [];
      final format = widget.competition.format;
      final startDate = DateTime.now().add(
        const Duration(days: 1),
      ); // Start tomorrow

      if (format == AppConstants.formatLeague) {
        matches = FixtureGenerator.generateLeagueFixtures(
          competitionId: widget.competition.id,
          teams: teams,
          startDate: startDate,
          doubleRoundRobin: config['doubleRoundRobin'] ?? false,
        );
      } else if (format == AppConstants.formatKnockout) {
        if (widget.competition.fixtureType == AppConstants.fixtureTypeFull) {
          matches = FixtureGenerator.generateFullKnockoutFixtures(
            competitionId: widget.competition.id,
            teams: teams,
            startDate: startDate,
            randomSeed: config['randomSeed'] ?? true,
          );
        } else {
          matches = FixtureGenerator.generateKnockoutFixtures(
            competitionId: widget.competition.id,
            teams: teams,
            startDate: startDate,
            randomSeed: config['randomSeed'] ?? true,
          );
        }
      } else if (format == AppConstants.formatGroupsKnockout) {
        matches = FixtureGenerator.generateGroupsKnockoutFixtures(
          competitionId: widget.competition.id,
          teams: teams,
          startDate: startDate,
          numberOfGroups: config['numberOfGroups'] ?? 1,
        );
        // Note: Full fixture generation for Groups+Knockout (including knockout tree placeholders)
        // is more complex and can be added in a future update.
      } else if (format == AppConstants.formatLeagueKnockout) {
        matches = FixtureGenerator.generateLeagueFixtures(
          competitionId: widget.competition.id,
          teams: teams,
          startDate: startDate,
          doubleRoundRobin: config['doubleRoundRobin'] ?? false,
        );
      } else {
        matches = FixtureGenerator.generateLeagueFixtures(
          competitionId: widget.competition.id,
          teams: teams,
          startDate: startDate,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context); // Close loading

      if (matches.isNotEmpty) {
        // Navigate to Preview Screen to review/edit fixtures
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GeneratedFixturesPreviewScreen(
              competition: widget.competition,
              matches: matches,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No fixtures could be generated. Try adding more teams.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _openManualMatchCreation(List<TeamModel> teams) async {
    final bool? success = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchCreateScreen(
          competitionId: widget.competition.id,
          teams: teams,
        ),
      ),
    );

    if (success == true && mounted) {
      // Ask if they want to add another
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Match Added',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Do you want to add another match?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                'No, Finish',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openManualMatchCreation(teams);
              },
              child: const Text(
                'Yes, Add Another',
                style: TextStyle(color: AppColors.accentGreen),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showEditTeamDialog(BuildContext context, TeamModel team) async {
    await showDialog(
      context: context,
      builder: (context) =>
          EditTeamDialog(team: team, groups: widget.competition.groups),
    );
  }
}

class EditTeamDialog extends StatefulWidget {
  final TeamModel team;
  final List<String> groups;

  const EditTeamDialog({super.key, required this.team, this.groups = const []});

  @override
  State<EditTeamDialog> createState() => _EditTeamDialogState();
}

class _EditTeamDialogState extends State<EditTeamDialog> {
  late TextEditingController _nameController;
  late TextEditingController _shortNameController;
  String? _selectedGroup;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team.name);
    _shortNameController = TextEditingController(text: widget.team.shortName);
    _selectedGroup = widget.team.group;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _shortNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      final updatedTeam = TeamModel(
        id: widget.team.id,
        name: _nameController.text.trim(),
        shortName: _shortNameController.text.trim().toUpperCase(),
        logoUrl: widget.team.logoUrl,
        competitionId: widget.team.competitionId,
        createdAt: widget.team.createdAt,
        group: _selectedGroup,
      );

      debugPrint(
        'Saving team: ${updatedTeam.name}, Group: ${updatedTeam.group}',
      );

      await firestore.updateTeam(updatedTeam);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text(
        'Edit Team',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Team Name',
              hintText: 'e.g. Manchester City',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shortNameController,
            style: const TextStyle(color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            decoration: const InputDecoration(
              labelText: 'Short Code',
              hintText: 'e.g. MCI',
              counterText: "",
            ),
          ),
          if (widget.groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              hint: const Text('Assign Group'),
              decoration: const InputDecoration(
                labelText: 'Group',
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.textPrimary),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ...widget.groups.map(
                  (g) => DropdownMenuItem(value: g, child: Text(g)),
                ),
              ],
              onChanged: (val) => setState(() => _selectedGroup = val),
            ),
          ],
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: LoadingSpinner(size: 20, color: AppColors.accentGreen),
                )
              : const Text(
                  'Save',
                  style: TextStyle(color: AppColors.accentGreen),
                ),
        ),
      ],
    );
  }
}
