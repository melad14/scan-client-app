import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════
//  ScanGo Theme Provider
//  Manages ThemeMode (light / dark) with persistence via SharedPreferences.
//  Default: ThemeMode.light (correct for a patient-facing medical app)
// ══════════════════════════════════════════════════════════════════

const _kThemePrefKey = 'scango_theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadPersistedTheme();
  }

  /// Loads saved preference on startup. Defaults to light mode.
  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kThemePrefKey);
      if (savedMode == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  /// Toggles between light and dark, then persists the choice.
  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Force-set a specific mode (e.g., from a settings screen).
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  bool get isDark => state == ThemeMode.dark;
}

/// The global theme provider.
/// Usage: ref.watch(themeProvider) → ThemeMode
/// Usage: ref.read(themeProvider.notifier).toggleTheme()
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
