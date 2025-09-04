// lib/models/timetable_bundle.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableBundle {
  final String id;
  final String name;
  final bool published;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? validFrom;
  final Timestamp? validTo;
  final String? notes;

  TimetableBundle({
    required this.id,
    required this.name,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
    this.validFrom,
    this.validTo,
    this.notes,
  });

  factory TimetableBundle.fromMap(String id, Map<String, dynamic> m) {
    return TimetableBundle(
      id: id,
      name: (m['name'] ?? '') as String,
      published: (m['published'] ?? false) as bool,
      createdAt: (m['createdAt'] as Timestamp?) ?? Timestamp.now(),
      updatedAt: (m['updatedAt'] as Timestamp?) ?? Timestamp.now(),
      validFrom: m['validFrom'] as Timestamp?,
      validTo: m['validTo'] as Timestamp?,
      notes: m['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'published': published,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (validFrom != null) 'validFrom': validFrom,
    if (validTo != null) 'validTo': validTo,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
  };

  TimetableBundle copyWith({
    String? name,
    bool? published,
    Timestamp? validFrom,
    Timestamp? validTo,
    String? notes,
  }) =>
      TimetableBundle(
        id: id,
        name: name ?? this.name,
        published: published ?? this.published,
        createdAt: createdAt,
        updatedAt: Timestamp.now(),
        validFrom: validFrom ?? this.validFrom,
        validTo: validTo ?? this.validTo,
        notes: notes ?? this.notes,
      );
}
