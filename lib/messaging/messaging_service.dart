import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_service.dart';

/// Background/terminated FCM handler. Must be a top-level (or static) function
/// annotated with `@pragma('vm:entry-point')`. We send a `notification` payload
/// from the Cloud Functions, so the OS renders the system-tray notification
/// itself — nothing to do here beyond existing.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wires Firebase Cloud Messaging into the app:
/// - creates the Android notification channel (matches the manifest default),
/// - shows foreground messages as a heads-up banner via local notifications,
/// - registers/refreshes this device's push token under the signed-in user.
///
/// Token lifecycle: [registerForUser] saves on sign-in/approval; [onTokenRefresh]
/// keeps it current; `AuthService.signOut` removes it. Cloud Functions read
/// `/fcm_tokens/{uid}` (Admin SDK) to target a user or all admins.
class MessagingService {
  MessagingService({AuthService? authService})
      : _auth = authService ?? AuthService();

  final AuthService _auth;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Channel id MUST match the manifest's
  /// `com.google.firebase.messaging.default_notification_channel_id`.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'door_default',
    'إشعارات البوابة',
    description: 'إشعارات الموافقة والطلبات الجديدة',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// One-time setup. Safe to call more than once. Run after `Firebase.init`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings:
          const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App in foreground: FCM does NOT auto-display, so render it ourselves.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Token rotation: persist the fresh token for whoever is signed in.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) unawaited(_auth.saveFcmToken(uid, token));
    });
  }

  /// Request permission (Android 13+/iOS) and save this device's token for
  /// [uid]. Called once an authenticated user is present (even while pending —
  /// they need the approval notification). No-op if the user denies permission.
  Future<void> registerForUser(String uid) async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _auth.saveFcmToken(uid, token);
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
