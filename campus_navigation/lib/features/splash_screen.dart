import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';      // 👈 add this
import 'package:flutter/foundation.dart';               // 👈 for debugPrint
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // 👇 Try to refresh the token once on launch so custom claims are present
    _refreshClaimsOnce();

    // Your original 3s splash -> LoginScreen
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  Future<void> _refreshClaimsOnce() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true); // force refresh so admin claim is included
        // (optional) verify in logs:
        // final t = await user.getIdTokenResult();
        // debugPrint('claims on splash: ${t.claims}');
      }
    } catch (e) {
      debugPrint('Token refresh on splash failed: $e');
      // safe to ignore; user can still sign in on the next screen
    }
  }

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
