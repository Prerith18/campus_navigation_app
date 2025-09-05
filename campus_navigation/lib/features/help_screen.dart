import 'package:flutter/material.dart';
import 'contact_us_screen.dart';

/// Help/FAQ screen with quick usage steps and a shortcut to contact support.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  /// Builds the help page: a list of concise "how to" steps and a Contact Us button.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('How to use the app', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const _StepTile(
            title: 'Search buildings',
            body: 'Use the search bar on Home to find campus buildings. Tap a result to navigate.',
            icon: Icons.search,
          ),
          const _StepTile(
            title: 'Navigate',
            body: 'Tap “Navigate” or a result to open the map focused on that location.',
            icon: Icons.navigation,
          ),
          const _StepTile(
            title: 'Timetable',
            body: 'Your published sessions for today appear on Home. Tap “Go to class” to route.',
            icon: Icons.schedule,
          ),
          const _StepTile(
            title: 'Notifications',
            body: 'Admins can send important updates. Tap the bell to read and mark as read.',
            icon: Icons.notifications_active,
          ),
          const _StepTile(
            title: 'Saved routes',
            body: 'In Profile → Saved Routes, set up to 3 favourites with custom names.',
            icon: Icons.star,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Us'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small reusable card that shows a single help step with icon, title, and body.
class _StepTile extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _StepTile({required this.title, required this.body, required this.icon});

  /// Renders a single help step row.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(body),
      ),
    );
  }
}
