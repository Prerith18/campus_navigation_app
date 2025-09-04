import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_navigation/models/campus_poi.dart';

class CampusPoiRepository {
  CampusPoiRepository._();
  static final instance = CampusPoiRepository._();

  final _col = FirebaseFirestore.instance.collection('map_pois');

  Stream<List<CampusPoi>> streamAllActiveOrdered() {
    return _col
        .where('active', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs
          .map((d) => CampusPoi.fromMap(d.id, d.data()))
          .toList();

      // Client sort: by order, then by name
      list.sort((a, b) {
        final c = a.order.compareTo(b.order);
        if (c != 0) return c;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Future<void> upsert(CampusPoi poi) async {
    final doc = poi.id.isEmpty ? _col.doc() : _col.doc(poi.id);
    await doc.set(poi.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteById(String id) => _col.doc(id).delete();
}
