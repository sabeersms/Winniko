import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/loading_spinner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../services/firestore_service.dart';

class MatchCreateScreen extends StatefulWidget {
  final String competitionId;
  final List<TeamModel> teams;
  final MatchModel? match; // Optional for Editing

  const MatchCreateScreen({
    super.key,
    required this.competitionId,
    required this.teams,
    this.match,
  });

  @override
  State<MatchCreateScreen> createState() => _MatchCreateScreenState();
}

class _MatchCreateScreenState extends State<MatchCreateScreen> {
  TeamModel? _selectedHomeTeam;
  TeamModel? _selectedAwayTeam;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _roundController = TextEditingController();
  final TextEditingController _matchNumberController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.match != null) {
      // Pre-fill for editing
      _selectedDate = widget.match!.scheduledTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.match!.scheduledTime);
      _roundController.text = widget.match!.round ?? '';
      _matchNumberController.text = widget.match!.matchNumber?.toString() ?? '';

      try {
        _selectedHomeTeam = widget.teams.firstWhere(
          (t) => t.id == widget.match!.team1Id,
        );
        _selectedAwayTeam = widget.teams.firstWhere(
          (t) => t.id == widget.match!.team2Id,
        );
      } catch (e) {
        // Teams might have been deleted, handle gracefully (leave null)
      }
    }
  }

  @override
  void dispose() {
    _roundController.dispose();
    _matchNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), // Allow past for corrections
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentGreen,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Show Cupertino Date Picker in a specific simplified style
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const Text(
                      'Select Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Picker
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
                    initialDateTime: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                      _selectedTime.hour,
                      _selectedTime.minute,
                    ),
                    use24hFormat: false, // Force 12-hour format
                    onDateTimeChanged: (DateTime newDateTime) {
                      setState(() {
                        _selectedTime = TimeOfDay.fromDateTime(newDateTime);
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

  Future<void> _saveMatch() async {
    if (_selectedHomeTeam == null || _selectedAwayTeam == null) {
      setState(() => _errorMessage = 'Please select both teams');
      return;
    }

    if (_selectedHomeTeam!.id == _selectedAwayTeam!.id) {
      setState(() => _errorMessage = 'Teams must be different');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      final matchDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final match = MatchModel(
        id: widget.match?.id ?? const Uuid().v4(), // Reuse ID if editing
        competitionId: widget.competitionId,
        team1Id: _selectedHomeTeam!.id,
        team1Name: _selectedHomeTeam!.name,
        team1LogoUrl: _selectedHomeTeam!.logoUrl,
        team2Id: _selectedAwayTeam!.id,
        team2Name: _selectedAwayTeam!.name,
        team2LogoUrl: _selectedAwayTeam!.logoUrl,
        scheduledTime: matchDate,
        status:
            widget.match?.status ??
            AppConstants.matchStatusScheduled, // Preserve status if editing
        actualScore: widget.match?.actualScore, // Preserve score
        round: _roundController.text.isEmpty ? null : _roundController.text,
        group: widget.match?.group,
        matchNumber: int.tryParse(_matchNumberController.text),
      );

      // Strict Confirmation for Edits
      if (widget.match != null) {
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text(
              'Confirm Changes',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'Are you sure you want to update this match? Changes to teams or schedule may invalidate existing predictions.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Update',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (widget.match != null) {
        await firestore.updateMatch(match);
      } else {
        await firestore.addMatch(match);
      }

      // Recalculate standings to reflect changes immediately
      await firestore.recalculateStandings(widget.competitionId);

      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.match != null;
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: Text(isEditing ? 'Edit Match' : 'Create Match')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Selection
            const Text(
              'Select Teams',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTeamDropdown(
              label: 'Home Team',
              value: _selectedHomeTeam,
              items: widget.teams,
              onChanged: (val) => setState(() => _selectedHomeTeam = val),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardColor,
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTeamDropdown(
              label: 'Away Team',
              value: _selectedAwayTeam,
              items: widget.teams,
              onChanged: (val) => setState(() => _selectedAwayTeam = val),
            ),
            const SizedBox(height: 32),

            // Match Details
            const Text(
              'Match Details',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roundController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Round Name',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      hintText: 'e.g. Round 1',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.dividerColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _matchNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Match #',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      hintText: 'e.g. 1',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.dividerColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Date & Time
            const Text(
              'Schedule',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.dividerColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.accentGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.dividerColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppColors.accentGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                color: AppColors.error.withValues(alpha: 0.2),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMatch,
                child: _isLoading
                    ? const LoadingSpinner(
                        size: 24,
                        color: AppColors.textPrimary,
                      )
                    : Text(
                        widget.match != null ? 'Update Match' : 'Create Match',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDropdown({
    required String label,
    required TeamModel? value,
    required List<TeamModel> items,
    required ValueChanged<TeamModel?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TeamModel>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.cardBackground,
              hint: const Text(
                'Select Team',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              items: items.map((team) {
                return DropdownMenuItem(
                  value: team,
                  child: Row(
                    children: [
                      if (team.logoUrl != null)
                        CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            team.logoUrl!,
                          ),
                          radius: 12,
                        )
                      else
                        const Icon(Icons.shield, size: 24, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        team.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
