import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:campus_navigation/services/timetable_repository.dart';
import 'package:campus_navigation/models/timetable_bundle.dart';
import 'package:campus_navigation/models/timetable_session.dart';
import 'package:campus_navigation/features/map_screen.dart';

/// Screen that shows the currently published timetable and its sessions.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TimetableRepository.instance;

    // Basic shell with an app bar and a body that streams data.
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      // Listen to the published bundle; if none, tell the user.
      body: StreamBuilder<TimetableBundle?>(
        stream: repo.streamPublishedBundle(),
        builder: (context, bundleSnap) {
          final bundle = bundleSnap.data;
          if (bundleSnap.hasError) {
            return Center(child: Text('Error: ${bundleSnap.error}'));
          }
          if (bundle == null) {
            return const Center(
              child: Text('No timetable published yet.'),
            );
          }

          // Once a bundle is available, stream its sessions.
          return StreamBuilder<List<TimetableSession>>(
            stream: repo.streamSessions(bundle.id),
            builder: (context, sessSnap) {
              if (sessSnap.hasError) {
                return Center(child: Text('Error: ${sessSnap.error}'));
              }
              final sessions = sessSnap.data ?? [];
              if (sessions.isEmpty) {
                return const Center(child: Text('No sessions in this timetable.'));
              }

              // Date formatting for each session row.
              final df = DateFormat('EEE, d MMM yyyy • HH:mm');

              // Render the list of sessions with a quick action to navigate.
              return ListView.separated(
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final start = s.startTime.toDate().toLocal();
                  final end = s.endTime.toDate().toLocal();
                  return ListTile(
                    leading: const Icon(Icons.school),
                    title: Text(s.title),
                    subtitle: Text(
                      '${df.format(start)}  →  ${df.format(end)}\n'
                          '${s.locationName}${s.room != null ? ' • ${s.room}' : ''}',
                    ),
                    isThreeLine: true,
                    // Opens the map focused on the session location.
                    trailing: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              searchQuery: s.locationName,
                              searchLat: s.lat,
                              searchLng: s.lng,
                            ),
                          ),
                        );
                      },
                      child: const Text('Go to class'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
