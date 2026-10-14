import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode controller with persistence.
///
/// The [ScholifyApp] listens to [mode] and rebuilds [MaterialApp] with the
/// matching brightness. Any screen can toggle via [toggle] or [setMode].
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'scholify_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool _loaded = false;

  /// Loads the persisted mode (call once at startup).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      mode.value = switch (raw) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {
      // Non-fatal: fall back to light.
    }
  }

  static Future<void> setMode(ThemeMode next) async {
    mode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        switch (next) {
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
          ThemeMode.light => 'light',
        },
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<void> toggle() {
    final next =
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    return setMode(next);
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}
