// lib/services/stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsService {
  /// Call this when a trip completes. Pass distance in km.
  static Future<void> addTrip({required double distanceKm}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('main');

    await ref.set({
      'tripsCompleted': FieldValue.increment(1),
      'distanceKm': FieldValue.increment(distanceKm),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
