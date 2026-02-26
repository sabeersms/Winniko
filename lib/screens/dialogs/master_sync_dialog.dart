import 'package:flutter/material.dart';
import '../../services/master_sync_service.dart';
import '../../constants/app_constants.dart';

class MasterSyncDialog extends StatefulWidget {
  const MasterSyncDialog({super.key});

  @override
  State<MasterSyncDialog> createState() => _MasterSyncDialogState();
}

class _MasterSyncDialogState extends State<MasterSyncDialog> {
  final MasterSyncService _syncService = MasterSyncService();
  final Map<String, bool> _syncingStates = {};
  final Map<String, bool> _recommendations = {}; // Cache for Live status
  bool _loading = true;

  // Mapping for nice display names
  final Map<String, String> _leagueNames = {
    'pl': 'Premier League',
    'ipl': 'Indian Premier League',
    'asiacup': 'Asia Cup',
    'cwc': 'Cricket World Cup',
    'ucl': 'Champions League',
    'laliga': 'La Liga',
    'bundesliga': 'Bundesliga',
    'seriea': 'Serie A',
    'ligue1': 'Ligue 1',
    'wc2026': 'FIFA World Cup 2026',
  };

  @override
  void initState() {
    super.initState();
    _checkRecommendations();
  }

  Future<void> _checkRecommendations() async {
    for (var leagueId in MasterSyncService.supportedLeagues) {
      if (!mounted) return;
      // Check each one
      final isLive = await _syncService.isSyncRecommended(leagueId);
      if (mounted) {
        setState(() {
          _recommendations[leagueId] = isLive;
        });
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _runSync(String leagueId) async {
    setState(() {
      _syncingStates[leagueId] = true;
    });

    try {
      await _syncService.syncLeague(leagueId);

      // Re-check after sync to update status
      final isLive = await _syncService.isSyncRecommended(leagueId);

      if (!mounted) return;
      setState(() {
        _recommendations[leagueId] = isLive;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${_leagueNames[leagueId]} successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingStates[leagueId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Master Sync Control',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only run this if you are the Master Admin. This fetches live data from paid APIs and updates the shared Firestore collection.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: MasterSyncService.supportedLeagues.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white24),
                itemBuilder: (context, index) {
                  final leagueId = MasterSyncService.supportedLeagues[index];
                  final name = _leagueNames[leagueId] ?? leagueId.toUpperCase();
                  final isSyncing = _syncingStates[leagueId] ?? false;
                  final isLive = _recommendations[leagueId] ?? false;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isLive
                                ? AppColors.accentGreen
                                : Colors.white,
                            fontWeight: isLive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentGreen,
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLive
                                  ? AppColors.accentGreen
                                  : Colors.grey[800],
                              foregroundColor: isLive
                                  ? Colors.black
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _runSync(leagueId),
                            child: const Text('Sync Now'),
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
}
