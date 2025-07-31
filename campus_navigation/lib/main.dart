import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'features/splash_screen.dart';
import 'features/login_screen.dart';
import 'features/register_screen.dart';
import 'firebase_options.dart';
import 'package:campus_navigation/services/theme_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  await ThemeSetup.loadTheme();

  runApp(const CampusNavigationApp());
}

class CampusNavigationApp extends StatelessWidget {
  const CampusNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeSetup.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Campus Navigation App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurple,
            ),
            scaffoldBackgroundColor: Colors.black,
          ),
          themeMode: currentMode,
          home: const SplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
          },
        );
      },
    );
  }
}
