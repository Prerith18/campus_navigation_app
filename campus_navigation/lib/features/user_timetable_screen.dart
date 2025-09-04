import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:campus_navigation/services/timetable_repository.dart';
import 'package:campus_navigation/models/timetable_bundle.dart';
import 'package:campus_navigation/models/timetable_session.dart';
import 'package:campus_navigation/features/map_screen.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TimetableRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
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

              final df = DateFormat('EEE, d MMM yyyy • HH:mm');
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
                    trailing: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              searchQuery: s.locationName,
                              searchLat: s.lat,
                              searchLng: s.lng,
                              // isAdmin stays default (false)
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
