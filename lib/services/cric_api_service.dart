import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'api_usage_tracker.dart';

/// Enhanced CricAPI Service with robust error handling and caching
///
/// Features:
/// - Smart caching with configurable TTL
/// - Automatic retry with exponential backoff
/// - Comprehensive error handling
/// - Rate limit protection
/// - Detailed logging
/// - Fallback to cached data on errors
class CricApiService {
  static const String _baseUrl = 'https://api.cricapi.com/v1';

  // Cache configuration
  static const Duration _cacheValidDuration = Duration(minutes: 2);
  static const Duration _cacheFallbackDuration = Duration(minutes: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Cache storage
  static List<Map<String, dynamic>>? _cachedMatches;
  static DateTime? _lastSuccessfulFetch;
  static DateTime? _lastFetchAttempt;

  // Error tracking
  static int _consecutiveErrors = 0;
  static String? _lastError;

  // Rate limiting
  static const Duration _minTimeBetweenRequests = Duration(seconds: 1);

  // Series List caching (Save API hits!)
  static List<Map<String, dynamic>>? _cachedSeriesList;
  static DateTime? _lastSeriesListFetch;
  static const Duration _seriesListCacheDuration = Duration(hours: 12);

  /// Fetches current matches from CricAPI with enhanced error handling
  ///
  /// Returns cached data if:
  /// - Cache is fresh (< 2 minutes old)
  /// - API fails but cache exists (< 30 minutes old)
  /// - Rate limited
  Future<List<Map<String, dynamic>>> fetchCurrentMatches({
    bool forceRefresh = false,
  }) async {
    try {
      // Check if we should use cache
      if (!forceRefresh && _shouldUseCache()) {
        debugPrint('CricAPI: Using cached data (${_getCacheAge()} old)');
        return _cachedMatches!;
      }

      // Rate limiting protection
      if (_lastFetchAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(
          _lastFetchAttempt!,
        );
        if (timeSinceLastAttempt < _minTimeBetweenRequests) {
          final waitTime = _minTimeBetweenRequests - timeSinceLastAttempt;
          debugPrint(
            'CricAPI: Rate limit protection, waiting ${waitTime.inMilliseconds}ms',
          );
          await Future.delayed(waitTime);
        }
      }

      _lastFetchAttempt = DateTime.now();

      // Fetch with retry logic
      final matches = await _fetchWithRetry();

      // Update cache on success
      _cachedMatches = matches;
      _lastSuccessfulFetch = DateTime.now();
      _consecutiveErrors = 0;
      _lastError = null;

      debugPrint('CricAPI: Successfully fetched ${matches.length} matches');
      return matches;
    } catch (e) {
      _consecutiveErrors++;
      _lastError = e.toString();

      debugPrint(
        'CricAPI: Error fetching matches (attempt $_consecutiveErrors): $e',
      );

      // Return cached data if available (even if old)
      if (_cachedMatches != null && _isCacheFallbackValid()) {
        debugPrint(
          'CricAPI: Returning stale cache due to error (${_getCacheAge()} old)',
        );
        return _cachedMatches!;
      }

      // No cache available, return empty list
      debugPrint('CricAPI: No cache available, returning empty list');
      return [];
    }
  }

  /// Fetches data with automatic retry and exponential backoff
  Future<List<Map<String, dynamic>>> _fetchWithRetry() async {
    int attempt = 0;
    Duration delay = _retryDelay;

    while (attempt < _maxRetries) {
      try {
        return await _performFetch();
      } catch (e) {
        // CRITICAL: Stop retrying if we hit a hard API error (like Quota Exceeded)
        if (e is CricApiException) {
          if (e.type == CricApiErrorType.apiError ||
              e.type == CricApiErrorType.rateLimited ||
              e.type == CricApiErrorType.authentication) {
            debugPrint(
              'CricAPI: Aborting retry due to hard error: ${e.message}',
            );
            rethrow;
          }
        }

        attempt++;

        if (attempt >= _maxRetries) {
          throw CricApiException(
            'Failed after $_maxRetries attempts: $e',
            type: CricApiErrorType.maxRetriesExceeded,
          );
        }

        debugPrint(
          'CricAPI: Fetch attempt $attempt failed, retrying in ${delay.inSeconds}s: $e',
        );
        await Future.delayed(delay);

        // Exponential backoff
        delay *= 2;
      }
    }

    throw CricApiException(
      'Unexpected error in retry logic',
      type: CricApiErrorType.unknown,
    );
  }

  /// Fetches list of active major cricket series (Tournaments)
  Future<List<Map<String, dynamic>>> getSeriesList() async {
    // Check Cache (Save 5 hits per call!)
    if (_cachedSeriesList != null &&
        _lastSeriesListFetch != null &&
        DateTime.now().difference(_lastSeriesListFetch!) <
            _seriesListCacheDuration) {
      debugPrint('CricAPI: Using cached Series List');
      return _cachedSeriesList!;
    }

    List<Map<String, dynamic>> allSeries = [];
    int offset = 0;
    bool hasMore = true;
    int maxPages =
        5; // Fetch up to 5 pages to find tournaments pushed down the list
    int page = 0;

    while (hasMore && page < maxPages) {
      final String url =
          '$_baseUrl/series?apikey=${AppConstants.cricApiKey}&offset=$offset';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] != 'success') {
            final reason = data['reason'] ?? 'Unknown API error';
            throw CricApiException(
              'API Error: $reason',
              type: CricApiErrorType.apiError,
            );
          }

          final List<dynamic> seriesList = data['data'];

          if (seriesList.isEmpty) {
            hasMore = false;
          } else {
            allSeries.addAll(seriesList.cast<Map<String, dynamic>>());
            offset += seriesList.length;

            // If we got fewer results than a full page (typically 25), we are done
            if (seriesList.length < 25) hasMore = false;
          }
          page++;
        } else {
          debugPrint('CricAPI: Series list failed with ${response.statusCode}');
          break;
        }
      } catch (e) {
        debugPrint('CricAPI: Error fetching series list page $page: $e');
        break;
      }
    }

    // Update Cache
    if (allSeries.isNotEmpty) {
      _cachedSeriesList = allSeries;
      _lastSeriesListFetch = DateTime.now();
    }

    debugPrint(
      'CricAPI: Fetched total ${allSeries.length} series across $page pages',
    );
    return allSeries;
  }

  /// Fetches all matches for a specific series
  Future<List<Map<String, dynamic>>> getSeriesMatches(String seriesId) async {
    final String url =
        '$_baseUrl/series_info?apikey=${AppConstants.cricApiKey}&id=$seriesId';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] != 'success') return [];

        final info = data['data'];
        if (info == null || info['matchList'] == null) return [];

        final List<dynamic> matches = info['matchList'];
        return matches.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('CricAPI: Error fetching series matches for $seriesId: $e');
      return [];
    }
  }

  /// Fetches detailed scorecard for a specific match
  Future<Map<String, dynamic>?> getMatchScore(String matchId) async {
    // Switch to match_info as match_score seems deprecated/restricted
    final String url =
        '$_baseUrl/match_info?apikey=${AppConstants.cricApiKey}&id=$matchId';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] != 'success') return null;

        return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('CricAPI: Error fetching match score for $matchId: $e');
      return null;
    }
  }

  /// Performs the actual HTTP request
  Future<List<Map<String, dynamic>>> _performFetch() async {
    final String url =
        '$_baseUrl/currentMatches?apikey=${AppConstants.cricApiKey}&offset=0';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw CricApiException(
                'Request timeout after 10 seconds',
                type: CricApiErrorType.timeout,
              );
            },
          );

      // Track API usage
      ApiUsageTracker().recordCricApiCall(response.headers);

      // Handle HTTP errors
      if (response.statusCode != 200) {
        throw CricApiException(
          'HTTP ${response.statusCode}: ${response.body}',
          type: _getErrorTypeFromStatusCode(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      // Parse response
      final data = json.decode(response.body);

      // Check API response status
      if (data['status'] == 'failure') {
        throw CricApiException(
          'API returned failure: ${data['reason'] ?? 'Unknown reason'}',
          type: CricApiErrorType.apiError,
          apiReason: data['reason'],
        );
      }

      // Extract matches
      if (data['data'] == null) {
        debugPrint('CricAPI: No data field in response');
        return [];
      }

      final List<dynamic> matchesData = data['data'];
      final matches = matchesData.cast<Map<String, dynamic>>();

      // Validate match data
      final validMatches = matches.where(_isValidMatch).toList();

      if (validMatches.length < matches.length) {
        debugPrint(
          'CricAPI: Filtered out ${matches.length - validMatches.length} invalid matches',
        );
      }

      return validMatches;
    } on FormatException catch (e) {
      throw CricApiException(
        'Invalid JSON response: $e',
        type: CricApiErrorType.parseError,
      );
    } on http.ClientException catch (e) {
      throw CricApiException(
        'Network error: $e',
        type: CricApiErrorType.networkError,
      );
    }
  }

  /// Validates if a match object has required fields
  bool _isValidMatch(Map<String, dynamic> match) {
    return match['id'] != null &&
        match['name'] != null &&
        match['teams'] != null;
  }

  /// Determines if cache should be used
  bool _shouldUseCache() {
    if (_cachedMatches == null || _lastSuccessfulFetch == null) {
      return false;
    }

    final cacheAge = DateTime.now().difference(_lastSuccessfulFetch!);
    return cacheAge < _cacheValidDuration;
  }

  /// Checks if cache can be used as fallback (even if stale)
  bool _isCacheFallbackValid() {
    if (_cachedMatches == null || _lastSuccessfulFetch == null) {
      return false;
    }

    final cacheAge = DateTime.now().difference(_lastSuccessfulFetch!);
    return cacheAge < _cacheFallbackDuration;
  }

  /// Gets cache age as human-readable string
  String _getCacheAge() {
    if (_lastSuccessfulFetch == null) return 'unknown';

    final age = DateTime.now().difference(_lastSuccessfulFetch!);
    if (age.inMinutes < 1) {
      return '${age.inSeconds}s';
    } else if (age.inHours < 1) {
      return '${age.inMinutes}m';
    } else {
      return '${age.inHours}h ${age.inMinutes % 60}m';
    }
  }

  /// Maps HTTP status code to error type
  CricApiErrorType _getErrorTypeFromStatusCode(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return CricApiErrorType.authentication;
      case 429:
        return CricApiErrorType.rateLimited;
      case 500:
      case 502:
      case 503:
      case 504:
        return CricApiErrorType.serverError;
      default:
        return CricApiErrorType.httpError;
    }
  }

  /// Enhanced score extraction with better error handling
  /// Returns a map compatible with App's `actualScore` structure
  Map<String, dynamic>? extractScore(Map<String, dynamic> cricMatch) {
    try {
      if (cricMatch['score'] == null) {
        debugPrint('CricAPI: No score data for match ${cricMatch['id']}');
        return null;
      }

      // Validate score is a list
      if (cricMatch['score'] is! List) {
        debugPrint('CricAPI: Score is not a list for match ${cricMatch['id']}');
        return null;
      }

      final List<dynamic> scores = cricMatch['score'];

      if (scores.isEmpty) {
        debugPrint('CricAPI: Empty score list for match ${cricMatch['id']}');
        return null;
      }

      // Validate each score entry
      final validScores = scores.where((score) {
        return score is Map<String, dynamic> &&
            score['r'] != null &&
            score['inning'] != null;
      }).toList();

      if (validScores.isEmpty) {
        debugPrint(
          'CricAPI: No valid score entries for match ${cricMatch['id']}',
        );
        return null;
      }

      return {
        'scores': validScores,
        'status': cricMatch['status'] ?? 'Unknown',
        'matchType': cricMatch['matchType'] ?? 'Unknown',
        'tossWon': cricMatch['tossWon'],
        'tossDecision': cricMatch['tossDecision'],
        'venue': cricMatch['venue'],
        'date': cricMatch['date'],
      };
    } catch (e) {
      debugPrint(
        'CricAPI: Error extracting score for match ${cricMatch['id']}: $e',
      );
      return null;
    }
  }

  /// Clears the cache (useful for testing or manual refresh)
  void clearCache() {
    _cachedMatches = null;
    _lastSuccessfulFetch = null;
    _lastFetchAttempt = null;
    _consecutiveErrors = 0;
    _lastError = null;
    debugPrint('CricAPI: Cache cleared');
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'hasCachedData': _cachedMatches != null,
      'cachedMatchCount': _cachedMatches?.length ?? 0,
      'cacheAge': _getCacheAge(),
      'lastSuccessfulFetch': _lastSuccessfulFetch?.toIso8601String(),
      'lastFetchAttempt': _lastFetchAttempt?.toIso8601String(),
      'consecutiveErrors': _consecutiveErrors,
      'lastError': _lastError,
      'isCacheValid': _shouldUseCache(),
      'isCacheFallbackValid': _isCacheFallbackValid(),
    };
  }

  /// Finds a series ID by fuzzy name matching
  Future<String?> getSeriesIdByName(String searchName) async {
    try {
      final seriesList = await getSeriesList();
      if (seriesList.isEmpty) return null;

      final normalizedSearch = searchName.toLowerCase();

      // 1. Exact Match
      for (var s in seriesList) {
        if (s['name'].toString().toLowerCase() == normalizedSearch) {
          return s['id'];
        }
      }

      // 2. Contains Match
      for (var s in seriesList) {
        if (s['name'].toString().toLowerCase().contains(normalizedSearch)) {
          return s['id'];
        }
      }

      return null;
    } catch (e) {
      debugPrint('CricAPI: Error searching series ID: $e');
      return null;
    }
  }

  /// Gets service health status
  CricApiHealthStatus getHealthStatus() {
    if (_consecutiveErrors >= 3) {
      return CricApiHealthStatus.critical;
    } else if (_consecutiveErrors > 0) {
      return CricApiHealthStatus.degraded;
    } else if (_cachedMatches != null) {
      return CricApiHealthStatus.healthy;
    } else {
      return CricApiHealthStatus.unknown;
    }
  }
}

/// Custom exception for CricAPI errors
class CricApiException implements Exception {
  final String message;
  final CricApiErrorType type;
  final int? statusCode;
  final String? apiReason;

  CricApiException(
    this.message, {
    required this.type,
    this.statusCode,
    this.apiReason,
  });

  @override
  String toString() {
    final buffer = StringBuffer('CricApiException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (apiReason != null) buffer.write(' - API Reason: $apiReason');
    return buffer.toString();
  }
}

/// Types of errors that can occur
enum CricApiErrorType {
  networkError,
  timeout,
  authentication,
  rateLimited,
  serverError,
  httpError,
  parseError,
  apiError,
  maxRetriesExceeded,
  unknown,
}

/// Health status of the CricAPI service
enum CricApiHealthStatus { healthy, degraded, critical, unknown }
