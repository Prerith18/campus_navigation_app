import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  static Future<void> ensureSubscribedToAllUsersTopic() async {
    // iOS: request permission (no-op on Android 13+; it shows its own prompt)
    await FirebaseMessaging.instance.requestPermission();

    // Subscribe once; it's idempotent
    await FirebaseMessaging.instance.subscribeToTopic('allUsers');
  }
}
