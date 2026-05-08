import 'package:techxpark/theme/app_colors.dart';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/* -------------------------------------------------------------------------- */
/* 🔔 BACKGROUND MESSAGE HANDLER — Must be a top-level function                */
/* -------------------------------------------------------------------------- */
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint(
    '📬 [FCM Background] ${message.notification?.title}: ${message.notification?.body}',
  );
}

/* -------------------------------------------------------------------------- */
/* 🔔 NOTIFICATION SERVICE                                                     */
/* -------------------------------------------------------------------------- */
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Notification IDs (unique per reminder type) ─────────────────────────
  static const _channelId = 'techxpark_channel';
  static const _channelName = 'TechXPark Notifications';

  static const int _idExpiry10 = 1001;
  static const int _idStartReminder30 = 1002;
  static const int _idStartReminder5 = 1003;

  // ─── Global navigation key (set from main.dart) ─────────────────────────
  static GlobalKey<NavigatorState>? navigatorKey;

  // ═══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      provisional: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notifications permission denied');
    }

    // 2. Initialize flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 3. Create high-importance notification channel (Android)
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Parking bookings, reminders, and offers.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
    }

    // 4. Register background FCM handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 5. Foreground FCM listener
    FirebaseMessaging.onMessage.listen(_showFcmAsLocal);

    // 6. Notification tap (app in background, not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('📲 [FCM Tapped] ${message.data}');
      _handleMessageTap(message);
    });

    // 6b. Notification tap (app terminated/cold start)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📲 [FCM Tapped Cold Start] ${initialMessage.data}');
      Future.delayed(const Duration(milliseconds: 1500), () {
        _handleMessageTap(initialMessage);
      });
    }

    // 7. Save FCM token
    await saveTokenToFirestore();

    // 8. Listen for token refresh
    _fcm.onTokenRefresh.listen((_) => saveTokenToFirestore());

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FCM TOKEN → FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> saveTokenToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await _fcm.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      debugPrint('🔑 FCM Token saved: $token');
    } catch (e) {
      debugPrint('⚠️ Token save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PERSIST NOTIFICATION TO FIRESTORE (INBOX)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _persistToFirestore({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Persist notification error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FOREGROUND FCM → LOCAL NOTIFICATION
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showFcmAsLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint('🔔 [FCM Foreground] ${notification.title}');
    final type = message.data['type'] as String? ?? 'general';

    await _persistToFirestore(
      title: notification.title ?? '',
      body: notification.body ?? '',
      type: type,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _notifDetails(color: const Color(0xFF1B75BC)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SCHEDULE ALL BOOKING REMINDERS
  // ═══════════════════════════════════════════════════════════════════════════
  /// Call this right after booking creation. Schedules 3 reminders:
  ///  - 30 min before START
  ///  - 5 min before START
  ///  - 10 min before END (expiry)
  Future<void> scheduleAllBookingReminders({
    required DateTime startTime,
    required DateTime endTime,
    required String slotName,
    required String parkingName,
  }) async {
    final now = DateTime.now();

    // ── 30 min before START ─────────────────────────────────────────────────
    final start30 = startTime.subtract(const Duration(minutes: 30));
    if (start30.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        id: _idStartReminder30,
        title: '🅿️ Booking Reminder',
        body:
            'Your parking at $parkingName starts in 30 minutes. Slot: $slotName',
        scheduledDate: tz.TZDateTime.from(start30, tz.local),
        notificationDetails: _notifDetails(color: AppColors.primary),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('⏰ 30-min start reminder scheduled: $start30');
    }

    // ── 5 min before START ──────────────────────────────────────────────────
    final start5 = startTime.subtract(const Duration(minutes: 5));
    if (start5.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        id: _idStartReminder5,
        title: '🚗 Almost Time!',
        body:
            'Your parking at $parkingName starts in 5 minutes. Head to slot $slotName!',
        scheduledDate: tz.TZDateTime.from(start5, tz.local),
        notificationDetails: _notifDetails(color: const Color(0xFFF59E0B)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('⏰ 5-min start reminder scheduled: $start5');
    }

    // ── 10 min before END (expiry) ──────────────────────────────────────────
    final end10 = endTime.subtract(const Duration(minutes: 10));
    if (end10.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        id: _idExpiry10,
        title: '⏳ Parking Ending Soon',
        body:
            'Your slot $slotName at $parkingName expires in 10 minutes. Move your car!',
        scheduledDate: tz.TZDateTime.from(end10, tz.local),
        notificationDetails: _notifDetails(color: const Color(0xFFE53935)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('⏰ 10-min expiry reminder scheduled: $end10');
    }
  }

  /// Cancel ALL booking-related scheduled reminders (for booking cancel or extension).
  Future<void> cancelAllBookingReminders() async {
    await _localNotifications.cancel(id: _idStartReminder30);
    await _localNotifications.cancel(id: _idStartReminder5);
    await _localNotifications.cancel(id: _idExpiry10);
    debugPrint('🗑️ All booking reminders cancelled');
  }

  /// Reschedule: cancels all, then re-schedules with new times.
  Future<void> rescheduleBookingReminders({
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String slotName,
    required String parkingName,
  }) async {
    await cancelAllBookingReminders();
    await scheduleAllBookingReminders(
      startTime: newStartTime,
      endTime: newEndTime,
      slotName: slotName,
      parkingName: parkingName,
    );
    debugPrint('♻️ Booking reminders rescheduled');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SHOW INSTANT LOCAL NOTIFICATION + PERSIST
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> showLocal({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await _persistToFirestore(title: title, body: body, type: type);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: _notifDetails(color: const Color(0xFF1B75BC)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  NotificationDetails _notifDetails({Color color = const Color(0xFF1B75BC)}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: color,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // Navigate to notifications screen if navigator key is set
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed('/notifications');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HANDLE BACKGROUND/TERMINATED NOTIFICATION TAP
  // ═══════════════════════════════════════════════════════════════════════════
  void _handleMessageTap(RemoteMessage message) {
    if (navigatorKey?.currentState == null) return;

    final type = message.data['type'] as String?;
    if (type == null) return;

    final nav = navigatorKey!.currentState!;

    switch (type) {
      case 'booking':
      case 'payment':
        nav.pushNamed('/my_bookings');
        break;
      case 'expiry':
        nav.pushNamed('/active_parking');
        break;
      case 'slot':
        nav.pushNamed('/slot_selection');
        break;
      case 'chat':
      case 'message':
        nav.pushNamed('/messages');
        break;
      default:
        nav.pushNamed('/notifications');
    }
  }
}

/* -------------------------------------------------------------------------- */
/* 📦 CONVENIENCE SHORTCUTS                                                    */
/* -------------------------------------------------------------------------- */

/// Call after booking is confirmed: shows notification + schedules all reminders
Future<void> notifyBookingConfirmed({
  required String slotName,
  required String parkingName,
  required DateTime startTime,
  required DateTime endTime,
}) async {
  // 1. Instant "Booking Confirmed" notification
  await NotificationService.instance.showLocal(
    title: '🅿️ Booking Confirmed',
    body:
        'Your parking slot $slotName at $parkingName has been reserved successfully.',
    type: 'booking',
  );

  // 2. Schedule all reminders (30-min, 5-min before start + 10-min before end)
  await NotificationService.instance.scheduleAllBookingReminders(
    startTime: startTime,
    endTime: endTime,
    slotName: slotName,
    parkingName: parkingName,
  );
}

/// Show a "Payment Successful" notification
Future<void> notifyPaymentSuccess(String amount) async {
  await NotificationService.instance.showLocal(
    title: '💳 Payment Successful',
    body: 'Your payment of $amount has been processed.',
    type: 'payment',
  );
}

/// Show a "Slot Available" notification
Future<void> notifySlotAvailable(String parkingName) async {
  await NotificationService.instance.showLocal(
    title: '🚗 Slot Available!',
    body: 'A parking slot just opened at $parkingName. Book now!',
    type: 'slot',
  );
}
