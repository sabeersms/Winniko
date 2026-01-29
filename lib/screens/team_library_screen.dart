import 'dart:io' show File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../models/team_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/team_logo.dart';
import '../widgets/loading_spinner.dart';

class TeamLibraryScreen extends StatefulWidget {
  final String organizerId;
  final bool isSelectionMode;

  const TeamLibraryScreen({
    super.key,
    required this.organizerId,
    this.isSelectionMode = false,
  });

  @override
  State<TeamLibraryScreen> createState() => _TeamLibraryScreenState();
}

class _TeamLibraryScreenState extends State<TeamLibraryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _selectedTeamIds = {};
  List<TeamModel> _allTeams = [];

  void _showAddEditTeamDialog(BuildContext context, {TeamModel? team}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEditTeamDialog(
        organizerId: widget.organizerId,
        team: team,
        imagePicker: _imagePicker,
      ),
    );
  }

  Future<void> _deleteTeam(TeamModel team) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Team?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${team.name}" from your library?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.deleteGlobalTeam(widget.organizerId, team.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team deleted from library'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteTournament(String tournamentName, int teamCount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Tournament Group?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "$tournamentName" and all its $teamCount teams from your library? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.deleteGlobalTournament(
        widget.organizerId,
        tournamentName,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament "$tournamentName" and its teams deleted'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode
              ? 'Select Teams (${_selectedTeamIds.length})'
              : 'Team Library',
        ),
        backgroundColor: AppColors.backgroundDark,
        actions: [
          if (widget.isSelectionMode && _selectedTeamIds.isNotEmpty)
            TextButton(
              onPressed: () {
                final selected = _allTeams
                    .where((t) => _selectedTeamIds.contains(t.id))
                    .toList();
                Navigator.pop(context, selected);
              },
              child: const Text(
                'IMPORT',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddEditTeamDialog(context),
              backgroundColor: AppColors.accentGreen,
              icon: const Icon(Icons.add, color: AppColors.backgroundDark),
              label: const Text(
                'Add Team',
                style: TextStyle(
                  color: AppColors.backgroundDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: StreamBuilder<List<TeamModel>>(
        stream: firestore.getGlobalTeams(widget.organizerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingSpinner());
          }

          _allTeams = snapshot.data ?? [];
          final teams = _allTeams;

          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.library_books,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Library is empty',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add reusable teams here',
                    style: TextStyle(color: Colors.white24),
                  ),
                  if (widget.isSelectionMode) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                      ),
                      onPressed: () => _showAddEditTeamDialog(context),
                      child: const Text(
                        'Create New Team',
                        style: TextStyle(color: AppColors.accentGreen),
                      ),
                    ),
                  ],
                ],
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
            padding: const EdgeInsets.all(16),
            itemCount: sortedTournamentNames.length + 1,
            itemBuilder: (context, index) {
              if (index == sortedTournamentNames.length) {
                return const SizedBox(height: 80);
              }

              final tournamentName = sortedTournamentNames[index];
              final tournamentTeams = groupedTeams[tournamentName]!;

              return Card(
                color: AppColors.cardBackground,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  collapsedIconColor: AppColors.accentGreen,
                  iconColor: AppColors.accentGreen,
                  title: Text(
                    tournamentName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    '${tournamentTeams.length} Teams',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: widget.isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.delete_sweep,
                            color: AppColors.error,
                          ),
                          onPressed: () => _deleteTournament(
                            tournamentName,
                            tournamentTeams.length,
                          ),
                        ),
                  children: tournamentTeams.map((team) {
                    final isSelected = _selectedTeamIds.contains(team.id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: TeamLogo(
                        url: team.logoUrl,
                        teamName: team.shortName,
                        size: 40,
                      ),
                      title: Text(
                        team.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        team.shortName,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: widget.isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              activeColor: AppColors.accentGreen,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedTeamIds.add(team.id);
                                  } else {
                                    _selectedTeamIds.remove(team.id);
                                  }
                                });
                              },
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppColors.accentGreen,
                                    size: 20,
                                  ),
                                  onPressed: () => _showAddEditTeamDialog(
                                    context,
                                    team: team,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteTeam(team),
                                ),
                              ],
                            ),
                      onTap: widget.isSelectionMode
                          ? () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTeamIds.remove(team.id);
                                } else {
                                  _selectedTeamIds.add(team.id);
                                }
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddEditTeamDialog extends StatefulWidget {
  final String organizerId;
  final TeamModel? team;
  final ImagePicker imagePicker;

  const _AddEditTeamDialog({
    required this.organizerId,
    this.team,
    required this.imagePicker,
  });

  @override
  State<_AddEditTeamDialog> createState() => _AddEditTeamDialogState();
}

class _AddEditTeamDialogState extends State<_AddEditTeamDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shortNameController = TextEditingController();
  XFile? _logoPreview;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.team != null) {
      _nameController.text = widget.team!.name;
      _shortNameController.text = widget.team!.shortName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final XFile? image = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
    );
    if (image != null) {
      setState(() => _logoPreview = image);
    }
  }

  Future<void> _saveTeam() async {
    final name = _nameController.text.trim();
    final code = _shortNameController.text.trim().toUpperCase();

    if (name.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final storage = Provider.of<StorageService>(context, listen: false);

      String teamId = widget.team?.id ?? const Uuid().v4();
      String? logoUrl = widget.team?.logoUrl;

      // Upload new logo if selected
      if (_logoPreview != null) {
        logoUrl = await storage.uploadGlobalTeamLogo(
          _logoPreview!,
          widget.organizerId,
          teamId,
        );
      }

      final team = TeamModel(
        id: teamId,
        name: name,
        shortName: code,
        logoUrl: logoUrl,
        competitionId: 'library', // Placeholder for global items
        createdAt: widget.team?.createdAt ?? DateTime.now(),
      );

      if (widget.team == null) {
        await firestore.createGlobalTeam(widget.organizerId, team);
      } else {
        await firestore.updateGlobalTeam(widget.organizerId, team);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.team == null ? 'Add Team to Library' : 'Edit Team',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textSecondary),
                    ),
                    child: _logoPreview != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? CachedNetworkImage(
                                    imageUrl: _logoPreview!.path,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: LoadingSpinner(size: 20),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  )
                                : Image.file(
                                    File(_logoPreview!.path),
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : (widget.team?.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.team!.logoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: LoadingSpinner(size: 20),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                )
                              : const Icon(
                                  Icons.add_a_photo,
                                  color: AppColors.textSecondary,
                                )),
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
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _shortNameController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        maxLength: 3,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Code (e.g. ARS)',
                          counterText: "",
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.backgroundDark,
                            ),
                          ),
                        )
                      : Text(
                          widget.team == null ? 'Add' : 'Save',
                          style: const TextStyle(
                            color: AppColors.backgroundDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
