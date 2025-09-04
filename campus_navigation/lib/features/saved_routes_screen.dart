// lib/features/saved_routes_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  static const _maxSlots = 3;

  // Reuse your existing Maps key; consider moving to a config file.
  static const String _apiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";

  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('users').doc(uid).collection('savedRoutes');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Routes')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('order').snapshots(),
        builder: (context, snap) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          // Find the doc for each slot index without returning null from a mapper.
          QueryDocumentSnapshot<Map<String, dynamic>>? _docForIndex(int i) {
            for (final d in docs) {
              final data = d.data();
              final orderVal = data['order'];
              if (orderVal is int && orderVal == i) return d;
            }
            return null;
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>?> slots =
          List<QueryDocumentSnapshot<Map<String, dynamic>>?>.generate(
            _maxSlots,
                (i) => _docForIndex(i),
          );

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final doc = slots[i];
              final data = doc?.data();
              final label = TextEditingController(text: data?['label'] ?? '');
              final placeName = data?['placeName'] as String?;
              final lat = (data?['lat'] as num?)?.toDouble();
              final lng = (data?['lng'] as num?)?.toDouble();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Slot ${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: label,
                        decoration: const InputDecoration(
                          labelText: 'Custom name (e.g. “My Library”)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              placeName == null
                                  ? 'No place selected'
                                  : '$placeName\n($lat, $lng)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _pickPlace(i, label.text.trim()),
                            icon: const Icon(Icons.place),
                            label: const Text('Pick place'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              // Save/Update
                              final id = doc?.id ?? (i + 1).toString();
                              await _col.doc(id).set({
                                'label': label.text.trim().isEmpty
                                    ? (placeName ?? 'Favourite ${i + 1}')
                                    : label.text.trim(),
                                'placeName': placeName,
                                'lat': lat,
                                'lng': lng,
                                'order': i,
                              }, SetOptions(merge: true));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Saved')),
                              );
                            },
                            child: const Text('Save'),
                          ),
                          const SizedBox(width: 8),
                          if (doc != null)
                            TextButton.icon(
                              onPressed: () async {
                                await doc.reference.delete();
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: _maxSlots,
          );
        },
      ),
    );
  }

  Future<void> _pickPlace(int slot, String currentLabel) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlacePickerSheet(
        onChosen: (name, lat, lng) async {
          final id = (slot + 1).toString();
          await _col.doc(id).set({
            'label': currentLabel.isEmpty ? name : currentLabel,
            'placeName': name,
            'lat': lat,
            'lng': lng,
            'order': slot,
          }, SetOptions(merge: true));
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _PlacePickerSheet extends StatefulWidget {
  final void Function(String name, double lat, double lng) onChosen;
  const _PlacePickerSheet({required this.onChosen});

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _c = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];

  static const _apiKey = _SavedRoutesScreenState._apiKey;

  Future<void> _getSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    const campusLat = 52.6219;
    const campusLng = -1.1244;
    const radius = 800;

    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=$input"
        "&location=$campusLat,$campusLng"
        "&radius=$radius"
        "&strictbounds=true"
        "&key=$_apiKey";

    final res = await http.get(Uri.parse(url));
    final data = json.decode(res.body);
    if (data['status'] == 'OK') {
      setState(() {
        _suggestions = List<Map<String, dynamic>>.from(
          data['predictions'].map((p) => {
            'description': p['description'],
            'place_id': p['place_id'],
          }),
        );
      });
    } else {
      setState(() => _suggestions = []);
    }
  }

  Future<void> _choose(String placeId, String name) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&fields=geometry"
        "&key=$_apiKey";
    final res = await http.get(Uri.parse(url));
    final data = json.decode(res.body);
    if (data['status'] == 'OK') {
      final loc = data['result']['geometry']['location'];
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();
      widget.onChosen(name, lat, lng);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get place details')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pick a building',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            onChanged: _getSuggestions,
            onSubmitted: (v) async {
              await _getSuggestions(v);
              await SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
            decoration: InputDecoration(
              hintText: 'Search on campus…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 8),
          if (_suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    title: Text(s['description']),
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      await SystemChannels.textInput.invokeMethod('TextInput.hide');
                      await _choose(s['place_id'], s['description']);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
