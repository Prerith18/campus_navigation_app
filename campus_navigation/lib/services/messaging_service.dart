// lib/services/messaging_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point') // needed for Android background handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // System UI handles the background notification.
}

class MessagingService {
  MessagingService._();
  static final instance = MessagingService._();

  static const _androidChannelId = 'campus_general';
  static const _androidChannelName = 'General Notifications';

  Future<void> init() async {
    final fcm = FirebaseMessaging.instance;

    // 1) Ask permission (Android 13+ POST_NOTIFICATIONS; iOS alert/badge/sound)
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2) Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3) Local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
        description: 'Campus alerts and announcements',
      );
      await _local
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 4) Token save / refresh (optional but handy for debugging)
    await _saveToken();
    fcm.onTokenRefresh.listen((t) => _saveToken(token: t));

    // 5) Apply saved preference: subscribe/unsubscribe to topic "all"
    final enabled = await _loadNotificationPref();
    await applyNotificationPreference(enabled, persist: false);

    // 6) Foreground messages → show local heads-up
    FirebaseMessaging.onMessage.listen((msg) async {
      final n = msg.notification;
      if (n == null) return;
      await _local.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: msg.data['deeplink'],
      );
    });
  }

  /// Toggle notifications for this device.
  /// - Subscribes/unsubscribes to the broadcast topic 'all'
  /// - Persists preference under users/{uid}.settings.notificationsEnabled when signed in
  Future<void> applyNotificationPreference(bool enable, {bool persist = true}) async {
    final fcm = FirebaseMessaging.instance;

    try {
      if (enable) {
        await fcm.subscribeToTopic('all');
        debugPrint('FCM: subscribed to topic "all"');
      } else {
        await fcm.unsubscribeFromTopic('all');
        // Cancel any foreground local notifications to "silence" immediately.
        await _local.cancelAll();
        debugPrint('FCM: unsubscribed from topic "all"');
      }
    } catch (e) {
      debugPrint('FCM topic toggle failed: $e');
    }

    if (persist) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'settings': {'notificationsEnabled': enable}
        }, SetOptions(merge: true));
      }
    }
  }

  /// Show a local (heads-up) notification in foreground
  Future<void> showLocal({required String title, required String body}) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ---- internals ----

  Future<void> _saveToken({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    final t = token ?? await FirebaseMessaging.instance.getToken();
    if (t == null) return;

    if (user == null) {
      // Not signed in: nothing to persist server-side; that's fine.
      return;
    }

    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(t);

    await doc.set({
      'token': t,
      'platform': Platform.operatingSystem,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> _loadNotificationPref() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true; // default enabled when signed out
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      final settings = (data?['settings'] as Map?)?.cast<String, dynamic>();
      final enabled = settings?['notificationsEnabled'];
      if (enabled is bool) return enabled;
    } catch (_) {}
    return true; // default
  }
}
