import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's optional custom accent color.
///
/// A null value means the custom swatch has not been configured yet. The
/// color is intentionally independent from the built-in theme identifiers so
/// it can survive light/dark mode changes without introducing another
/// background palette.
final customAccentProvider = NotifierProvider<CustomAccentNotifier, Color?>(
  CustomAccentNotifier.new,
);

class CustomAccentNotifier extends Notifier<Color?> {
  static const _preferencesKey = 'custom_accent_color';

  @override
  Color? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getInt(_preferencesKey);
      if (value != null) state = Color(value);
    } catch (_) {
      // A missing/invalid preference simply leaves the custom swatch unset.
    }
  }

  Future<void> setColor(Color color) async {
    state = color;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_preferencesKey, color.toARGB32());
    } catch (_) {
      // The in-memory color still applies for this session.
    }
  }
}
