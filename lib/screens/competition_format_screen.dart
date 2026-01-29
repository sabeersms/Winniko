import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../services/firestore_service.dart';
import 'competition_teams_screen.dart';
import '../widgets/loading_spinner.dart';

class CompetitionFormatScreen extends StatefulWidget {
  final CompetitionModel competition;

  const CompetitionFormatScreen({super.key, required this.competition});

  @override
  State<CompetitionFormatScreen> createState() =>
      _CompetitionFormatScreenState();
}

class _CompetitionFormatScreenState extends State<CompetitionFormatScreen> {
  String? _selectedFormat;
  int _numberOfGroups = 4; // Default
  String _fixtureType = AppConstants.fixtureTypeRunning;
  bool _isLoading = false;
  List<String> _selectedTieBreakerRules = [];
  int _pointsForWin = 3;
  int _pointsForDraw = 1;
  int _pointsForLoss = 0;

  @override
  void initState() {
    super.initState();
    // Remove default selection
    _selectedFormat = null;
    _fixtureType = widget.competition.fixtureType;
    _selectedTieBreakerRules = List<String>.from(
      widget.competition.tieBreakerRules,
    );
    if (_selectedTieBreakerRules.isEmpty) {
      _selectedTieBreakerRules = ['goal_difference']; // Default for custom
    }
    _pointsForWin = widget.competition.pointsForWin;
    _pointsForDraw = widget.competition.pointsForDraw;
    _pointsForLoss = widget.competition.pointsForLoss;

    if (widget.competition.numberOfGroups > 0) {
      _numberOfGroups = widget.competition.numberOfGroups;
    }
  }

  Future<void> _saveFormatAndContinue() async {
    if (_selectedFormat == null) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      // Create updated model
      final updatedCompetition = widget.competition.copyWith(
        format: _selectedFormat!,
        fixtureType: _fixtureType,
        tieBreakerRules: _selectedTieBreakerRules,
        pointsForWin: _pointsForWin,
        pointsForDraw: _pointsForDraw,
        pointsForLoss: _pointsForLoss,
        numberOfGroups: _selectedFormat == AppConstants.formatGroupsKnockout
            ? _numberOfGroups
            : 0,
        groups: _selectedFormat == AppConstants.formatGroupsKnockout
            ? List.generate(
                _numberOfGroups,
                (i) => 'Group ${String.fromCharCode(65 + i)}',
              )
            : [],
      );

      // Update in Firestore
      await firestoreService.updateCompetition(updatedCompetition);

      if (!mounted) return;

      // Proceed to Teams Screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CompetitionTeamsScreen(competition: updatedCompetition),
        ),
      );

      // Reset loading if returned
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Select Format')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Select a format',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // League
                  _buildFormatCard(
                    title: AppConstants.formatLeague,
                    icon: Icons.format_list_numbered,
                    value: AppConstants.formatLeague,
                  ),
                  if (_selectedFormat == AppConstants.formatLeague)
                    _buildLeagueSettingsSection(),

                  // Knockout
                  _buildFormatCard(
                    title: AppConstants.formatKnockout,
                    icon: Icons.account_tree,
                    value: AppConstants.formatKnockout,
                  ),
                  // No specific settings for standalone knockout here yet

                  // League + Knockout
                  _buildFormatCard(
                    title: AppConstants.formatLeagueKnockout,
                    icon: Icons.schema,
                    value: AppConstants.formatLeagueKnockout,
                  ),
                  if (_selectedFormat == AppConstants.formatLeagueKnockout)
                    _buildLeagueSettingsSection(),

                  // Groups + Knockout
                  _buildFormatCard(
                    title: AppConstants.formatGroupsKnockout,
                    icon: Icons.grid_view,
                    value: AppConstants.formatGroupsKnockout,
                  ),
                  if (_selectedFormat == AppConstants.formatGroupsKnockout) ...[
                    _buildGroupSettingsSection(),
                  ],

                  // Single Match
                  _buildFormatCard(
                    title: AppConstants.formatSingleMatch,
                    icon: Icons.sports_score,
                    value: AppConstants.formatSingleMatch,
                  ),

                  // Custom
                  _buildFormatCard(
                    title: AppConstants.formatCustom,
                    icon: Icons.help_outline,
                    value: AppConstants.formatCustom,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.backgroundDark,
              border: Border(
                top: BorderSide(color: AppColors.cardBackground, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_selectedFormat == null || _isLoading)
                    ? null
                    : _saveFormatAndContinue,
                child: _isLoading
                    ? const LoadingSpinner(
                        size: 24,
                        color: AppColors.textPrimary,
                      )
                    : const Text('Next', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueSettingsSection() {
    return Column(
      children: [
        const Divider(color: AppColors.dividerColor, height: 32),
        Text(
          'League Table Settings',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Win',
                  hintText: '3',
                ),
                controller: TextEditingController(
                  text: _pointsForWin.toString(),
                ),
                onChanged: (v) => _pointsForWin = int.tryParse(v) ?? 3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Draw',
                  hintText: '1',
                ),
                controller: TextEditingController(
                  text: _pointsForDraw.toString(),
                ),
                onChanged: (v) => _pointsForDraw = int.tryParse(v) ?? 1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Loss',
                  hintText: '0',
                ),
                controller: TextEditingController(
                  text: _pointsForLoss.toString(),
                ),
                onChanged: (v) => _pointsForLoss = int.tryParse(v) ?? 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tie Breaker Priority Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tie Breaker Priority',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  if (widget.competition.sport ==
                      AppConstants.sportCricket) ...[
                    _buildTieBreakerChip('Wins', AppConstants.tieBreakerWins),
                    _buildTieBreakerChip(
                      'Net Run Rate (NRR)',
                      AppConstants.tieBreakerNrr,
                    ),
                  ] else ...[
                    _buildTieBreakerChip(
                      'Goal Difference',
                      AppConstants.tieBreakerGoalDiff,
                    ),
                    _buildTieBreakerChip(
                      'Goals Scored',
                      AppConstants.tieBreakerGoalsScored,
                    ),
                    _buildTieBreakerChip(
                      'Head to Head',
                      AppConstants.tieBreakerHeadToHead,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedTieBreakerRules.isEmpty)
                const Text(
                  'Please select at least one tie breaker rule.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                )
              else
                Text(
                  'Order: ${_selectedTieBreakerRules.map((r) => r.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')).join(' > ')}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFormatCard({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedFormat == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accentGreen
                        : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTieBreakerChip(String label, String value) {
    final index = _selectedTieBreakerRules.indexOf(value);
    final isSelected = index != -1;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTieBreakerRules.add(value);
          } else {
            _selectedTieBreakerRules.remove(value);
          }
        });
      },
      backgroundColor: AppColors.backgroundDark,
      selectedColor: AppColors.accentGreen.withValues(alpha: 0.2),
      checkmarkColor: AppColors.accentGreen,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentGreen : AppColors.textPrimary,
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

  Widget _buildGroupSettingsSection() {
    return Column(
      children: [
        const Divider(color: AppColors.dividerColor, height: 32),
        Text(
          'Group Settings',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _numberOfGroups,
              isExpanded: true,
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.textPrimary),
              items: List.generate(15, (i) => i + 2).map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text(
                    '$count Groups (${List.generate(count, (i) => String.fromCharCode(65 + i)).join(", ")}...)',
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _numberOfGroups = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildLeagueSettingsSection(), // Reuse league settings for points
      ],
    );
  }
}
