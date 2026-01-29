import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/competition_model.dart';

class FixtureConfigurationDialog extends StatefulWidget {
  final CompetitionModel competition;

  const FixtureConfigurationDialog({super.key, required this.competition});

  @override
  State<FixtureConfigurationDialog> createState() =>
      _FixtureConfigurationDialogState();
}

class _FixtureConfigurationDialogState
    extends State<FixtureConfigurationDialog> {
  bool _doubleRoundRobin = false;
  bool _randomSeed = true;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text(
        'Generate Fixtures',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Format: ${widget.competition.format}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          if (widget.competition.format == AppConstants.formatLeague ||
              widget.competition.format == AppConstants.formatLeagueKnockout ||
              widget.competition.format == AppConstants.formatGroupsKnockout)
            SwitchListTile(
              title: const Text(
                'Double Round Robin',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Teams play each other twice (Home & Away)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: _doubleRoundRobin,
              onChanged: (val) => setState(() => _doubleRoundRobin = val),
              activeColor: AppColors.accentGreen,
              contentPadding: EdgeInsets.zero,
            ),

          if (widget.competition.format == AppConstants.formatKnockout ||
              widget.competition.format == AppConstants.formatGroupsKnockout ||
              widget.competition.format == AppConstants.formatLeagueKnockout)
            SwitchListTile(
              title: const Text(
                'Random Seeding',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Shuffle teams before generating bracket',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: _randomSeed,
              onChanged: (val) => setState(() => _randomSeed = val),
              activeColor: AppColors.accentGreen,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Cancel
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'doubleRoundRobin': _doubleRoundRobin,
              'numberOfGroups': widget.competition.numberOfGroups,
              'randomSeed': _randomSeed,
            });
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
