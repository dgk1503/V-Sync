import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/core/providers/theme_mode_notifier.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';

final colorThemeProvider = NotifierProvider<ColorThemeNotifier, String>(
  ColorThemeNotifier.new,
);

/// Persists the selected accent theme and keeps the Android launcher icon
/// in sync with it.
///
/// The choice is remembered separately for light and dark mode: toggling
/// dark mode restores whichever accent was last used in that mode
/// (defaulting to monochrome). Gold and red have matching light/dark
/// palettes; emerald is dark-only; pink is light-only.
class ColorThemeNotifier extends Notifier<String> {
  static const _legacyKey = 'color_theme';
  static const _darkKey = 'color_theme_dark';
  static const _lightKey = 'color_theme_light';
  static const _appliedKey = 'launcher_icon_applied';
  static const _channel = MethodChannel('vsync/launcher_icon');

  String get _bucketKey => ref.read(userPreferencesProvider).isDarkModeEnabled
      ? _darkKey
      : _lightKey;

  @override
  String build() {
    _load();
    return AppColorTheme.mono;
  }

  /// The theme that is actually in effect right now — invalid
  /// mode/theme combos resolve to monochrome.
  String get effectiveTheme {
    switch (state) {
      case AppColorTheme.gold:
      case AppColorTheme.red:
        return state;
      case AppColorTheme.emerald:
        final dark = ref.read(userPreferencesProvider).isDarkModeEnabled;
        return dark ? state : AppColorTheme.mono;
      case AppColorTheme.pink:
        final dark = ref.read(userPreferencesProvider).isDarkModeEnabled;
        return dark ? AppColorTheme.mono : state;
      case AppColorTheme.custom:
        return state;
      default:
        return AppColorTheme.mono;
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getString(_bucketKey) ??
          prefs.getString(_legacyKey) ??
          AppColorTheme.mono;
      state = saved;
      await syncLauncherIcon();
    } catch (_) {
      state = AppColorTheme.mono;
    }
  }

  Future<void> setTheme(String theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bucketKey, theme);
    await syncLauncherIcon();
    // Rebuild MaterialApp theme.
    ref.invalidate(themeModeProvider);
  }

  /// Re-applies the launcher icon for the current effective theme.
  Future<void> syncLauncherIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final effective = effectiveTheme;
    final applied = prefs.getString(_appliedKey);
    if (applied == effective) return; // already in sync

    try {
      await _channel.invokeMethod('setGold', {
        'gold': effective == AppColorTheme.gold,
      });
      await prefs.setString(_appliedKey, effective);
    } catch (_) {
      // Native side unavailable — ignore.
    }
  }
}
