import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/payment_service.dart';
import 'services/notification_service.dart';
import 'services/network_service.dart';
import 'services/ad_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signup_screen.dart'; // import signup screen
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/splash_screen.dart';
// import 'screens/waiting_verification_screen.dart';
import 'firebase_options.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
    webProvider: ReCaptchaV3Provider('pass-key'),
  );

  // --- TEMPORARY LEADERBOARD REFRESH ---
  try {
    final db = FirebaseFirestore.instance;
    final fs = FirestoreService();
    final leagueId = 'mens-t20-world-cup-2026';

    // Check if we already ran it
    final metaDoc = await db
        .collection('app_metadata')
        .doc('t20_leaderboard_refresh5')
        .get();
    if (!metaDoc.exists) {
      debugPrint(
        '🔄 SCRUBBING ALL DUMMY MATCHES AND REFRESHING LEADERBOARDS... 🔄',
      );

      final compsSnap = await db
          .collection('competitions')
          .where('leagueId', isEqualTo: leagueId)
          .get();

      int cleanedCount = 0;

      // 1. Scrub Hard Copy
      final hardDocs = await db
          .collection('official_leagues')
          .doc(leagueId)
          .collection('matches')
          .get();
      for (var doc in hardDocs.docs) {
        final data = doc.data();
        if (data['actualScore'] != null ||
            (data['status'] != 'upcoming' && data['status'] != 'scheduled')) {
          await doc.reference.update({
            'actualScore': null,
            'status': 'upcoming',
            'winnerId': null,
          });
        }
      }

      for (var comp in compsSnap.docs) {
        // 2. Scrub Competition Matches
        final compMatchesSnap = await db
            .collection('competitions')
            .doc(comp.id)
            .collection('matches')
            .get();
        for (var doc in compMatchesSnap.docs) {
          final data = doc.data();
          if (data['actualScore'] != null ||
              (data['status'] != 'upcoming' && data['status'] != 'scheduled')) {
            await doc.reference.update({
              'actualScore': null,
              'status': 'upcoming',
              'winnerId': null,
            });
            cleanedCount++;
          }
        }

        // 3. Recalculate correctly!
        await fs.recalculateStandings(comp.id);
        debugPrint('✅ Refreshed Standings for: \${comp.id}');
      }

      // Record completion so we never run this again
      await db.collection('app_metadata').doc('t20_leaderboard_refresh5').set({
        'ran': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '🎉 ALL $cleanedCount SCORING BUGS WIPED AND STANDINGS REFRESHED! 🎉',
      );
    }
  } catch (e) {
    debugPrint('Error refreshing standings: $e');
  }

  // Initialize Notifications
  final notificationService = NotificationService();
  notificationService.initialize();

  // Initialize Network Service
  NetworkService().initialize();

  // Initialize Ads
  await AdService().initialize();

  runApp(WinnikoApp(notificationService: notificationService));
}

// Global RouteObserver for detecting navigation events
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class WinnikoApp extends StatelessWidget {
  final NotificationService notificationService;

  const WinnikoApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PaymentService>(create: (_) => PaymentService()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<NetworkService>(create: (_) => NetworkService()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        home: const AuthWrapper(),
        routes: {'/privacy-policy': (context) => const PrivacyPolicyScreen()},
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    _startMinSplashTimer();
  }

  void _startMinSplashTimer() {
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _minTimeElapsed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show splash until snapshot is active AND minimum time has elapsed
        if (snapshot.connectionState == ConnectionState.active &&
            _minTimeElapsed) {
          final user = snapshot.data;
          if (user == null) {
            return FutureBuilder<bool>(
              future: _checkFirstRun(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data == true
                      ? const SignupScreen()
                      : const LoginScreen();
                }
                return const SplashScreen();
              },
            );
          } else {
            authService.registerAdminUidIfNeeded();
            return const HomeScreen();
          }
        }
        return const SplashScreen();
      },
    );
  }

  Future<bool> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstRun = prefs.getBool('is_first_run') ?? true;
    if (isFirstRun) {
      await prefs.setBool('is_first_run', false);
    }
    return isFirstRun;
  }
}
