import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'login_screen.dart';

/// Splash screen that refreshes auth claims once, then moves to Login after a short delay.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off a one-time token refresh and schedule navigation to the login screen.
    _refreshClaimsOnce();
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  // Refresh the Firebase ID token so any custom claims are available early.
  Future<void> _refreshClaimsOnce() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }
    } catch (e) {
      debugPrint('Token refresh on splash failed: $e');
    }
  }

  // Minimal centered logo splash.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/leicester_university_01.png',
              height: 150,
            ),
          ],
        ),
      ),
    );
  }
}
