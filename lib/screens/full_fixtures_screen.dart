import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../services/fixture_pdf_service.dart';
import '../utils/share_util.dart';
import '../widgets/team_logo.dart';
import '../widgets/loading_spinner.dart';
import '../services/ad_service.dart';

class FullFixturesScreen extends StatefulWidget {
  final CompetitionModel competition;
  final List<MatchModel> matches;

  const FullFixturesScreen({
    super.key,
    required this.competition,
    required this.matches,
  });

  @override
  State<FullFixturesScreen> createState() => _FullFixturesScreenState();
}

class _FullFixturesScreenState extends State<FullFixturesScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _sharePdf() async {
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
        setState(() => _isGeneratingPdf = true);
        try {
          final pdfFile = await FixturePdfService.generateTournamentPdf(
            tournamentName: widget.competition.name,
            matches: widget.matches,
          );

          await ShareUtil.shareFile(
            file: pdfFile,
            text:
                'Here is the official schedule for ${widget.competition.name}!',
            mimeType: 'application/pdf',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to share PDF: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isGeneratingPdf = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort matches by date
    final matches = List<MatchModel>.from(widget.matches)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final authService = Provider.of<AuthService>(context, listen: false);
    final isOrganizer =
        authService.currentUser?.uid == widget.competition.organizerId;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Full Schedule'),
        actions: [
          if (isOrganizer)
            if (_isGeneratingPdf)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: LoadingSpinner(size: 20, color: Colors.white),
              )
            else
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share PDF',
                onPressed: _sharePdf,
              ),
        ],
      ),
      body: matches.isEmpty
          ? const Center(
              child: Text(
                'No fixtures available',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.dividerColor, height: 1),
              itemBuilder: (context, index) {
                final match = matches[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Date/Time Column
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM dd').format(match.scheduledTime),
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a').format(match.scheduledTime),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Teams Column
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                TeamLogo(
                                  url: match.team1LogoUrl,
                                  teamName: match.team1Name,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    match.team1Name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TeamLogo(
                                  url: match.team2LogoUrl,
                                  teamName: match.team2Name,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    match.team2Name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Location/Round Info
                      if (match.location != null || match.round != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (match.round != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.dividerColor,
                                  ),
                                ),
                                child: Text(
                                  match.round!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: isOrganizer
          ? FloatingActionButton.extended(
              onPressed: _sharePdf,
              backgroundColor: AppColors.accentGreen,
              icon: _isGeneratingPdf
                  ? const LoadingSpinner(size: 20, color: Colors.white)
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isGeneratingPdf ? 'Generating...' : 'Download PDF'),
            )
          : null,
    );
  }
}
