import 'package:firebase_messaging/firebase_messaging.dart';

/// Ensure this device can receive push alerts: request permission (where needed)
/// and subscribe once to the global "allUsers" topic.
class PushService {
  static Future<void> ensureSubscribedToAllUsersTopic() async {
    // Request notification permission on platforms that need it, then subscribe.
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.subscribeToTopic('allUsers');
  }
}
