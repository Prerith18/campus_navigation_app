// lib/features/students_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all | active | disabled

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('users');

    if (_statusFilter == 'active') {
      q = q.where('status', isEqualTo: 'active');
    } else if (_statusFilter == 'disabled') {
      q = q.where('status', isEqualTo: 'disabled');
    }

    // No orderBy here → avoids composite index requirement
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Students'),
      ),
      body: Column(
        children: [
          // Search + Filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading students:\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];

                // Client-side search
                final q = _searchCtrl.text.trim().toLowerCase();
                final filtered = (q.isEmpty)
                    ? docs.toList()
                    : docs.where((d) {
                  final m = d.data();
                  final email = (m['email'] ?? '').toString().toLowerCase();
                  final name = (m['name'] ?? '').toString().toLowerCase();
                  return email.contains(q) || name.contains(q);
                }).toList();

                // Client-side sort by email
                filtered.sort((a, b) {
                  final ea = (a.data()['email'] ?? '').toString().toLowerCase();
                  final eb = (b.data()['email'] ?? '').toString().toLowerCase();
                  return ea.compareTo(eb);
                });

                if (filtered.isEmpty) {
                  return const Center(child: Text('No students found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final m = d.data();
                    final email = (m['email'] ?? '') as String;
                    final name = (m['name'] ?? email) as String;
                    final status = (m['status'] ?? 'active') as String;
                    final isEnabled = status == 'active';
                    final isAdmin = email.toLowerCase() == 'admin@le.ac.uk';

                    return Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                            style: TextStyle(color: theme.colorScheme.onPrimary),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? theme.colorScheme.primary.withOpacity(0.12)
                                    : theme.colorScheme.error.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isEnabled ? 'Active' : 'Disabled',
                                style: TextStyle(
                                  color: isEnabled
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isEnabled,
                              onChanged: isAdmin
                                  ? null // don't disable the admin account here
                                  : (val) => _toggleStatus(context, d.reference, email, val),
                            ),
                          ],
                        ),
                        onTap: () => _showStudentSheet(context, name, email, status),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(
      BuildContext context,
      DocumentReference ref,
      String email,
      bool enable,
      ) async {
    if (!enable) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disable account?'),
          content: Text(
            'This will prevent $email from using the app. '
                'You can enable them again later.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable')),
          ],
        ),
      );
      if (ok != true) return;
    }

    await ref.update({'status': enable ? 'active' : 'disabled'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email ${enable ? 'enabled' : 'disabled'}')),
      );
    }
  }

  void _showStudentSheet(BuildContext context, String name, String email, String status) {
    final theme = Theme.of(context);
    final safe = (status.isNotEmpty) ? status : 'active';
    final display = safe[0].toUpperCase() + safe.substring(1);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(email),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Text('Status: $display'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
