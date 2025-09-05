import 'package:flutter/material.dart';

/// Simple placeholder screen for campus bus info.
class BusScreen extends StatelessWidget {
  const BusScreen({super.key});

  /// Builds a bare scaffold with an app bar.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Center Bus')),
      body: const Center(child: Text('')),
    );
  }
}
