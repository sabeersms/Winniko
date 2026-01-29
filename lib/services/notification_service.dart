import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/match_model.dart';
import '../models/competition_model.dart';
import 'firestore_service.dart';

// Background handler must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to access other Firebase services in the background, initialize them here
  // await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('Handling a background message: ${message.messageId}');
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        debugPrint('User granted permission');
      }
    } else {
      if (kDebugMode) {
        debugPrint('User declined or has not accepted permission');
      }
      return;
    }

    // 2. Initialize Local Notifications (for foreground display)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Note: iOS setup requires more work in AppDelegate, assuming default for now or skipping specific iOS config if not requested.
    // For simplicity in this cross-platform snippet:
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (kDebugMode) {
          debugPrint('Notification tapped: ${response.payload}');
        }
      },
    );

    // 3. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
        }
        _showForegroundNotification(message);
      }
    });

    // 5. Get Token
    try {
      String? token;
      if (kIsWeb) {
        // On web, a VAPID key is required.
        // If we don't have one configured, we skip token retrieval to avoid console errors.
        const vapidKey = 'YOUR_VAPID_KEY_HERE';
        if (vapidKey == 'YOUR_VAPID_KEY_HERE') {
          if (kDebugMode) {
            debugPrint(
              'Web Notification: No VAPID key configured. Skipping token retrieval.',
            );
          }
        } else {
          try {
            token = await _firebaseMessaging.getToken(vapidKey: vapidKey);
          } catch (e) {
            // Suppress confusing "subscribe" errors if the key is invalid
            debugPrint(
              'Web Notification Warning: Failed to get token. (Check VAPID key)',
            );
          }
        }
      } else {
        token = await _firebaseMessaging.getToken();
      }

      if (kDebugMode) {
        debugPrint('FCM Token: $token');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  // Subscribe to a topic (e.g. for a specific competition)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  Future<void> scheduleMatchNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Schedule for 1 hour before
    final notificationTime = scheduledTime.subtract(const Duration(hours: 1));

    if (notificationTime.isBefore(DateTime.now())) return;

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'match_reminders',
          'Match Reminders',
          channelDescription: 'Notifications for upcoming matches',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelMatchNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<void> syncAllMatchNotifications(
    String userId,
    FirestoreService firestore,
  ) async {
    try {
      final List<CompetitionModel> competitions = await firestore
          .getJoinedCompetitions(userId)
          .first;

      for (var comp in competitions) {
        // 2. Get matches for each competition
        final List<MatchModel> matches = await firestore
            .getMatches(comp.id)
            .first;

        for (var match in matches) {
          if (match.status == 'Scheduled' || match.status == 'Upcoming') {
            final notificationId = match.id.hashCode;
            final matchTime = match.scheduledTime;

            if (matchTime.isAfter(DateTime.now())) {
              await scheduleMatchNotification(
                id: notificationId,
                title: 'Match Starting Soon! ⚽',
                body:
                    '${match.team1Name} vs ${match.team2Name} in ${comp.name} starts in 1 hour!',
                scheduledTime: matchTime,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing notifications: $e');
    }
  }
}
