import 'package:flutter/material.dart';
import 'package:winniko/services/api_usage_tracker.dart';

/// Test script to demonstrate API usage tracking
///
/// Run this to check your current API usage and limits
void main() {
  runApp(const ApiUsageApp());
}

class ApiUsageApp extends StatelessWidget {
  const ApiUsageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Usage Monitor',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ApiUsageScreen(),
    );
  }
}

class ApiUsageScreen extends StatefulWidget {
  const ApiUsageScreen({super.key});

  @override
  State<ApiUsageScreen> createState() => _ApiUsageScreenState();
}

class _ApiUsageScreenState extends State<ApiUsageScreen> {
  final _tracker = ApiUsageTracker();
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  void _refreshReport() {
    setState(() {
      _report = _tracker.getUsageReport();
    });
    // Also print to console
    _tracker.printUsageReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Usage Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _report == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _refreshReport(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildApiCard(
                    'CricAPI',
                    _report!['cricApi'] as Map<String, dynamic>,
                    Icons.sports_cricket,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildApiCard(
                    'RapidAPI',
                    _report!['rapidApi'] as Map<String, dynamic>,
                    Icons.flash_on,
                    Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  _buildWarningCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildApiCard(
    String name,
    Map<String, dynamic> data,
    IconData icon,
    Color color,
  ) {
    final callsToday = data['callsToday'] as int;
    final remaining = data['remaining'] as int?;
    final limit = data['limit'] as int?;
    final percentUsed = data['percentUsed'] as String;
    final resetTime = data['resetTime'] as String?;

    final hasLimitInfo = remaining != null && limit != null;
    final usagePercent = hasLimitInfo
        ? double.tryParse(percentUsed.replaceAll('%', '')) ?? 0
        : 0;

    Color getUsageColor() {
      if (!hasLimitInfo) return Colors.grey;
      if (usagePercent >= 90) return Colors.red;
      if (usagePercent >= 75) return Colors.orange;
      if (usagePercent >= 50) return Colors.yellow.shade700;
      return Colors.green;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 12),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Calls Today', '$callsToday', Icons.call_made),
          if (hasLimitInfo) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              'Remaining',
              '$remaining / $limit',
              Icons.hourglass_bottom,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.pie_chart, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Usage'),
                          Text(
                            percentUsed,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getUsageColor(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: usagePercent / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(getUsageColor()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (resetTime != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Resets',
                _formatResetTime(resetTime),
                Icons.access_time,
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No rate limit info available yet. Make an API call to see limits.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWarningCard() {
    final isApproaching = _tracker.isApproachingLimit(threshold: 0.8);

    if (!isApproaching) {
      return Card(
        color: Colors.green.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'API usage is healthy. You have plenty of calls remaining.',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warning: Approaching API Limit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are using more than 80% of your daily API quota. Consider reducing refresh frequency.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatResetTime(String isoString) {
    try {
      final resetTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = resetTime.difference(now);

      if (difference.isNegative) return 'Already reset';

      if (difference.inHours > 0) {
        return 'in ${difference.inHours}h ${difference.inMinutes % 60}m';
      } else if (difference.inMinutes > 0) {
        return 'in ${difference.inMinutes}m';
      } else {
        return 'in ${difference.inSeconds}s';
      }
    } catch (e) {
      return isoString;
    }
  }
}
