// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../widgets/loading_spinner.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../services/ad_service.dart';

class MatchScoreScreen extends StatefulWidget {
  final MatchModel match;
  final String sport;

  const MatchScoreScreen({super.key, required this.match, required this.sport});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  final TextEditingController _homeScoreController = TextEditingController();
  final TextEditingController _awayScoreController = TextEditingController();
  String? _tieBreakWinnerId;

  bool _isLoading = false;

  // For Cricket
  String? _cricketWinnerId;
  String? _battingFirstId; // New: Who batted first
  String _cricketMarginType = 'runs';
  String? _cricketMarginValue;
  final TextEditingController _t1RunsController = TextEditingController();
  final TextEditingController _t1WicketsController = TextEditingController();
  final TextEditingController _t2RunsController = TextEditingController();
  final TextEditingController _t2WicketsController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.match.actualScore != null) {
      if (widget.sport == AppConstants.sportCricket) {
        _cricketWinnerId = widget.match.actualScore!['winnerId'];
        _battingFirstId = widget.match.actualScore!['battingFirstId'];
        _cricketMarginType = widget.match.actualScore!['marginType'] ?? 'runs';
        _cricketMarginValue = widget.match.actualScore!['marginValue'];
        _t1RunsController.text =
            widget.match.actualScore!['t1Runs']?.toString() ?? '';
        _t1WicketsController.text =
            widget.match.actualScore!['t1Wickets']?.toString() ?? '';
        _t2RunsController.text =
            widget.match.actualScore!['t2Runs']?.toString() ?? '';
        _t2WicketsController.text =
            widget.match.actualScore!['t2Wickets']?.toString() ?? '';
      } else {
        _homeScoreController.text =
            widget.match.actualScore!['team1']?.toString() ?? '0';
        _awayScoreController.text =
            widget.match.actualScore!['team2']?.toString() ?? '0';
        _tieBreakWinnerId = widget.match.actualScore!['winnerId'];
      }
    }

    _homeScoreController.addListener(() => setState(() {}));
    _awayScoreController.addListener(() => setState(() {}));
    _t1RunsController.addListener(() => setState(() {}));
    _t2RunsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _t1RunsController.dispose();
    _t1WicketsController.dispose();
    _t2RunsController.dispose();
    _t2WicketsController.dispose();
    super.dispose();
  }

  Future<void> _saveScore() async {
    if (DateTime.now().isBefore(widget.match.scheduledTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update score before match start time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      final int homeScore = int.tryParse(_homeScoreController.text) ?? 0;
      final int awayScore = int.tryParse(_awayScoreController.text) ?? 0;

      final bool isCricket = widget.sport == AppConstants.sportCricket;

      // Auto-Calculate Cricket Result if needed
      Map<String, dynamic> actualScore;

      if (isCricket) {
        if (_battingFirstId == null && _t1RunsController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select who batted first')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Calculate Result Logic
        int t1Runs = int.tryParse(_t1RunsController.text) ?? 0;
        int t2Runs = int.tryParse(_t2RunsController.text) ?? 0;
        int t1Wickets = int.tryParse(_t1WicketsController.text) ?? 0;
        int t2Wickets = int.tryParse(_t2WicketsController.text) ?? 0;

        _cricketWinnerId = 'tied'; // Default
        if (t1Runs > t2Runs) _cricketWinnerId = widget.match.team1Id;
        if (t2Runs > t1Runs) _cricketWinnerId = widget.match.team2Id;

        // Check for Super Over / Tie Breaker
        if (t1Runs == t2Runs) {
          if (_tieBreakWinnerId != null) {
            _cricketWinnerId = _tieBreakWinnerId;
            _cricketMarginType = 'super_over';
            _cricketMarginValue = '0';
          } else {
            _cricketWinnerId = 'tied';
          }
        }

        if (_cricketWinnerId != 'tied' &&
            _cricketWinnerId != 'no_result' &&
            _cricketMarginType != 'super_over') {
          if (_cricketWinnerId == _battingFirstId) {
            // Batting First Won -> Runs Margin
            _cricketMarginType = 'runs';
            int diff = (t1Runs - t2Runs).abs();
            _cricketMarginValue = _getRunRange(diff);
          } else {
            // Batting Second Won -> Wickets Margin
            _cricketMarginType = 'wickets';
            int winnerWickets = _cricketWinnerId == widget.match.team1Id
                ? t1Wickets
                : t2Wickets;
            // Assuming 10 wickets total
            int wicketsLeft = 10 - winnerWickets;
            if (wicketsLeft < 0) wicketsLeft = 0;
            _cricketMarginValue = wicketsLeft.toString();
          }
        }

        actualScore = {
          'winnerId': _cricketWinnerId,
          'battingFirstId': _battingFirstId,
          'marginType': _cricketMarginType,
          'marginValue': _cricketMarginValue,
          't1Runs': t1Runs,
          't1Wickets': t1Wickets,
          't2Runs': t2Runs,
          't2Wickets': t2Wickets,
        };
      } else {
        actualScore = {
          'team1': homeScore,
          'team2': awayScore,
          if (homeScore == awayScore && _tieBreakWinnerId != null)
            'winnerId': _tieBreakWinnerId,
        };
      }

      final bool requiresMargin =
          isCricket &&
          _cricketWinnerId != 'tied' &&
          _cricketWinnerId != 'no_result';

      if (isCricket && _cricketWinnerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a result')));
        setState(() => _isLoading = false);
        return;
      }

      if (requiresMargin && _cricketMarginValue == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a margin')));
        setState(() => _isLoading = false);
        return;
      }

      // Strict Confirmation for Score Updates
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Confirm Match Result',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saving this result will finalize scores, update standings, and calculate points for all participants.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isCricket
                    ? Text(
                        _cricketWinnerId == 'tied'
                            ? 'Result: Tied'
                            : _cricketWinnerId == 'no_result'
                            ? 'Result: No Result'
                            : _cricketMarginType == 'super_over'
                            ? 'Winner: ${_cricketWinnerId == widget.match.team1Id ? widget.match.team1Name : widget.match.team2Name} (Super Over)'
                            : 'Winner: ${_cricketWinnerId == widget.match.team1Id ? widget.match.team1Name : widget.match.team2Name}\nMargin: $_cricketMarginValue $_cricketMarginType',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.match.team1Name}: $homeScore',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              'vs',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${widget.match.team2Name}: $awayScore',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirm & Save',
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

      await firestore.updateMatchScore(
        widget.match.competitionId,
        widget.match.id,
        actualScore,
        AppConstants.matchStatusCompleted,
        oldScore: widget.match.actualScore,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Score updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetMatch() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Reset Match?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will set the match status back to "Scheduled", clear the score, and revert any points awarded to participants. This action cannot be undone.',
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
              'Reset Match',
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
      if (!context.mounted) return;
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      await firestore.updateMatchScore(
        widget.match.competitionId,
        widget.match.id,
        {}, // Empty score
        AppConstants.matchStatusScheduled,
        oldScore: widget.match.actualScore,
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match reset to scheduled!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadReport() async {
    // Show Ad before PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please watch this short ad to support Winniko!'),
        duration: Duration(seconds: 2),
      ),
    );

    AdService().showInterstitialAd(
      onAdDismissed: () async {
        if (!mounted) return;
        setState(() => _isLoading = true);
        try {
          final firestore = Provider.of<FirestoreService>(
            context,
            listen: false,
          );

          // 1. Get Competition Details
          final competition = await firestore.getCompetition(
            widget.match.competitionId,
          );
          if (competition == null) throw Exception('Competition not found');

          // 2. Get Predictions for this match
          final predictions = await firestore.getPredictionsForMatch(
            widget.match.id,
          );
          if (predictions.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No predictions found for this match.'),
              ),
            );
            return;
          }

          // 3. Get Participants (for names)
          final leaderboard = await firestore
              .getLeaderboard(widget.match.competitionId)
              .first;

          // 4. Generate PDF
          await PdfService.generateMatchReport(
            widget.match,
            predictions,
            competition,
            leaderboard,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating report: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Update Score'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Report',
            onPressed: _isLoading ? null : _downloadReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Dropdown removed
            const SizedBox(height: 32),

            // Score Input
            if (widget.sport == AppConstants.sportCricket)
              _buildCricketResultInput()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScoreInput(
                    widget.match.team1Name,
                    _homeScoreController,
                  ),
                  const Text(
                    '-',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _buildScoreInput(
                    widget.match.team2Name,
                    _awayScoreController,
                  ),
                ],
              ),
            const SizedBox(height: 48),

            // Tie Break Selection (Football/Other)
            if (widget.sport != AppConstants.sportCricket &&
                _homeScoreController.text == _awayScoreController.text &&
                _homeScoreController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  children: [
                    const Text(
                      'Match Ended in a Draw?',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select the winner if there was a tie-breaker (e.g. Penalties)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _tieBreakWinnerId != null
                              ? AppColors.accentGreen
                              : AppColors.dividerColor,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tieBreakWinnerId,
                          hint: const Text(
                            'Select Winner (Optional)',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          dropdownColor: AppColors.cardBackground,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.emoji_events,
                            color: AppColors.accentGreen,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: const Text(
                                'No Tie Breaker (Draw)',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            DropdownMenuItem(
                              value: widget.match.team1Id,
                              child: Text(
                                '${widget.match.team1Name} Wins',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: widget.match.team2Id,
                              child: Text(
                                '${widget.match.team2Name} Wins',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _tieBreakWinnerId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveScore,
                child: _isLoading
                    ? const LoadingSpinner(
                        size: 24,
                        color: AppColors.textPrimary,
                      )
                    : const Text('Save Result'),
              ),
            ),
            if (widget.match.status == AppConstants.matchStatusCompleted ||
                widget.match.status == AppConstants.matchStatusLive ||
                widget.match.actualScore != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _resetMatch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset to Scheduled'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCricketResultInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actual Scores',
          style: TextStyle(
            color: AppColors.accentGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    widget.match.team1Name,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _t1RunsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Runs',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _t1WicketsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Wickets',
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  Text(
                    widget.match.team2Name,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _t2RunsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Runs',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _t2WicketsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Wickets',
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const Text(
          'Who batted first?',
          style: TextStyle(
            color: AppColors.accentGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        RadioListTile<String>(
          title: Text(
            widget.match.team1Name,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          value: widget.match.team1Id,
          groupValue: _battingFirstId,
          activeColor: AppColors.accentGreen,
          onChanged: (val) => setState(() => _battingFirstId = val),
        ),
        RadioListTile<String>(
          title: Text(
            widget.match.team2Name,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          value: widget.match.team2Id,
          groupValue: _battingFirstId,
          activeColor: AppColors.accentGreen,
          onChanged: (val) => setState(() => _battingFirstId = val),
        ),

        // Tie Breaker Selection
        if (_t1RunsController.text.isNotEmpty &&
            _t2RunsController.text.isNotEmpty &&
            _t1RunsController.text == _t2RunsController.text)
          Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: Column(
              children: [
                const Text(
                  'Match Tied?',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select winner if decided by Super Over or similar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _tieBreakWinnerId != null
                          ? AppColors.accentGreen
                          : AppColors.dividerColor,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tieBreakWinnerId,
                      hint: const Text(
                        'Select Winner (Optional)',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      dropdownColor: AppColors.cardBackground,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.emoji_events,
                        color: AppColors.accentGreen,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: const Text(
                            'Match Tied',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: widget.match.team1Id,
                          child: Text(
                            '${widget.match.team1Name} Wins',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: widget.match.team2Id,
                          child: Text(
                            '${widget.match.team2Name} Wins',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _tieBreakWinnerId = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getRunRange(int runs) {
    for (String range in AppConstants.cricketRunMargins) {
      if (range.contains('+')) {
        int min = int.tryParse(range.replaceAll('+', '')) ?? 201;
        if (runs >= min) return range;
      } else {
        List<String> parts = range.split('-');
        if (parts.length == 2) {
          int min = int.tryParse(parts[0]) ?? 0;
          int max = int.tryParse(parts[1]) ?? 999;
          if (runs >= min && runs <= max) return range;
        }
      }
    }
    return AppConstants.cricketRunMargins.first; // Fallback
  }

  Widget _buildScoreInput(String teamName, TextEditingController controller) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            teamName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentGreen),
          ),
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
