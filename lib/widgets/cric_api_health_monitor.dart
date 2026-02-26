import 'package:flutter/material.dart';
import '../services/cric_api_service.dart';
import '../constants/app_constants.dart';

/// Widget to display CricAPI service health and cache statistics
///
/// Useful for debugging and monitoring API performance
class CricApiHealthMonitor extends StatefulWidget {
  const CricApiHealthMonitor({super.key});

  @override
  State<CricApiHealthMonitor> createState() => _CricApiHealthMonitorState();
}

class _CricApiHealthMonitorState extends State<CricApiHealthMonitor> {
  final CricApiService _apiService = CricApiService();
  Map<String, dynamic>? _stats;
  CricApiHealthStatus? _healthStatus;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _stats = _apiService.getCacheStats();
      _healthStatus = _apiService.getHealthStatus();
    });
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing CricAPI connection...')),
    );

    try {
      final matches = await _apiService.fetchCurrentMatches(forceRefresh: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Success! Fetched ${matches.length} matches'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshStats();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      _refreshStats();
    }
  }

  void _clearCache() {
    _apiService.clearCache();
    _refreshStats();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CricAPI Health Monitor',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildHealthBadge(),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            if (_stats != null) ...[
              _buildStatRow(
                'Cache Status',
                _stats!['hasCachedData'] ? 'Active' : 'Empty',
              ),
              _buildStatRow('Cached Matches', '${_stats!['cachedMatchCount']}'),
              _buildStatRow('Cache Age', _stats!['cacheAge']),
              _buildStatRow(
                'Cache Valid',
                _stats!['isCacheValid'] ? 'Yes' : 'No',
              ),
              _buildStatRow(
                'Consecutive Errors',
                '${_stats!['consecutiveErrors']}',
              ),

              if (_stats!['lastError'] != null) ...[
                const SizedBox(height: 8),
                _buildErrorSection(_stats!['lastError']),
              ],

              if (_stats!['lastSuccessfulFetch'] != null) ...[
                const SizedBox(height: 8),
                _buildStatRow(
                  'Last Success',
                  _formatDateTime(_stats!['lastSuccessfulFetch']),
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Cache'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
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

  Widget _buildHealthBadge() {
    if (_healthStatus == null) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;
    String label;

    switch (_healthStatus!) {
      case CricApiHealthStatus.healthy:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Healthy';
        break;
      case CricApiHealthStatus.degraded:
        color = Colors.orange;
        icon = Icons.warning;
        label = 'Degraded';
        break;
      case CricApiHealthStatus.critical:
        color = Colors.red;
        icon = Icons.error;
        label = 'Critical';
        break;
      case CricApiHealthStatus.unknown:
        color = Colors.grey;
        icon = Icons.help;
        label = 'Unknown';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Error:',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return isoString;
    }
  }
}
