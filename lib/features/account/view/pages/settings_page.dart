import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/providers/color_theme_notifier.dart';
import 'package:vit_ap_student_app/core/providers/theme_mode_notifier.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/account/view/widgets/developer_mode_tiles.dart';


class SettingsPage extends ConsumerStatefulWidget {
  final bool isDeveloperModeEnabled;

  const SettingsPage({super.key, this.isDeveloperModeEnabled = false});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final userPreferences = ref.watch(userPreferencesProvider);
    final userPreferencesNotifier = ref.read(userPreferencesProvider.notifier);
    final colorTheme = ref.watch(colorThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: AccentGradientText(
          'Settings',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.isDeveloperModeEnabled)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Iconsax.security_user_copy, size: 22),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          // Appearance
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(
                userPreferences.isDarkModeEnabled
                    ? Iconsax.moon_copy
                    : Iconsax.sun_1_copy,
                color: colorScheme.onSurface,
              ),
              title: Text(
                'Dark mode',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: userPreferences.isDarkModeEnabled,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Color theme — the available set depends on the mode:
          // dark = Monochrome / Gold / Emerald, light = Monochrome /
          // Pink / Gold / Red.
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              'Color theme',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _ThemePill(
                  title: 'Monochrome',
                  selected: colorTheme == AppColorTheme.mono,
                  onTap: () => ref
                      .read(colorThemeProvider.notifier)
                      .setTheme(AppColorTheme.mono),
                  fill: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFEDEDED),
                  textColor: isDark ? Colors.white : Colors.black,
                  selectedFill: isDark ? Colors.white : Colors.black,
                  selectedTextColor: isDark ? Colors.black : Colors.white,
                ),
                if (isDark)
                  _ThemePill(
                    title: 'Gold',
                    selected: colorTheme == AppColorTheme.gold,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.gold),
                    fill: const Color(0xFF2E2712),
                    textColor: const Color(0xFFE6C15A),
                    selectedFill: const Color(0xFFD4AF37),
                    selectedTextColor: const Color(0xFF1A1602),
                  ),
                if (isDark)
                  _ThemePill(
                    title: 'Emerald',
                    selected: colorTheme == AppColorTheme.emerald,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.emerald),
                    fill: const Color(0xFF12241B),
                    textColor: const Color(0xFF98D8B4),
                    selectedFill: const Color(0xFF4EA77D),
                    selectedTextColor: const Color(0xFF06130C),
                  ),
                if (isDark)
                  _ThemePill(
                    title: 'Red',
                    selected: colorTheme == AppColorTheme.red,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.red),
                    fill: const Color(0xFF2A1212),
                    textColor: const Color(0xFFF0A8A8),
                    selectedFill: const Color(0xFFE05252),
                    selectedTextColor: const Color(0xFF1A0A0A),
                  ),
                if (!isDark)
                  _ThemePill(
                    title: 'Pink',
                    selected: colorTheme == AppColorTheme.pink,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.pink),
                    fill: const Color(0xFFFBE9EE),
                    textColor: const Color(0xFFC2185B),
                    selectedFill: const Color(0xFFC2185B),
                    selectedTextColor: Colors.white,
                  ),
                if (!isDark)
                  _ThemePill(
                    title: 'Gold',
                    selected: colorTheme == AppColorTheme.gold,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.gold),
                    fill: const Color(0xFFF5EBCF),
                    textColor: const Color(0xFF8A6D1D),
                    selectedFill: const Color(0xFFD4AF37),
                    selectedTextColor: const Color(0xFF1A1602),
                  ),
                if (!isDark)
                  _ThemePill(
                    title: 'Red',
                    selected: colorTheme == AppColorTheme.red,
                    onTap: () => ref
                        .read(colorThemeProvider.notifier)
                        .setTheme(AppColorTheme.red),
                    fill: const Color(0xFFFCE8E8),
                    textColor: const Color(0xFFB71C1C),
                    selectedFill: const Color(0xFFC62828),
                    selectedTextColor: Colors.white,
                  ),
              ],
            ),

            const SizedBox(height: 20),

          // Font scale
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(
              'Font size (${(userPreferences.fontScale ?? 1.2).toStringAsFixed(1)}x)',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Slider(
                  value: userPreferences.fontScale ?? 1.2,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label:
                      '${(userPreferences.fontScale ?? 1.2).toStringAsFixed(1)}x',
                  onChanged: (value) async {
                    final updatedPreferences = userPreferences.copyWith(
                      fontScale: value,
                    );
                    await userPreferencesNotifier.updatePreferences(
                      updatedPreferences,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.8x', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      Text('1.2x', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      Text('1.6x', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.isDeveloperModeEnabled) ...[
            const SizedBox(height: 20),
            const DeveloperModeTiles(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Stadium-shaped theme selector pill (tinted fill + accent text).
class _ThemePill extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Color fill;
  final Color textColor;
  final Color selectedFill;
  final Color selectedTextColor;

  const _ThemePill({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.fill,
    required this.textColor,
    required this.selectedFill,
    required this.selectedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? selectedFill : fill,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? selectedTextColor : textColor,
          ),
        ),
      ),
    );
  }
}
