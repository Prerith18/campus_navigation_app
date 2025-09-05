import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple contact directory screen linking to email, phone, web, and address.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  /// Tries to open the given URI in an external application.
  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // no-op if launch fails
    }
  }

  /// Builds the page scaffold with a list of contact options.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact methods as tappable cards
          Card(
            child: ListTile(
              leading: Icon(Icons.email, color: theme.colorScheme.primary),
              title: const Text('Email'),
              subtitle: const Text('support@le.ac.uk'),
              onTap: () => _open(Uri.parse('mailto:support@le.ac.uk')),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.phone, color: theme.colorScheme.primary),
              title: const Text('Phone'),
              subtitle: const Text('+44 116 252 2522'),
              onTap: () => _open(Uri.parse('tel:+441162522522')),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.public, color: theme.colorScheme.primary),
              title: const Text('Website'),
              subtitle: const Text('https://le.ac.uk'),
              onTap: () => _open(Uri.parse('https://le.ac.uk')),
            ),
          ),
          const SizedBox(height: 12),
          // Static address (info only)
          Card(
            child: ListTile(
              leading: Icon(Icons.location_on, color: theme.colorScheme.primary),
              title: const Text('Address'),
              subtitle: const Text('University of Leicester, University Rd, Leicester LE1 7RH, UK'),
            ),
          ),
        ],
      ),
    );
  }
}
