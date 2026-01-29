import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/network_service.dart';
import '../models/competition_model.dart';
import '../models/user_model.dart';
// Keep for search results or vertical lists if needed
import '../widgets/mini_competition_card.dart';
import '../widgets/loading_spinner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import 'competition_detail_screen.dart';
import 'competition_create_screen.dart';
import 'organizer_dashboard_screen.dart';
import '../utils/web_utils.dart'; // Abstraction for PWA
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  UserModel? _currentUser;
  bool _isLoading = true;

  Timer? _pwaCheckTimer;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  late Stream<List<CompetitionModel>> _allCompetitionsStream;

  // Search State
  Timer? _debounce;
  List<CompetitionModel>? _searchResults;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Initialize stream ONCE to prevent rebuilding/blinking
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _allCompetitionsStream = firestoreService.getAllCompetitions();

    _loadUserProfile();
    if (kIsWeb) {
      _startPwaCheck();
      _checkAndShowPromotion();
    }
    // Mobile Ad
    if (!kIsWeb) {
      _bannerAd = AdService().createBannerAd(
        onAdLoaded: () {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
      )..load();
    }
  }

  void _startPwaCheck() {
    // Check every 2 seconds for 10 seconds effectively
    _pwaCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isPwaInstallAvailable()) {
        if (mounted) {
          setState(() {
            // Rebuild to show the button
          });
        }
        timer.cancel(); // Found it, stop checking
      } else if (timer.tick > 10) {
        timer.cancel(); // Give up after 20 seconds
      }
    });
  }

  Future<void> _checkAndShowPromotion() async {
    try {
      if (isRunningStandalone()) {
        debugPrint('App is running in standalone mode, skipping promotion.');
        return;
      }

      // Show every time on web browser
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _showPromotionPopup();
        }
      });
    } catch (e) {
      debugPrint('Error checking promotion: $e');
    }
  }

  void _showPromotionPopup() {
    showDialog(
      context: context,
      builder: (context) {
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  height: 40,
                  width: 40,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Get the Full Experience',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAndroid
                    ? 'Download our official Android app for a smoother tournament experience and instant notifications!'
                    : isIOS
                    ? 'For the best experience, add Winniko to your Home Screen!'
                    : 'Experience Winniko as a native app on your device!',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (isIOS) ...[
                const SizedBox(height: 16),
                _buildInstructionStep(
                  '1',
                  'Tap the Share button below',
                  Icons.ios_share,
                ),
                const SizedBox(height: 8),
                _buildInstructionStep(
                  '2',
                  'Scroll down and tap "Add to Home Screen"',
                  Icons.add_box_outlined,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (isAndroid)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.winniko.winniko',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.android, color: Colors.black),
                label: const Text(
                  'Get on Play Store',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                ),
              )
            else if (isIOS)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (isPwaInstallAvailable()) {
                    showPwaInstallPrompt();
                  } else {
                    // Fallback: show instructions inline or just close
                    // Since this is a minor case, let's just close for now
                    // or keep it simple
                    debugPrint('PWA Install not available as fallback');
                  }
                },
                child: const Text('Install App'),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pwaCheckTimer?.cancel();
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId != null) {
      await authService.syncUserProfile();
      if (mounted) {
        setState(() {
          _currentUser = authService.currentUserModel;
          _isLoading = false;
        });

        // Sync Notifications
        final notificationService = Provider.of<NotificationService>(
          context,
          listen: false,
        );
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        notificationService.syncAllMatchNotifications(userId, firestoreService);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILDING HOMESCREEN with index $_currentIndex');
    final authService = Provider.of<AuthService>(context);
    // ignore: unused_local_variable
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If not on Home tab or Search is active, go back to Home/Clear Search
        if (_isSearching ||
            _searchController.text.isNotEmpty ||
            _currentIndex != 0) {
          setState(() {
            if (_isSearching || _searchController.text.isNotEmpty) {
              _searchController.clear();
              _isSearching = false;
              _searchResults = null;
            } else {
              _currentIndex = 0;
            }
          });
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text(
              'Exit App?',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'Do you want to close Winniko?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.accentGreen),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        drawer: AppDrawer(user: authService.currentUserModel),
        appBar: _currentIndex == 1
            ? null
            : AppBar(
                actions: [
                  if (kIsWeb && !isRunningStandalone())
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: _showPromotionPopup,
                        icon: const Icon(
                          Icons.download,
                          size: 16,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'Install App',
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                ],
                title: Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        height: 32,
                        width: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(AppConstants.appName),
                  ],
                ),
              ),
        body: _isLoading
            ? const Center(child: LoadingSpinner(color: AppColors.accentGreen))
            : IndexedStack(
                index: _currentIndex,
                children: [
                  // Tab 0: Home (New Layout)
                  _buildHomeTab(),
                  // Tab 1: My Competitions
                  MyCompetitionsScreen(
                    key: const ValueKey('my_competitions_tab'),
                    organizerId: authService.currentUserId ?? '',
                  ),
                  // Tab 2: Create Competition
                  _buildCreateTab(),
                ],
              ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAdLoaded && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: AppColors.cardBackground,
              selectedItemColor: AppColors.accentGreen,
              unselectedItemColor: AppColors.textSecondary,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events),
                  label: 'My Competitions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Create',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _runSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = null;
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);
      try {
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        final results = await firestoreService.searchCompetitions(query);

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        // Offline Indicator
        StreamBuilder<NetworkStatus>(
          stream: Provider.of<NetworkService>(context).networkStatusStream,
          initialData: NetworkStatus.online,
          builder: (context, snapshot) {
            if (snapshot.data == NetworkStatus.offline) {
              return Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Offline Mode - Showing Cached Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Search Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: AppColors.backgroundDark,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardColor),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by Name or Code...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.accentGreen,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _runSearch,
            ),
          ),
        ),

        Expanded(
          child: _searchController.text.isNotEmpty
              ? _buildSearchResults()
              : StreamBuilder<List<CompetitionModel>>(
                  stream: _allCompetitionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: LoadingSpinner(color: AppColors.accentGreen),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final allCompetitions = snapshot.data ?? [];

                    // Apply Search Filter
                    final query = _searchController.text.toLowerCase().trim();
                    final filteredCompetitions = allCompetitions.where((comp) {
                      if (query.isEmpty) return true;
                      return comp.name.toLowerCase().contains(query) ||
                          comp.joinCode.toLowerCase().contains(query);
                    }).toList();

                    // Categorize
                    final majorTournaments = filteredCompetitions
                        .where(
                          (c) => c.leagueId != null && c.leagueId!.isNotEmpty,
                        )
                        .toList();
                    final singleMatchContests = filteredCompetitions
                        .where(
                          (c) => c.format == AppConstants.formatSingleMatch,
                        )
                        .toList();
                    // Custom = Not Major AND Not Single Match
                    final customTournaments = filteredCompetitions
                        .where(
                          (c) =>
                              (c.leagueId == null || c.leagueId!.isEmpty) &&
                              c.format != AppConstants.formatSingleMatch,
                        )
                        .toList();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ROW 1: Major Tournaments
                          if (majorTournaments.isNotEmpty) ...[
                            _buildSectionHeader('Major Tournaments'),
                            _buildHorizontalList(majorTournaments),
                            const SizedBox(height: 24),
                          ],

                          // ROW 2: Custom Tournaments
                          if (customTournaments.isNotEmpty) ...[
                            _buildSectionHeader('Custom Tournaments'),
                            _buildHorizontalList(customTournaments),
                            const SizedBox(height: 24),
                          ],

                          // ROW 3: Single Match Contests
                          if (singleMatchContests.isNotEmpty) ...[
                            _buildSectionHeader('Single Match Contests'),
                            _buildHorizontalList(singleMatchContests),
                            const SizedBox(height: 24),
                          ],

                          if (filteredCompetitions.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      query.isEmpty
                                          ? 'No competitions found'
                                          : 'No results for "$query"',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: LoadingSpinner(color: AppColors.accentGreen));
    }

    if (_searchResults == null || _searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No competitions found for "${_searchController.text}"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final competition = _searchResults![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: MiniCompetitionCard(
            competition: competition,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CompetitionDetailScreen(competitionId: competition.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<CompetitionModel> competitions) {
    return SizedBox(
      height: 120, // Reduced by 25% (150 -> 120) for compact layout
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: competitions.length,
        itemBuilder: (context, index) {
          final competition = competitions[index];
          return MiniCompetitionCard(
            competition: competition,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CompetitionDetailScreen(competitionId: competition.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCreateTab() {
    if (_currentUser == null) {
      return const Center(
        child: Text(
          "Please sign in to create competitions",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 80,
              color: AppColors.accentGreen,
            ),
            const SizedBox(height: 24),
            const Text(
              "Create a New Competition",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Host your own tournament, invite friends, and manage matches easily.",
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SimpleDialog(
                        title: const Text('Select Competition Type'),
                        backgroundColor: AppColors.cardBackground,
                        titleTextStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompetitionCreateScreen(
                                    organizerId: _currentUser!.id,
                                    organizerName: _currentUser!.name,
                                    organizerLocation: _currentUser!.location,
                                    isPublic: false,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Custom Tournament',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.lightGreenAccent,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Create Your Own',
                                        style: TextStyle(
                                          color: Colors.lightGreenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Setup teams, matches and rules manually.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(color: AppColors.dividerColor),
                          SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompetitionCreateScreen(
                                    organizerId: _currentUser!.id,
                                    organizerName: _currentUser!.name,
                                    organizerLocation: _currentUser!.location,
                                    isPublic: true,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Major Tournaments',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Select from official leagues like Premier League, La Liga, World Cup, etc.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  "Start Creating",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accentGreen,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
        Icon(icon, color: AppColors.textSecondary, size: 20),
      ],
    );
  }
}
