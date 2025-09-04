// lib/features/admin_timetables_screen.dart
// Admin: create/rename/delete timetable bundles, add/edit/delete sessions,
// and publish exactly one bundle at a time.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp

import 'package:campus_navigation/models/timetable_bundle.dart';
import 'package:campus_navigation/models/timetable_session.dart';
import 'package:campus_navigation/services/timetable_repository.dart';

/// Top-level helper: result from the mini place picker.
class _PlaceChoice {
  final String name;
  final double lat;
  final double lng;
  const _PlaceChoice(this.name, this.lat, this.lng);
}

class AdminTimetablesScreen extends StatefulWidget {
  const AdminTimetablesScreen({super.key});

  @override
  State<AdminTimetablesScreen> createState() => _AdminTimetablesScreenState();
}

class _AdminTimetablesScreenState extends State<AdminTimetablesScreen> {
  String? _selectedBundleId;

  // Reuse the same API key you already use in the app
  static const String _gmapsApiKey = "AIzaSyAsHYoxe5t5A8Zm8tPogYOfWFjAtyDionw";

  @override
  Widget build(BuildContext context) {
    final repo = TimetableRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Timetables')),
      floatingActionButton: _selectedBundleId == null
          ? null
          : FloatingActionButton.extended(
        onPressed: _onAddSession,
        icon: const Icon(Icons.add),
        label: const Text('Add session'),
      ),
      body: Column(
        children: [
          // ----- Bundles row -----
          StreamBuilder<List<TimetableBundle>>(
            stream: repo.streamBundles(),
            builder: (context, snap) {
              final bundles = snap.data ?? [];
              if (bundles.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('No bundles yet. Create one to begin.'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final name = await _askText('New bundle name');
                          if (name == null || name.trim().isEmpty) return;
                          final id = await repo.createBundle(name.trim());
                          setState(() => _selectedBundleId = id);
                        },
                        child: const Text('Create bundle'),
                      ),
                    ],
                  ),
                );
              }

              // Ensure a valid selected bundle (avoid setState in build)
              if (_selectedBundleId == null ||
                  !bundles.any((b) => b.id == _selectedBundleId)) {
                _selectedBundleId = bundles.first.id;
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: bundles.map((b) {
                    final selected = b.id == _selectedBundleId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        selected: selected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(b.name),
                            if (b.published)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.public, size: 16),
                              ),
                          ],
                        ),
                        onSelected: (_) {
                          setState(() => _selectedBundleId = b.id);
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const Divider(height: 1),

          // ----- Sessions list -----
          Expanded(
            child: _selectedBundleId == null
                ? const SizedBox()
                : StreamBuilder<List<TimetableSession>>(
              stream: repo.streamSessions(_selectedBundleId!),
              builder: (context, snap) {
                final sessions = snap.data ?? [];
                if (sessions.isEmpty) {
                  return const Center(
                      child: Text('No sessions in this bundle.'));
                }
                final df = DateFormat('EEE, d MMM yyyy • HH:mm');
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    return ListTile(
                      leading: const Icon(Icons.event_note),
                      title: Text(s.title),
                      subtitle: Text(
                        '${df.format(s.startTime.toDate().toLocal())}  →  ${df.format(s.endTime.toDate().toLocal())}\n'
                            '${s.locationName}${s.room != null ? ' • ${s.room}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openSessionEditor(existing: s),
                      ),
                      onLongPress: () async {
                        final ok = await _confirm('Delete this session?');
                        if (ok != true) return;
                        await repo.deleteSession(_selectedBundleId!, s.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ----- Bundle actions: rename, delete, publish -----
      bottomNavigationBar: _selectedBundleId == null
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: StreamBuilder<List<TimetableBundle>>(
            stream: repo.streamBundles(),
            builder: (context, snap) {
              final bundles = snap.data ?? [];
              if (bundles.isEmpty) return const SizedBox();

              final current = bundles.firstWhere(
                    (b) => b.id == _selectedBundleId,
                orElse: () => bundles.first,
              );

              // Wrap fixes bottom overflow on narrow screens
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: const Text('Rename'),
                    onPressed: () async {
                      final name = await _askText('Rename bundle',
                          initial: current.name);
                      if (name == null || name.trim().isEmpty) return;
                      await repo.updateBundle(
                          current.copyWith(name: name.trim()));
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete bundle'),
                    onPressed: () async {
                      final ok = await _confirm(
                          'Delete bundle and all sessions?');
                      if (ok != true) return;
                      await repo.deleteBundle(current.id);
                      if (mounted) setState(() => _selectedBundleId = null);
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.publish),
                    label: Text(
                        current.published ? 'Published' : 'Publish'),
                    onPressed: () async {
                      await repo.publishBundle(current.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Published "${current.name}"')),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onAddSession() async {
    await _openSessionEditor();
  }

  Future<void> _openSessionEditor({TimetableSession? existing}) async {
    if (_selectedBundleId == null) return;

    final title = TextEditingController(text: existing?.title ?? '');
    final module = TextEditingController(text: existing?.moduleCode ?? '');
    final room = TextEditingController(text: existing?.room ?? '');
    final locationName =
    TextEditingController(text: existing?.locationName ?? '');
    final lat = TextEditingController(
        text: (existing?.lat ?? 52.6219).toStringAsFixed(6));
    final lng = TextEditingController(
        text: (existing?.lng ?? -1.1244).toStringAsFixed(6));
    final notes = TextEditingController(text: existing?.notes ?? '');

    DateTime start = (existing?.startTime.toDate().toLocal()) ??
        DateTime.now().add(const Duration(hours: 1));
    DateTime end = (existing?.endTime.toDate().toLocal()) ??
        start.add(const Duration(hours: 1));

    Future<void> pickStart() async {
      final d = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d == null) return;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(start),
      );
      if (t == null) return;
      start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }

    Future<void> pickEnd() async {
      final d = await showDatePicker(
        context: context,
        initialDate: end,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d == null) return;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(end),
      );
      if (t == null) return;
      end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add session' : 'Edit session',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: module,
                decoration:
                const InputDecoration(labelText: 'Module code'),
              ),
              TextField(
                controller: room,
                decoration: const InputDecoration(labelText: 'Room'),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start: ${DateFormat('EEE, d MMM • HH:mm').format(start)}',
                    ),
                  ),
                  TextButton(onPressed: pickStart, child: const Text('Pick')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'End:   ${DateFormat('EEE, d MMM • HH:mm').format(end)}',
                    ),
                  ),
                  TextButton(onPressed: pickEnd, child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 8),

              // Location name with search helper
              TextField(
                controller: locationName,
                decoration: InputDecoration(
                  labelText: 'Location name *',
                  suffixIcon: IconButton(
                    tooltip: 'Search building',
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final picked = await _pickPlaceDialog(
                        initialQuery: locationName.text.trim(),
                      );
                      if (picked != null) {
                        locationName.text = picked.name;
                        lat.text = picked.lat.toStringAsFixed(6);
                        lng.text = picked.lng.toStringAsFixed(6);
                      }
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: lat,
                      decoration: const InputDecoration(labelText: 'Latitude *'),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lng,
                      decoration:
                      const InputDecoration(labelText: 'Longitude *'),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),

              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (existing != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () async {
                        final ok = await _confirm('Delete this session?');
                        if (ok != true) return;
                        await TimetableRepository.instance
                            .deleteSession(_selectedBundleId!, existing.id);
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final s = TimetableSession(
                          id: existing?.id ?? '',
                          title: title.text.trim(),
                          moduleCode: module.text.trim().isEmpty
                              ? null
                              : module.text.trim(),
                          room: room.text.trim().isEmpty
                              ? null
                              : room.text.trim(),
                          startTime: Timestamp.fromDate(start.toUtc()),
                          endTime: Timestamp.fromDate(end.toUtc()),
                          locationName: locationName.text.trim(),
                          lat: double.parse(lat.text.trim()),
                          lng: double.parse(lng.text.trim()),
                          notes: notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                        );
                        await TimetableRepository.instance
                            .upsertSession(_selectedBundleId!, s);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- helpers ----------

  Future<String?> _askText(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );
  }

  // ---- Place picker (Google Places Text Search) ----
  Future<_PlaceChoice?> _pickPlaceDialog({String initialQuery = ''}) async {
    final queryCtrl = TextEditingController(text: initialQuery);
    List<_PlaceChoice> results = [];

    Future<void> _search() async {
      final q = queryCtrl.text.trim();
      if (q.isEmpty) return;

      // Bias around campus (adjust radius if needed)
      const campusLat = 52.6219;
      const campusLng = -1.1244;
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query': q,
          'location': '$campusLat,$campusLng',
          'radius': '1500',
          'key': _gmapsApiKey,
        },
      );

      try {
        final resp = await http.get(uri);
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final List items = (data['results'] as List?) ?? [];
        results = items.map<_PlaceChoice>((e) {
          final name = (e['name'] as String?) ?? 'Unnamed';
          final loc = (e['geometry']?['location'] as Map?) ?? {};
          final lat = ((loc['lat'] ?? 0) as num).toDouble();
          final lng = ((loc['lng'] ?? 0) as num).toDouble();
          return _PlaceChoice(name, lat, lng);
        }).toList();
      } catch (_) {
        results = [];
      }
    }

    return showDialog<_PlaceChoice>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Search building'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. David Wilson Library',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () async {
                            await _search();
                            setSt(() {});
                          },
                        ),
                      ),
                      onSubmitted: (_) async {
                        await _search();
                        setSt(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    if (results.isEmpty)
                      const Text('No results yet. Search above.'),
                    if (results.isNotEmpty)
                      SizedBox(
                        height: 260,
                        child: ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = results[i];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(r.name),
                              subtitle: Text(
                                  '${r.lat.toStringAsFixed(6)}, ${r.lng.toStringAsFixed(6)}'),
                              onTap: () => Navigator.pop(ctx, r),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
