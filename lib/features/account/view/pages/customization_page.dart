import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/models/user_preferences.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';

/// Per-entry visibility toggles for the Academics hub, plus the
/// experimental Liquid Glass navbar. Everything is visible by default, so
/// users who never open this page get the full app; hiding an entry
/// removes it from the Academics hub.
class CustomizationPage extends ConsumerWidget {
  const CustomizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPreferences = ref.watch(userPreferencesProvider);
    final userPreferencesNotifier = ref.read(userPreferencesProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    Widget sectionHeading(String text) => Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              letterSpacing: 0.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );

    Widget sectionCard({required List<Widget> children}) {
      final tiles = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        tiles.add(children[i]);
        if (i < children.length - 1) {
          tiles.add(Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ));
        }
      }
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(children: tiles),
      );
    }

    Widget tile({
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
      String? subtitle,
    }) =>
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(value: value, onChanged: onChanged),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: AccentGradientText(
          'Customization',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          sectionHeading('Academics page'),
          sectionCard(
            children: [
              tile(
                title: 'Grades',
                value: !userPreferences.hideGrades,
                onChanged: (value) => userPreferencesNotifier
                    .updatePreferences(
                        userPreferences.copyWith(hideGrades: !value)),
              ),
              tile(
                title: 'Digital Assignments',
                value: !userPreferences.hideDigitalAssignments,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                    userPreferences.copyWith(hideDigitalAssignments: !value)),
              ),
              tile(
                title: 'Outing',
                value: !userPreferences.hideOuting,
                onChanged: (value) => userPreferencesNotifier
                    .updatePreferences(
                        userPreferences.copyWith(hideOuting: !value)),
              ),
              tile(
                title: 'Faculty Info',
                value: !userPreferences.hideFacultyInfo,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                    userPreferences.copyWith(hideFacultyInfo: !value)),
              ),
              tile(
                title: 'Open VTOP',
                value: !userPreferences.hideOpenVtop,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                    userPreferences.copyWith(hideOpenVtop: !value)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          sectionHeading('Navbar'),
          sectionCard(
            children: [
              tile(
                title: 'Liquid Glass',
                subtitle: 'May affect performance on low-end devices',
                value: userPreferences.liquidGlassNavbar,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                    userPreferences.copyWith(liquidGlassNavbar: value)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
