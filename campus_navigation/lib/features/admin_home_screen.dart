import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_screen.dart';
import 'admin_notifications_screen.dart';

/// Admin dashboard entry screen: quick nav, manage grid, live stats, and logout.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  /// Signs the current user out and returns to the login screen.
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  /// Opens the map after refreshing the ID token and determining admin access.
  Future<void> _openMap(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.getIdToken(true);
      final token = await user?.getIdTokenResult();
      final isAdmin = token?.claims?['admin'] == true ||
          (user?.email?.toLowerCase() == 'admin@le.ac.uk');
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(
            isAdmin: isAdmin,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open map: $e')));
    }
  }

  /// Builds the admin dashboard layout and content.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor:
        theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavPill(
                icon: Icons.calendar_month,
                label: 'Timetables',
                onTap: () => Navigator.pushNamed(context, '/admin/timetables'),
              ),
              _NavPill(
                icon: Icons.group,
                label: 'Students',
                onTap: () => Navigator.pushNamed(context, '/admin/students'),
              ),
              _NavPill(
                icon: Icons.map,
                label: 'Map',
                onTap: () => _openMap(context),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text('Manage',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                _FeatureCard(
                  icon: Icons.calendar_view_month,
                  title: 'Timetables',
                  description: 'Create, edit, and publish timetable bundles.',
                  onTap: () => Navigator.pushNamed(context, '/admin/timetables'),
                ),
                _FeatureCard(
                  icon: Icons.badge,
                  title: 'Students',
                  description: 'Manage student accounts and access.',
                  onTap: () => Navigator.pushNamed(context, '/admin/students'),
                ),
                _FeatureCard(
                  icon: Icons.map,
                  title: 'Map',
                  description: 'Campus map (view only).',
                  onTap: () => _openMap(context),
                ),
                _FeatureCard(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  description: 'Send announcements to students.',
                  onTap: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
                    );
                  },
                ),
              ]
          ),

          const SizedBox(height: 32),

          Text('Status Overview',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _StatTile(
            label: 'Draft Bundles',
            icon: Icons.calendar_month,
            stream: FirebaseFirestore.instance
                .collection('timetableBundles')
                .where('published', isEqualTo: false)
                .snapshots()
                .map((s) => s.size),
            onTap: () => Navigator.pushNamed(context, '/admin/timetables'),
          ),
          const SizedBox(height: 12),
          _StatTile(
            label: 'Disabled Accounts',
            icon: Icons.person_off,
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('status', isEqualTo: 'disabled')
                .snapshots()
                .map((s) => s.size),
            onTap: () => Navigator.pushNamed(context, '/admin/students'),
          ),

          const SizedBox(height: 32),

          Center(
            child: TextButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ),
    );
  }
}

/// Compact circular icon + label used for the quick navigation row.
class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            radius: 28,
            child: Icon(icon, color: theme.colorScheme.onPrimary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Card used in the "Manage" grid to launch a specific admin feature.
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.arrow_forward_ios,
                    size: 16, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live Firestore-backed count tile with an action, used in "Status Overview".
class _StatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Stream<int> stream;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.icon,
    required this.stream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primary.withOpacity(0.1),
              child: Icon(icon, color: cs.primary),
            ),
            title:
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
