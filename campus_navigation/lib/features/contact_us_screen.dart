import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // You could show a snackbar here if desired
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
