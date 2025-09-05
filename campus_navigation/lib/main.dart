// App entry point: bootstraps Firebase, messaging, theme, and starts the UI.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'package:campus_navigation/services/theme_setup.dart';

import 'features/splash_screen.dart';
import 'features/login_screen.dart';
import 'features/register_screen.dart';
import 'features/students_screen.dart';

import 'features/admin_timetables_screen.dart';
import 'features/user_timetable_screen.dart';
import 'services/messaging_service.dart';
import 'features/admin_notifications_screen.dart';

void main() async {
  // Ensure bindings, then init Firebase, push messaging, and load saved theme.
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await MessagingService.instance.init();

  await ThemeSetup.loadTheme();

  runApp(const CampusNavigationApp());
}

class CampusNavigationApp extends StatelessWidget {
  const CampusNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the app whenever the theme mode changes.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeSetup.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        // Central MaterialApp configuration (themes, home, and named routes).
        return MaterialApp(
          title: 'Campus Navigation App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.deepPurple),
            scaffoldBackgroundColor: Colors.black,
          ),
          themeMode: currentMode,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/admin/students': (context) => const StudentsScreen(),
            '/admin/timetables': (context) => const AdminTimetablesScreen(),
            '/timetables': (context) => const TimetableScreen(),
            '/admin/notifications': (context) => const AdminNotificationsScreen(),
          },
        );
      },
    );
  }
}
