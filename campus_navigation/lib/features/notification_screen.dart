import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markingAll = false;

  Future<void> _markAllAsRead(String uid) async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      final col = FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(uid)
          .collection('items');

      final unread = await col.where('read', isEqualTo: false).get();
      if (unread.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in unread.docs) {
        batch.set(d.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${unread.docs.length} as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(
          child: Text('Please sign in to view notifications.'),
        ),
      );
    }

    final uid = user.uid;
    final itemsQuery = FirebaseFirestore.instance
        .collection('userNotifications')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: itemsQuery.where('read', isEqualTo: false).snapshots(),
            builder: (_, snap) {
              final unread = snap.data?.size ?? 0;
              if (unread == 0) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Mark all as read',
                onPressed: _markingAll ? null : () => _markAllAsRead(uid),
                icon: _markingAll
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.mark_email_read_outlined),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: itemsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              final title = (data['title'] ?? '') as String;
              final body = (data['body'] ?? '') as String;
              final image = data['image'] as String?;
              final read = data['read'] == true;
              final ts = data['createdAt'];
              DateTime? createdAt;
              if (ts is Timestamp) createdAt = ts.toDate().toLocal();

              return ListTile(
                leading: Icon(
                  read ? Icons.notifications_none : Icons.notifications_active,
                  color: read ? null : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: read ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty) Text(body),
                    if (image != null && image.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            image,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const SizedBox(height: 0),
                          ),
                        ),
                      ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _formatWhen(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ),
                  ],
                ),
                trailing:
                read ? null : const Icon(Icons.fiber_new, color: Colors.red),
                onTap: () async {
                  // mark as read
                  await d.reference.set({
                    'read': true,
                    'readAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  // Optional deep link
                  final link = data['deeplink'] as String?;
                  if (link != null && link.isNotEmpty) {
                    _openDeepLink(context, link);
                  }
                },
                onLongPress: () async {
                  // Optional: delete a single item (per-user)
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete notification?'),
                      content: const Text(
                          'This removes it from your device only.'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                      false;
                  if (ok) {
                    await d.reference.delete();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // Adjust this to your navigation. Example: app://map?lat=..&lng=..&q=Name
  void _openDeepLink(BuildContext context, String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    if (uri.host == 'map') {
      final q = uri.queryParameters['q'] ?? 'Selected location';
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
      final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
      // For now just pop back to Home; your HomeScreen can react if you wire a global handler.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigate to: $q')),
      );
      // TODO: invoke your navigation to MapScreen with (q, lat, lng)
    }
  }
}
