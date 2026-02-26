import 'package:flutter/material.dart';
import '../services/allsports_api_service.dart';

/// Example screen showing how to use AllSportsApi
///
/// This demonstrates fetching and displaying tournament data from AllSportsApi
class AllSportsApiExampleScreen extends StatefulWidget {
  const AllSportsApiExampleScreen({super.key});

  @override
  State<AllSportsApiExampleScreen> createState() =>
      _AllSportsApiExampleScreenState();
}

class _AllSportsApiExampleScreenState extends State<AllSportsApiExampleScreen> {
  final AllSportsApiService _apiService = AllSportsApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Example: Fetch Premier League events
      // You'll need to find the correct tournament and season IDs
      final events = await _apiService.getSeasonTeamEventsAway(
        tournamentId: '17', // Example: Premier League
        seasonId: '61627', // Example: 2025/2026 season
      );

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchLiveMatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch live cricket matches (sportId: 3)
      final liveMatches = await _apiService.getLiveMatches(3);

      setState(() {
        _events = liveMatches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AllSportsApi Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.live_tv),
            onPressed: _fetchLiveMatches,
            tooltip: 'Fetch Live Matches',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchEvents, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    // Extract event data
    final homeTeam = event['homeTeam']?['name'] ?? 'Unknown';
    final awayTeam = event['awayTeam']?['name'] ?? 'Unknown';
    final homeScore = event['homeScore']?['current'];
    final awayScore = event['awayScore']?['current'];
    final status = event['status']?['description'] ?? 'Scheduled';
    final startTime = event['startTimestamp'];

    // Format date if available
    String dateStr = 'TBD';
    if (startTime != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
      dateStr =
          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(status),
                  backgroundColor: _getStatusColor(status),
                ),
                Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),

            // Teams and Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homeTeam,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        awayTeam,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (homeScore != null && awayScore != null)
                  Column(
                    children: [
                      Text(
                        homeScore.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        awayScore.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  const Text('vs', style: TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('live') || statusLower.contains('inprogress')) {
      return Colors.red;
    } else if (statusLower.contains('finished') ||
        statusLower.contains('ended')) {
      return Colors.grey;
    } else {
      return Colors.green;
    }
  }
}
