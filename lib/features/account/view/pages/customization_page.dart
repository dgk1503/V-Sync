import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/services/app_icon_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';

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
          sectionHeading('App icon'),
          const _AppIconPicker(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Launcher icon chooser. Previews are rendered from the same assets used
/// to build the adaptive icons; the selected state is read from the
/// platform (activity-alias enable state) so it always matches the real
/// launcher icon.
class _AppIconPicker extends StatefulWidget {
  const _AppIconPicker();

  @override
  State<_AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<_AppIconPicker> {
  AppIconVariant _current = AppIconVariant.defaultIcon;
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    AppIconService.getCurrent().then((variant) {
      if (!mounted) return;
      setState(() {
        _current = variant;
        _loading = false;
      });
    });
  }

  Future<void> _pick(AppIconVariant variant) async {
    if (_loading || _switching || variant.id == _current.id) return;
    setState(() => _switching = true);
    try {
      await AppIconService.setIcon(variant);
      if (!mounted) return;
      setState(() => _current = variant);
      showSnackBar(
        context,
        'App icon updated — it may take a few seconds to show up',
        SnackBarType.success,
      );
    } catch (_) {
      if (mounted) {
        showSnackBar(
          context,
          'Could not change the app icon',
          SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < AppIconVariant.all.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _IconPreviewTile(
                    variant: AppIconVariant.all[i],
                    selected: AppIconVariant.all[i].id == _current.id,
                    dimmed: _loading || _switching,
                    onTap: () => _pick(AppIconVariant.all[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'changes the icon on your home screen. some launchers take a '
            'moment to refresh.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPreviewTile extends StatelessWidget {
  const _IconPreviewTile({
    required this.variant,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final AppIconVariant variant;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.55 : 1,
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      // Same background the launcher draws behind the
                      // adaptive icon foreground.
                      color: const Color(0xFF080808),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        width: selected ? 2 : 1,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      variant.previewAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Iconsax.tick_circle,
                        size: 12,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              variant.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
