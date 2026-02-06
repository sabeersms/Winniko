import 'package:flutter/material.dart';
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
import 'widgets/loading_spinner.dart';
// import 'screens/waiting_verification_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check (Debug)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.appAttest,
    webProvider: ReCaptchaV3Provider('pass-key'),
  );

  // Initialize Notifications
  final notificationService = NotificationService();
  notificationService.initialize();

  // Initialize Network Service
  NetworkService().initialize();

  // Initialize Ads
  await AdService().initialize();

  runApp(WinnikoApp(notificationService: notificationService));
}

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
        home: const AuthWrapper(),
        routes: {'/privacy-policy': (context) => const PrivacyPolicyScreen()},
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            // Check if first run
            return FutureBuilder<bool>(
              future: _checkFirstRun(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data == true
                      ? const SignupScreen()
                      : const LoginScreen();
                }
                return const Scaffold(
                  body: Center(
                    child: LoadingSpinner(color: AppColors.accentGreen),
                  ),
                );
              },
            );
          } else {
            // Email verification check (Disabled)
            // if (!authService.isEmailVerified) {
            //   return const WaitingVerificationScreen();
            // }
            return const HomeScreen();
          }
        }
        return const Scaffold(
          body: Center(child: LoadingSpinner(color: AppColors.accentGreen)),
        );
      },
    );
  }

  Future<bool> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if not set
    bool isFirstRun = prefs.getBool('is_first_run') ?? true;
    if (isFirstRun) {
      // Mark as seen so next time it goes to Login (unless they sign up, which logs them in)
      // Actually, if they don't sign up and close app, we probably still want Signup?
      // User request: "1st open signup screen, if user did not signup ever."
      // If they explicitly go to Login, we should remember that?
      // For now, let's strictly follow: "if user did not signup ever" -> implies no account.
      // But standard UX is: Show Signup. If they click "Login", show Login.
      // We will leave 'is_first_run' as is until they successfully sign up or we might toggle it elsewhere.
      // But to prevent stuck on Signup, usually we set it to false once shown?
      // Let's keep it simple: defaulting to SignupScreen for null user if no pref set.
      // NOTE: We should set it to false somewhere if we want to default to Login later.
      // For now, we only read it.
      await prefs.setBool('is_first_run', false);
    }
    return isFirstRun;
  }
}
