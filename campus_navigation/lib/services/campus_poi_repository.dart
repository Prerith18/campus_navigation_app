import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_navigation/models/campus_poi.dart';

/// Firestore-backed repository for campus POIs (create, read, delete).
class CampusPoiRepository {
  CampusPoiRepository._();
  static final instance = CampusPoiRepository._();

  final _col = FirebaseFirestore.instance.collection('map_pois');

  /// Streams all active POIs and sorts them by `order` then `name`.
  Stream<List<CampusPoi>> streamAllActiveOrdered() {
    return _col
        .where('active', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      // Map documents to models and perform a client-side sort.
      final list = snap.docs
          .map((d) => CampusPoi.fromMap(d.id, d.data()))
          .toList();

      list.sort((a, b) {
        final c = a.order.compareTo(b.order);
        if (c != 0) return c;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  /// Creates or updates a POI document (auto ID when `poi.id` is empty).
  Future<void> upsert(CampusPoi poi) async {
    final doc = poi.id.isEmpty ? _col.doc() : _col.doc(poi.id);
    await doc.set(poi.toMap(), SetOptions(merge: true));
  }

  /// Deletes a POI document by its Firestore ID.
  Future<void> deleteById(String id) => _col.doc(id).delete();
}
