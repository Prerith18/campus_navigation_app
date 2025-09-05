import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

/// Student registration screen that creates an account and a lightweight profile.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Holds form controllers, simple UI state, and the registration flow.
class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// Dispose controllers to avoid memory leaks.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Derives a friendly display name from the university email.
  String _deriveNameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Student';
    final parts = local.replaceAll('_', '.').split('.');
    return parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : '')).join(' ').trim();
  }

  /// Validates input, creates the Firebase Auth user, writes a profile, then navigates in.
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = cred.user;

      if (user != null) {
        final uid = user.uid;
        final name = _deriveNameFromEmail(email);

        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({
            'email': email,
            'name': name,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('⚠️ Firestore profile write failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created. Profile sync will finish shortly.')),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created!")),
      );

      if (mounted && user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(userEmail: user.email ?? '')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email already in use. Redirecting to login...")),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unexpected error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Builds the registration form UI with email/password fields and actions.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? const Color.fromRGBO(0, 0, 0, 0.6);

    final underline = UnderlineInputBorder(borderSide: BorderSide(color: cs.primary));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset('assets/images/leicester_university_01.png', height: 200),
                  const SizedBox(height: 16),
                  Text('Create Account', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'University Email',
                      labelStyle: GoogleFonts.poppins(color: labelColor),
                      enabledBorder: underline,
                      focusedBorder: underline,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter email';
                      if (!value.trim().toLowerCase().endsWith('@student.le.ac.uk')) {
                        return 'Use university email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const <String>[],
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.poppins(color: labelColor),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: cs.primary),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      enabledBorder: underline,
                      focusedBorder: underline,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const <String>[],
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: GoogleFonts.poppins(color: labelColor),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: cs.primary),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      enabledBorder: underline,
                      focusedBorder: underline,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm password';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Submit button or progress hint
                  _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('Creating your account...', style: GoogleFonts.poppins(color: cs.primary)),
                    ],
                  )
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text('Register', style: GoogleFonts.poppins(color: cs.onPrimary)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Link to login
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text("Already have an account? Login", style: GoogleFonts.poppins(color: cs.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
