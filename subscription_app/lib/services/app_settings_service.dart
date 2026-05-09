import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _keyTheme = 'theme_mode';
  static const _keyLocale = 'locale';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);
  static final ValueNotifier<String> locale = ValueNotifier('en');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_keyTheme) ?? 'system';
    themeMode.value = _parseTheme(themeStr);
    locale.value = prefs.getString(_keyLocale) ?? 'en';
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, _themeString(mode));
  }

  static Future<void> setLocale(String code) async {
    locale.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, code);
  }

  static ThemeMode _parseTheme(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
