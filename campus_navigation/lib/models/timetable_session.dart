// lib/models/timetable_session.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableSession {
  final String id;
  final String title;
  final String? moduleCode;
  final String? room;
  final Timestamp startTime; // stored as UTC
  final Timestamp endTime;   // stored as UTC
  final String locationName;
  final double lat;
  final double lng;
  final String? notes;

  TimetableSession({
    required this.id,
    required this.title,
    this.moduleCode,
    this.room,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.lat,
    required this.lng,
    this.notes,
  });

  factory TimetableSession.fromMap(String id, Map<String, dynamic> m) {
    return TimetableSession(
      id: id,
      title: (m['title'] ?? '') as String,
      moduleCode: m['moduleCode'] as String?,
      room: m['room'] as String?,
      startTime: m['startTime'] as Timestamp,
      endTime: m['endTime'] as Timestamp,
      locationName: (m['locationName'] ?? '') as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      notes: m['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    if (moduleCode != null && moduleCode!.isNotEmpty) 'moduleCode': moduleCode,
    if (room != null && room!.isNotEmpty) 'room': room,
    'startTime': startTime,
    'endTime': endTime,
    'locationName': locationName,
    'lat': lat,
    'lng': lng,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}
