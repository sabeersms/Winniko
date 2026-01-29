import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/competition_model.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_spinner.dart';
import '../widgets/team_logo.dart';
import 'competition_detail_screen.dart';
import 'full_fixtures_screen.dart';

class GeneratedFixturesPreviewScreen extends StatefulWidget {
  final CompetitionModel competition;
  final List<MatchModel> matches;

  const GeneratedFixturesPreviewScreen({
    super.key,
    required this.competition,
    required this.matches,
  });

  @override
  State<GeneratedFixturesPreviewScreen> createState() =>
      _GeneratedFixturesPreviewScreenState();
}

class _GeneratedFixturesPreviewScreenState
    extends State<GeneratedFixturesPreviewScreen> {
  late List<MatchModel> _matches;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy and sort by date
    _matches = List.from(widget.matches);
    _matches.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    final match = _matches[index];
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: match.scheduledTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentGreen,
              onPrimary: AppColors.textPrimary,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.backgroundDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Keep existing time
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        match.scheduledTime.hour,
        match.scheduledTime.minute,
      );

      setState(() {
        _matches[index] = match.copyWith(scheduledTime: newDateTime);
        // Re-sort to keep order
        _matches.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      });
    }
  }

  void _selectTime(BuildContext context, int index) {
    final match = _matches[index];
    final initialDateTime = match.scheduledTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              // Header with Done button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Time',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newDateTime) {
                      // Combined date from match with time from picker
                      final updatedDateTime = DateTime(
                        match.scheduledTime.year,
                        match.scheduledTime.month,
                        match.scheduledTime.day,
                        newDateTime.hour,
                        newDateTime.minute,
                      );

                      setState(() {
                        _matches[index] = match.copyWith(
                          scheduledTime: updatedDateTime,
                        );
                        // No need to sort just for time changes usually, but safe to do
                        // _matches.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveFixtures() async {
    setState(() => _isSaving = true);

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      await firestore.createBatchMatches(_matches);

      // Initialize Standings
      await firestore.recalculateStandings(widget.competition.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_matches.length} fixtures saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate to Matches Tab
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionDetailScreen(
            competitionId: widget.competition.id,
            initialTab: 1, // Matches Tab
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving fixtures: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Preview Fixtures'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: LoadingSpinner(size: 20, color: Colors.white),
              ),
            )
          else if (!_isSaving) ...[
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'View Full List',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullFixturesScreen(
                      competition: widget.competition,
                      matches: _matches,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: _saveFixtures,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardBackground,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.accentGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Review and adjust match times before saving. Tap on the date or time to edit.',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _matches.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.dividerColor, height: 1),
              itemBuilder: (context, index) {
                final match = _matches[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      // Matchup Row
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    match.team1Name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TeamLogo(
                                  url: match.team1LogoUrl,
                                  teamName: match.team1Name,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'VS',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                TeamLogo(
                                  url: match.team2LogoUrl,
                                  teamName: match.team2Name,
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    match.team2Name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Schedule Row
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Round
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDark,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.dividerColor,
                                ),
                              ),
                              child: Text(
                                match.round ?? 'Round ?',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Date Picker
                            GestureDetector(
                              onTap: () => _selectDate(context, index),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: AppColors.accentGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(match.scheduledTime),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.textSecondary,
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Time Picker
                            GestureDetector(
                              onTap: () => _selectTime(context, index),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: AppColors.accentGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat.jm().format(match.scheduledTime),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.textSecondary,
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                  ),
                                ],
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
    );
  }
}
