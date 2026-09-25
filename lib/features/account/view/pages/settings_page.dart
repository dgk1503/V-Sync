import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/color_theme_notifier.dart';
import 'package:vit_ap_student_app/core/providers/custom_accent_provider.dart';
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
  Future<void> _pickCustomColor() async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _CustomColorPicker(selectedColor: ref.read(customAccentProvider)),
    );
    if (!mounted || selected == null) return;
    await ref.read(customAccentProvider.notifier).setColor(selected);
    await ref.read(colorThemeProvider.notifier).setTheme(AppColorTheme.custom);
  }

  @override
  Widget build(BuildContext context) {
    final userPreferences = ref.watch(userPreferencesProvider);
    final userPreferencesNotifier = ref.read(userPreferencesProvider.notifier);
    final colorTheme = ref.watch(colorThemeProvider);
    final customAccent = ref.watch(customAccentProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: AccentGradientText(
          'Appearance',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        actions: [
          if (widget.isDeveloperModeEnabled)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(LucideIcons.fingerprint, size: 22),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          // One single settings section. Everything (dark mode, colour
          // theme, font size) lives in this one card, and every block gets
          // the SAME padding and the same divider treatment, so the rows
          // read as one evenly spaced group instead of three separate
          // cards with mismatched gaps.
          AppCard(
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dark mode
                Padding(
                  padding: _rowPadding,
                  child: Row(
                    children: [
                      Icon(
                        userPreferences.isDarkModeEnabled ||
                                !userPreferences.hasUserChosenTheme
                            ? LucideIcons.moon
                            : LucideIcons.sun,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Dark mode',
                          style: TextStyle(
                            fontSize: 15.5,
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.85,
                        child: Switch.adaptive(
                          value:
                              userPreferences.isDarkModeEnabled ||
                              !userPreferences.hasUserChosenTheme,
                          onChanged: (value) {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const _RowDivider(),

                // Colour theme — the available set depends on the mode:
                // dark = Monochrome / Gold / Emerald, light = Monochrome /
                // Pink / Gold / Red.
                Padding(
                  padding: _rowPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color theme',
                        style: TextStyle(
                          fontSize: 15.5,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 8,
                        runSpacing: 8,
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
                            selectedTextColor: isDark
                                ? Colors.black
                                : Colors.white,
                          ),
                          if (isDark)
                            _ThemePill(
                              title: 'Gold',
                              selected: colorTheme == AppColorTheme.gold,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.gold),
                              fill: AppThemeAccent.goldDark.accent,
                              textColor: AppThemeAccent.goldDark.onAccent,
                              selectedFill: AppThemeAccent.goldDark.accent,
                              selectedTextColor:
                                  AppThemeAccent.goldDark.onAccent,
                            ),
                          if (isDark)
                            _ThemePill(
                              title: 'Emerald',
                              selected: colorTheme == AppColorTheme.emerald,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.emerald),
                              fill: AppThemeAccent.emeraldDark.accent,
                              textColor: AppThemeAccent.emeraldDark.onAccent,
                              selectedFill: AppThemeAccent.emeraldDark.accent,
                              selectedTextColor:
                                  AppThemeAccent.emeraldDark.onAccent,
                            ),
                          if (isDark)
                            _ThemePill(
                              title: 'Red',
                              selected: colorTheme == AppColorTheme.red,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.red),
                              fill: AppThemeAccent.redDark.accent,
                              textColor: AppThemeAccent.redDark.onAccent,
                              selectedFill: AppThemeAccent.redDark.accent,
                              selectedTextColor:
                                  AppThemeAccent.redDark.onAccent,
                            ),
                          if (!isDark)
                            _ThemePill(
                              title: 'Pink',
                              selected: colorTheme == AppColorTheme.pink,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.pink),
                              fill: AppThemeAccent.pinkLight.accent,
                              textColor: AppThemeAccent.pinkLight.onAccent,
                              selectedFill: AppThemeAccent.pinkLight.accent,
                              selectedTextColor:
                                  AppThemeAccent.pinkLight.onAccent,
                            ),
                          if (!isDark)
                            _ThemePill(
                              title: 'Gold',
                              selected: colorTheme == AppColorTheme.gold,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.gold),
                              fill: AppThemeAccent.goldLight.accent,
                              textColor: AppThemeAccent.goldLight.onAccent,
                              selectedFill: AppThemeAccent.goldLight.accent,
                              selectedTextColor:
                                  AppThemeAccent.goldLight.onAccent,
                            ),
                          if (!isDark)
                            _ThemePill(
                              title: 'Red',
                              selected: colorTheme == AppColorTheme.red,
                              onTap: () => ref
                                  .read(colorThemeProvider.notifier)
                                  .setTheme(AppColorTheme.red),
                              fill: AppThemeAccent.redLight.accent,
                              textColor: AppThemeAccent.redLight.onAccent,
                              selectedFill: AppThemeAccent.redLight.accent,
                              selectedTextColor:
                                  AppThemeAccent.redLight.onAccent,
                            ),
                          _ThemePill(
                            title: 'Custom',
                            selected: colorTheme == AppColorTheme.custom,
                            onTap: _pickCustomColor,
                            fill:
                                customAccent ??
                                (isDark
                                    ? const Color(0xFF1B1B1F)
                                    : const Color(0xFFECECF0)),
                            textColor: customAccent == null
                                ? (isDark ? Colors.white : Colors.black)
                                : _onAccent(customAccent),
                            selectedFill:
                                customAccent ??
                                (isDark ? Colors.white : Colors.black),
                            selectedTextColor: customAccent == null
                                ? (isDark ? Colors.black : Colors.white)
                                : _onAccent(customAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const _RowDivider(),

                // Font size
                Padding(
                  padding: _rowPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.type,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Font size',
                            style: TextStyle(
                              fontSize: 15.5,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(userPreferences.fontScale ?? 1.2).toStringAsFixed(1)}x',
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0.8x',
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '1.2x',
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '1.6x',
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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

/// Even padding for every block inside the single settings section card.
const _rowPadding = EdgeInsets.fromLTRB(16, 14, 16, 14);

/// Hairline divider between blocks of the settings section, inset so it
/// starts where the row text starts rather than at the card edge.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

Color _onAccent(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

class _CustomColorPicker extends StatelessWidget {
  final Color? selectedColor;

  const _CustomColorPicker({required this.selectedColor});

  static const colors = <Color>[
    Color(0xFFB8A9F2),
    Color(0xFFF2A7C3),
    Color(0xFF9EDCEB),
    Color(0xFFC4E266),
    Color(0xFFD98C5F),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose accent color',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final color in colors)
                  _ColorSwatch(
                    color: color,
                    selected: color == selectedColor,
                    onTap: () => Navigator.of(context).pop(color),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = _onAccent(color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(LucideIcons.check, size: 20, color: foreground)
            : null,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          color: selected ? selectedFill : fill,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedFill.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w500,
            color: selected ? selectedTextColor : textColor,
          ),
        ),
      ),
    );
  }
}
