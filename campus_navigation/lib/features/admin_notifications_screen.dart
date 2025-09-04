import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  final _deeplink = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('admin_notifications');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    _deeplink.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _sending = true);
    try {
      final me = FirebaseAuth.instance.currentUser;
      await _col.add({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'image': _image.text.trim().isEmpty ? null : _image.text.trim(),
        'deeplink': _deeplink.text.trim().isEmpty ? null : _deeplink.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'publishedByUid': me?.uid,
        'publishedByEmail': me?.email,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Published')),
      );
      _title.clear();
      _body.clear();
      _image.clear();
      _deeplink.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                  ),
                  TextFormField(
                    controller: _body,
                    decoration: const InputDecoration(labelText: 'Body *'),
                    maxLines: 3,
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a message' : null,
                  ),
                  TextFormField(
                    controller: _image,
                    decoration:
                    const InputDecoration(labelText: 'Image URL (optional)'),
                  ),
                  TextFormField(
                    controller: _deeplink,
                    decoration: const InputDecoration(
                      labelText: 'Deeplink (optional, e.g. app://timetables)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _sending
                          ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Publishing…' : 'Publish'),
                      onPressed: _sending ? null : _publish,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent publishes',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col.orderBy('createdAt', descending: true).limit(20).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No notifications yet.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      final data = d.data();
                      final ts = data['createdAt'] as Timestamp?;
                      final when = ts?.toDate().toLocal();
                      final subtitle = [
                        if (data['body'] != null) data['body'] as String,
                        if (data['deeplink'] != null) '🔗 ${data['deeplink']}',
                      ].join('\n');

                      return ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Text(subtitle),
                        trailing: when == null
                            ? null
                            : Text(
                          _fmtShortTime(when),
                          style: theme.textTheme.bodySmall,
                        ),
                        onLongPress: () async {
                          // optional: long-press to delete an admin publish document
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete notification?'),
                              content: const Text('This will remove the admin record.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          ) ??
                              false;
                          if (ok) await d.reference.delete();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtShortTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$d/$mo $h:$m';
}
