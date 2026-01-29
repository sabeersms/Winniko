// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/competition_model.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_spinner.dart';

class RecycleBinScreen extends StatefulWidget {
  final String organizerId;

  const RecycleBinScreen({super.key, required this.organizerId});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  // Auto-prune Check
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAutoPrune();
    });
  }

  Future<void> _performAutoPrune() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    // Fetch one-time snapshot of deleted items
    final snapshot = await firestore
        .getDeletedCompetitions(widget.organizerId)
        .first;

    for (var comp in snapshot) {
      if (comp.deletedAt == null) continue;

      final daysDeleted = DateTime.now().difference(comp.deletedAt!).inDays;
      if (daysDeleted >= 7) {
        debugPrint(
          'Auto-pruning competition: ${comp.name} (Deleted $daysDeleted days ago)',
        );
        await firestore.permanentDeleteCompetition(comp.id);
      }
    }
  }

  String _getRemainingTime(DateTime deletedAt) {
    final deadline = deletedAt.add(const Duration(days: 7));
    final remaining = deadline.difference(DateTime.now());

    if (remaining.isNegative) {
      return 'Expired';
    }

    if (remaining.inDays > 0) {
      return '${remaining.inDays} days remaining';
    } else {
      return '${remaining.inHours} hours remaining';
    }
  }

  Future<void> _restoreCompetition(CompetitionModel competition) async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      await firestore.restoreCompetition(competition.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${competition.name} restored!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _permanentDelete(CompetitionModel competition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Delete Forever?',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(
          'This will permanently delete "${competition.name}". This action CANNOT be undone.',
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
              'Delete Forever',
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
      await firestore.permanentDeleteCompetition(competition.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Competition permanently deleted.'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: StreamBuilder<List<CompetitionModel>>(
        stream: firestore.getDeletedCompetitions(widget.organizerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingSpinner());
          }

          final deletedCompetitions = snapshot.data ?? [];

          if (deletedCompetitions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Recycle Bin is empty',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deletedCompetitions.length,
            itemBuilder: (context, index) {
              final comp = deletedCompetitions[index];
              return Card(
                color: AppColors.cardBackground,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    comp.name,
                    style: const TextStyle(
                      color: Colors.white54,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    _getRemainingTime(comp.deletedAt!),
                    style: const TextStyle(color: AppColors.error),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.restore,
                          color: AppColors.accentGreen,
                        ),
                        tooltip: 'Restore',
                        onPressed: () => _restoreCompetition(comp),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: AppColors.error,
                        ),
                        tooltip: 'Delete Forever',
                        onPressed: () => _permanentDelete(comp),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
