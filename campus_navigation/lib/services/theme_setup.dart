import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised theme manager: keeps app-wide light/dark mode and persistence.
class ThemeSetup {
  /// Notifies the app when theme mode changes (default: light).
  static final ValueNotifier<ThemeMode> themeNotifier =
  ValueNotifier(ThemeMode.light);

  /// Apply the chosen theme and store the preference locally.
  static Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  /// Restore the previously saved theme during app start.
  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
