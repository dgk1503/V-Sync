import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/providers/color_theme_notifier.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';

part 'theme_mode_notifier.g.dart';

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeData build() {
    // Get user preferences to determine initial theme. Dark monochrome is
    // the app's identity: rows that never saw an explicit user toggle
    // (legacy installs and fresh users) resolve to dark regardless of the
    // stored flag or OS setting.
    final userPreferences = ref.read(userPreferencesProvider);
    final colorTheme = ref.watch(colorThemeProvider);

    final isDark = userPreferences.hasUserChosenTheme
        ? userPreferences.isDarkModeEnabled
        : true;

    return getThemeData(
      isDarkMode: isDark,
      isAmoled: userPreferences.isAmoledEnabled,
      colorTheme: colorTheme,
    );
  }

  Future<void> toggleTheme() async {
    final currentPreferences = ref.read(userPreferencesProvider);
    final newThemeMode = !currentPreferences.isDarkModeEnabled;

    final updatedPreferences = currentPreferences.copyWith(
      isDarkModeEnabled: newThemeMode,
      // From this point on, respect whatever the user picked.
      hasUserChosenTheme: true,
    );
    await ref
        .read(userPreferencesProvider.notifier)
        .updatePreferences(updatedPreferences);

    // Rebuild MaterialApp theme, and reload the color theme from the
    // bucket for the new mode (light and dark remember separately).
    ref.invalidateSelf();
    ref.invalidate(colorThemeProvider);
  }

  Future<void> toggleAmoled() async {
    final currentPreferences = ref.read(userPreferencesProvider);
    final newAmoledMode = !currentPreferences.isAmoledEnabled;

    final updatedPreferences = currentPreferences.copyWith(
      isAmoledEnabled: newAmoledMode,
    );
    await ref
        .read(userPreferencesProvider.notifier)
        .updatePreferences(updatedPreferences);

    // Rebuild theme with new AMOLED mode
    ref.invalidateSelf();
  }
}
