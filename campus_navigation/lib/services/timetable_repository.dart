// Firestore repository for timetable bundles and their sessions.
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_bundle.dart';
import '../models/timetable_session.dart';

class TimetableRepository {
  TimetableRepository._();
  static final instance = TimetableRepository._();

  final _bundles = FirebaseFirestore.instance.collection('timetableBundles');

  // Live list of all bundles (newest first).
  Stream<List<TimetableBundle>> streamBundles() {
    return _bundles
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
        s.docs.map((d) => TimetableBundle.fromMap(d.id, d.data())).toList());
  }

  // The currently published bundle, or null if none.
  Stream<TimetableBundle?> streamPublishedBundle() {
    return _bundles
        .where('published', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
        ? null
        : TimetableBundle.fromMap(s.docs.first.id, s.docs.first.data()));
  }

  // Create a new draft bundle and return its document id.
  Future<String> createBundle(String name) async {
    final now = Timestamp.now();
    final ref = await _bundles.add({
      'name': name,
      'published': false,
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  // Update bundle fields (copyWith bumps updatedAt).
  Future<void> updateBundle(TimetableBundle b) {
    return _bundles.doc(b.id).update(b.copyWith().toMap());
  }

  // Delete a bundle and its sessions in a single batch.
  Future<void> deleteBundle(String id) async {
    final batch = FirebaseFirestore.instance.batch();
    final sess = await _bundles.doc(id).collection('sessions').get();
    for (final d in sess.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_bundles.doc(id));
    await batch.commit();
  }

  // Make exactly one bundle published; unpublish all others.
  Future<void> publishBundle(String id) async {
    final now = Timestamp.now();
    final all = await _bundles.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final d in all.docs) {
      final ref = _bundles.doc(d.id);
      batch.update(ref, {
        'published': d.id == id,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }


  // Live sessions for a bundle ordered by start time.
  Stream<List<TimetableSession>> streamSessions(String bundleId) {
    return _bundles
        .doc(bundleId)
        .collection('sessions')
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs
        .map((d) => TimetableSession.fromMap(d.id, d.data()))
        .toList());
  }

  // Create or update a session under a bundle (auto ID if empty).
  Future<void> upsertSession(String bundleId, TimetableSession s) async {
    final col = _bundles.doc(bundleId).collection('sessions');
    if (s.id.isEmpty) {
      await col.add(s.toMap());
    } else {
      await col.doc(s.id).set(s.toMap(), SetOptions(merge: true));
    }
  }

  // Remove a single session from a bundle.
  Future<void> deleteSession(String bundleId, String sessionId) {
    return _bundles.doc(bundleId).collection('sessions').doc(sessionId).delete();
  }

  // Today's sessions from the published bundle (local day → UTC range).
  Stream<List<TimetableSession>> streamTodayFromPublished(
      {required DateTime localNow}) {
    final localStart = DateTime(localNow.year, localNow.month, localNow.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = Timestamp.fromDate(localStart.toUtc());
    final endUtc = Timestamp.fromDate(localEnd.toUtc());

    return streamPublishedBundle().asyncExpand((bundle) {
      if (bundle == null) return Stream.value(<TimetableSession>[]);
      return _bundles
          .doc(bundle.id)
          .collection('sessions')
          .where('startTime', isGreaterThanOrEqualTo: startUtc)
          .where('startTime', isLessThan: endUtc)
          .orderBy('startTime')
          .snapshots()
          .map((s) => s.docs
          .map((d) => TimetableSession.fromMap(d.id, d.data()))
          .toList());
    });
  }
}
