import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:campus_navigation/services/push_service.dart';

import 'admin_home_screen.dart';
import 'main_screen.dart';

/// Demo admin credentials for quick start.
const _adminEmail = 'admin@le.ac.uk';
const _adminPassword = 'Admin@123';

enum LoginMode { student, admin }

/// Login screen with student/admin modes and Firebase authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  LoginMode _mode = LoginMode.student;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles sign-in for admin or student and routes accordingly.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _mode == LoginMode.admin ? _adminEmail : _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_mode == LoginMode.admin) {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _adminEmail,
            password: _adminPassword,
          );

          final uid = cred.user?.uid;
          if (uid != null) {
            final users = FirebaseFirestore.instance.collection('users');
            final doc = await users.doc(uid).get();
            if (!doc.exists) {
              await users.doc(uid).set({
                'email': _adminEmail,
                'name': 'Admin',
                'status': 'active',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
          await PushService.ensureSubscribedToAllUsersTopic();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome, Admin!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
          );
        } on FirebaseAuthException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin sign-in failed. Check email/password in Firebase Auth.')),
            );
          }
        }
        return;
      }

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = cred.user;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Try again.')),
          );
        }
        return;
      }

      final uid = user.uid;
      final users = FirebaseFirestore.instance.collection('users');
      final doc = await users.doc(uid).get();

      if (!doc.exists) {
        await users.doc(uid).set({
          'email': user.email ?? email,
          'name': (user.email ?? email).split('@').first.replaceAll(RegExp(r'[._]'), ' '),
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final status = (doc.data()?['status'] ?? 'active') as String;
        if (status == 'disabled') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account is disabled. Please contact the administrator.'),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(userEmail: email)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Account does not exist';
          break;
        case 'wrong-password':
          message = 'Wrong password';
          break;
        case 'invalid-email':
          message = 'Enter correct university email';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
        default:
          message = 'Login failed. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sends a password reset email for student accounts.
  Future<void> _resetPassword() async {
    if (_mode == LoginMode.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin password is managed by IT.')),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.endsWith('@student.le.ac.uk')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid university email')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: ${e.message}')),
      );
    }
  }

  /// Builds the login form, mode switch, and actions.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? const Color.fromRGBO(0, 0, 0, 0.6);
    final borderColor = cs.primary;
    final isAdmin = _mode == LoginMode.admin;

    final underlineBorder = UnderlineInputBorder(borderSide: BorderSide(color: borderColor));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/leicester_university_01.png', height: 200),
                  const SizedBox(height: 12),
                  Text('Welcome!', style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  _ModePillSwitch(
                    mode: _mode,
                    onChanged: (m) {
                      setState(() {
                        _mode = m;
                        _passwordController.clear();
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  if (!isAdmin)
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'University Email',
                        labelStyle: GoogleFonts.poppins(color: labelColor),
                        enabledBorder: underlineBorder,
                        focusedBorder: underlineBorder,
                      ),
                      validator: (value) {
                        if (_mode == LoginMode.admin) return null;
                        if (value == null || value.trim().isEmpty) return 'Please enter your email';
                        final e = value.trim().toLowerCase();
                        if (!e.endsWith('@student.le.ac.uk')) return 'Use your @student.le.ac.uk email';
                        return null;
                      },
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            _adminEmail,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Admin', style: GoogleFonts.poppins(fontSize: 12, color: cs.primary)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const <String>[],
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.poppins(color: labelColor),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: cs.primary),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      enabledBorder: underlineBorder,
                      focusedBorder: underlineBorder,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text('Forgot Password?', style: GoogleFonts.poppins(color: labelColor)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _isLoading
                      ? Column(
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('Logging you in...', style: GoogleFonts.poppins(color: cs.primary)),
                        ],
                      ),
                    ],
                  )
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text('Login', style: GoogleFonts.poppins(color: cs.onPrimary)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_mode == LoginMode.student)
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      child: Text("Don't have an account? Register here", style: GoogleFonts.poppins(color: cs.primary)),
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

/// Two-option pill switch for Student/Admin selection.
class _ModePillSwitch extends StatelessWidget {
  final LoginMode mode;
  final ValueChanged<LoginMode> onChanged;

  const _ModePillSwitch({required this.mode, required this.onChanged, super.key});

  /// Renders the animated pill and handles taps on each option.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStudent = mode == LoginMode.student;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final half = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: isStudent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: half,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(LoginMode.student),
                      child: Center(
                        child: Text(
                          'Student',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: isStudent ? cs.onPrimary : cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(LoginMode.admin),
                      child: Center(
                        child: Text(
                          'Admin',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: !isStudent ? cs.onPrimary : cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
