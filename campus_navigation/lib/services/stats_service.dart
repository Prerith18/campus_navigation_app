import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stores simple per-user usage stats in Firestore.
class StatsService {
  // Adds one completed trip and increments total distance (in km) for the signed-in user.
  static Future<void> addTrip({required double distanceKm}) async {
    // If no user is signed in, there's nothing to record.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Point to users/{uid}/stats/main where we keep aggregate counters.
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('main');

    // Merge counters and update the timestamp.
    await ref.set({
      'tripsCompleted': FieldValue.increment(1),
      'distanceKm': FieldValue.increment(distanceKm),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
