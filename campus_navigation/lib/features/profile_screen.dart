// lib/features/profile_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'saved_routes_screen.dart';
import 'help_screen.dart';
import 'contact_us_screen.dart';
import 'package:campus_navigation/services/theme_setup.dart';
import 'package:campus_navigation/services/messaging_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _stepFreeRoutes = false;
  bool _darkMode = ThemeSetup.themeNotifier.value == ThemeMode.dark;
  bool _notifications = true;

  final user = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _prefsSub;

  @override
  void initState() {
    super.initState();
    _listenToPrefs();
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    super.dispose();
  }

  void _listenToPrefs() {
    final uid = user?.uid;
    if (uid == null) return;

    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    _prefsSub = doc.snapshots().listen((snap) {
      final data = snap.data() ?? {};
      setState(() {
        _stepFreeRoutes = (data['stepFreeRoutes'] == true);
        _notifications = (data['notificationsEnabled'] != false); // default true
      });
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final uid = user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {key: value},
      SetOptions(merge: true),
    );
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notifications = enabled);
    await _savePref('notificationsEnabled', enabled);
    await MessagingService.instance.applyNotificationPreference(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? 'Notifications on' : 'Notifications off')),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = user?.email ?? 'user@student.le.ac.uk';
    final first = email.split('@').first;
    final displayName = _capitalize(first);

    final uid = user?.uid;
    final statsStream = uid == null
        ? null
        : FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('main')
        .snapshots();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/leicester_university_01.png',
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                "University",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium!.color,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.person, size: 32, color: Colors.white),
              )
            ],
          ),
          Text(email, style: theme.textTheme.bodySmall),
          const Divider(height: 32),

          // Stats
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: statsStream,
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final trips = (data['tripsCompleted'] ?? 0) as int;
              final distanceKm = (data['distanceKm'] ?? 0.0) as num;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatPill(
                      icon: Icons.navigation,
                      value: '$trips',
                      label: 'Trips Completed',
                    ),
                    _StatPill(
                      icon: Icons.directions_walk,
                      value: '${distanceKm.toStringAsFixed(1)} km',
                      label: 'Distance Travelled',
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

          SwitchListTile(
            title: const Text('Step-Free Routes', style: TextStyle(fontWeight: FontWeight.w500)),
            value: _stepFreeRoutes,
            onChanged: (val) async {
              setState(() => _stepFreeRoutes = val);
              await _savePref('stepFreeRoutes', val);
            },
            secondary: Icon(Icons.accessible, color: theme.colorScheme.primary),
            activeColor: theme.colorScheme.primary,
          ),

          SwitchListTile(
            title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              ThemeSetup.toggleTheme(val);
            },
            secondary: Icon(Icons.dark_mode, color: theme.colorScheme.primary),
            activeColor: theme.colorScheme.primary,
          ),

          SwitchListTile(
            title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w500)),
            value: _notifications,
            onChanged: _toggleNotifications,
            secondary: Icon(Icons.notifications_active, color: theme.colorScheme.primary),
            activeColor: theme.colorScheme.primary,
          ),

          const SizedBox(height: 24),
          const Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),

          _SettingsTile(
            title: 'Saved Routes',
            icon: Icons.star,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedRoutesScreen()));
            },
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            title: 'Help',
            icon: Icons.help_outline,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
          const SizedBox(height: 12),

          // NEW: dedicated Contact Us screen
          _SettingsTile(
            title: 'Contact Us',
            icon: Icons.support_agent,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
            },
          ),

          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => (s.isEmpty) ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
