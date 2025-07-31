import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:campus_navigation/services/theme_setup.dart';

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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildTile(String title, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Username';
    final email = user?.email ?? 'xyz@student.le.ac.uk';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/leicester_university_01.png',
          height: 150,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              "University",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, size: 32, color: Colors.white),
              )
            ],
          ),
          Text(email, style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.navigation, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    const Text("18", style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text("Trips Completed", style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_walk, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    const Text("10 km", style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text("Distance Travelled", style: TextStyle(fontSize: 12)),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text("Preferences", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

          _buildToggleRow("Step-Free Routes", _stepFreeRoutes, (val) {
            setState(() => _stepFreeRoutes = val);
          }, Icons.accessible),

          _buildToggleRow("Dark Mode", _darkMode, (val) {
            setState(() => _darkMode = val);
            ThemeSetup.toggleTheme(val);
          }, Icons.dark_mode),

          _buildToggleRow("Notifications", _notifications, (val) {
            setState(() => _notifications = val);
          }, Icons.notifications_active),

          const SizedBox(height: 24),
          const Text("App Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),

          _buildTile("Saved Routes", Icons.location_on, () {}),
          const SizedBox(height: 12),
          _buildTile("Units and Measurements", Icons.tune, () {}),
          const SizedBox(height: 12),
          _buildTile("Help and Feedback", Icons.help_outline, () {}),

          const SizedBox(height: 32),
          Center(
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ),
    );
  }
}
