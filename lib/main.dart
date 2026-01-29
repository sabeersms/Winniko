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
            return const LoginScreen();
          } else {
            // Email verification check disabled for simplified signup
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
}
