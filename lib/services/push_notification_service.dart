import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/routing/app_routes.dart';

/// Handler pour les messages FCM reçus en arrière-plan / app terminée.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'dar_plus_general',
      'Notifications DAR PLUS',
      description: 'Notifications des messages, reservations et appels.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    Future<void> registerToken() async {
      final token = await FirebaseMessaging.instance.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }

    await registerToken();
    FirebaseAuth.instance.authStateChanges().listen((_) => registerToken());
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    });

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'DAR PLUS';
      final body = message.notification?.body ?? '';
      unawaited(_showLocal(title, body, message.data));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _scheduleNavigation(message.data);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _scheduleNavigation(initialMessage.data);
    }
  }

  Future<void> _showLocal(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'dar_plus_general',
      'Notifications DAR PLUS',
      channelDescription: 'Notifications des messages, reservations et appels.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _scheduleNavigation(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('Invalid notification payload: $error');
    }
  }

  void _scheduleNavigation(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_navigateForNotification(data));
    });
  }

  Future<void> _navigateForNotification(Map<String, dynamic> data) async {
    final navigator = AppRoutes.navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;

    final type = data['type']?.toString();
    final bookingId = data['bookingId']?.toString() ?? '';
    try {
      if (type == 'payment' || type == 'payment_received') {
        await navigator.pushNamed(AppRoutes.paymentHistory);
        return;
      }

      if ((type == 'chat' ||
              type == 'booking' ||
              type == 'booking_review_received') &&
          bookingId.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();
        final booking = snapshot.data();
        if (snapshot.exists && booking != null) {
          final route = type == 'chat'
              ? AppRoutes.bookingChat
              : AppRoutes.bookingDetail;
          await navigator.pushNamed(
            route,
            arguments: {...booking, 'id': snapshot.id},
          );
          return;
        }
      }

      await navigator.pushNamed(AppRoutes.bookings);
    } catch (error, stackTrace) {
      debugPrint('Unable to open notification destination: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
