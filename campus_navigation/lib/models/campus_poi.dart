import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simple POI model used by the map/carousel with Firestore (de)serialization.
class CampusPoi {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String imageUrl;

  final String? address;
  final String? phone;
  final String? website;
  final Map<String, String> hours;
  final bool isOpenNow;
  final String closesAt;
  final int order;
  final bool active;
  final String? category;

  const CampusPoi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.imageUrl,
    this.address,
    this.phone,
    this.website,
    this.hours = const {},
    this.isOpenNow = true,
    this.closesAt = '',
    this.order = 0,
    this.active = true,
    this.category,
  });

  /// Convenience pair for Google Maps widgets.
  LatLng get latLng => LatLng(lat, lng);

  /// Serialize to a Firestore-friendly map.
  Map<String, dynamic> toMap() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'imageUrl': imageUrl,
    'address': address,
    'phone': phone,
    'website': website,
    'hours': hours,
    'isOpenNow': isOpenNow,
    'closesAt': closesAt,
    'order': order,
    'active': active,
    'category': category,
  };

  /// Rehydrate a POI from a Firestore document.
  factory CampusPoi.fromMap(String id, Map<String, dynamic> m) => CampusPoi(
    id: id,
    name: (m['name'] ?? '') as String,
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    imageUrl: (m['imageUrl'] ?? '') as String,
    address: m['address'] as String?,
    phone: m['phone'] as String?,
    website: m['website'] as String?,
    hours: (m['hours'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        const {},
    isOpenNow: (m['isOpenNow'] ?? true) as bool,
    closesAt: (m['closesAt'] ?? '') as String,
    order: (m['order'] ?? 0) as int,
    active: (m['active'] ?? true) as bool,
    category: m['category'] as String?,
  );
}
