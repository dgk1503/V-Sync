import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/services/app_icon_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_shortcut.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_settings.dart';

/// Per-entry visibility toggles for the Academics hub and Home, the navbar, the
/// Thumb Dock and the app icon. Everything is visible by default, so users who
/// never open this page get the full app.
///
/// The Academics page has the most switches, so its per-page toggles fold into
/// one dropdown row.
class CustomizationPage extends ConsumerWidget {
  const CustomizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPreferences = ref.watch(userPreferencesProvider);
    final userPreferencesNotifier = ref.read(userPreferencesProvider.notifier);
    final dock = ref.watch(thumbDockProvider);
    final dockNotifier = ref.read(thumbDockProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    Widget sectionHeading(String text, {String? tag}) => Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              letterSpacing: 0.2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 10.5,
                  letterSpacing: 0.3,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget divider() => Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    Widget sectionCard({required List<Widget> children}) {
      final tiles = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        tiles.add(children[i]);
        if (i < children.length - 1) tiles.add(divider());
      }
      return AppCard(borderRadius: 16, child: Column(children: tiles));
    }

    Widget tile({
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
      String? subtitle,
    }) => ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                fontFamily: 'Instrument Sans',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Transform.scale(
        scale: 0.85,
        child: Switch.adaptive(value: value, onChanged: onChanged),
      ),
    );

    // Attendance, Marks and Exam Schedule always stay; these are the rest.
    final optionalPages = [
      !userPreferences.hideGrades,
      !userPreferences.hideBiometric,
      !userPreferences.hideDigitalAssignments,
      !userPreferences.hideOuting,
      !userPreferences.hideFacultyInfo,
      !userPreferences.hideOpenVtop,
      !userPreferences.hideAcademicCalendar,
    ];
    final shownCount = optionalPages.where((shown) => shown).length;

    return Scaffold(
      appBar: AppBar(
        title: AccentGradientText(
          'Customization',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          sectionHeading('Academics page'),
          sectionCard(
            children: [
              tile(
                title: 'Grid layout',
                subtitle: 'Show the options two per row instead of a list',
                value: !userPreferences.academicsListView,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                  userPreferences.copyWith(academicsListView: !value),
                ),
              ),
              _Dropdown(
                title: 'Pages shown',
                summary: '$shownCount of ${optionalPages.length}',
                children: [
                  tile(
                    title: 'Grades',
                    value: !userPreferences.hideGrades,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(hideGrades: !value),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Biometric Log',
                    value: !userPreferences.hideBiometric,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(hideBiometric: !value),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Digital Assignments',
                    value: !userPreferences.hideDigitalAssignments,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(
                            hideDigitalAssignments: !value,
                          ),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Outing',
                    value: !userPreferences.hideOuting,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(hideOuting: !value),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Faculty Info',
                    value: !userPreferences.hideFacultyInfo,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(hideFacultyInfo: !value),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Open VTOP',
                    value: !userPreferences.hideOpenVtop,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(hideOpenVtop: !value),
                        ),
                  ),
                  divider(),
                  tile(
                    title: 'Academic Calendar',
                    value: !userPreferences.hideAcademicCalendar,
                    onChanged: (value) =>
                        userPreferencesNotifier.updatePreferences(
                          userPreferences.copyWith(
                            hideAcademicCalendar: !value,
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          sectionHeading('Home page'),
          sectionCard(
            children: [
              tile(
                title: 'Class card slider',
                subtitle: 'Show current and upcoming classes on Home',
                value: userPreferences.classStackEnabled,
                onChanged: (value) => userPreferencesNotifier.updatePreferences(
                  userPreferences.copyWith(classStackEnabled: value),
                ),
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
                  userPreferences.copyWith(liquidGlassNavbar: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          sectionHeading('Thumb Dock', tag: 'beta'),
          sectionCard(
            children: [
              tile(
                title: 'Thumb Dock',
                subtitle:
                    'A handle on the screen edge. Hold it and slide to any page',
                value: dock.enabled,
                onChanged: dockNotifier.setEnabled,
              ),
              if (dock.enabled)
                tile(
                  title: 'Liquid Glass',
                  subtitle:
                      'Glass look for the dock. Turn off on slower phones',
                  value: dock.glass,
                  onChanged: dockNotifier.setGlass,
                ),
              if (dock.enabled)
                _DockShortcutPicker(
                  selected: dock.shortcuts,
                  onToggle: dockNotifier.toggleShortcut,
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

/// A row that unfolds to show more switches. Folded to start with.
class _Dropdown extends StatefulWidget {
  const _Dropdown({
    required this.title,
    required this.summary,
    required this.children,
  });

  final String title;

  /// What is currently chosen, shown on the right while folded.
  final String summary;
  final List<Widget> children;

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  widget.summary,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    ...widget.children,
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Chooses which pages sit in the dock's Academics row, in the order tapped.
class _DockShortcutPicker extends StatelessWidget {
  const _DockShortcutPicker({required this.selected, required this.onToggle});

  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final full = selected.length >= ThumbDockSettings.maxShortcuts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academics shortcuts',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Attendance and Marks always stay. Choose up to '
            '${ThumbDockSettings.customSlots} more, shown in the order you '
            'pick them',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final shortcut in DockShortcuts.all)
                FilterChip(
                  label: Text(shortcut.label),
                  avatar: Icon(shortcut.icon, size: 16),
                  selected: selected.contains(shortcut.id),
                  showCheckmark: false,
                  // The locked pair is shown chosen but cannot be changed.
                  onSelected:
                      (ThumbDockSettings.lockedShortcuts.contains(
                            shortcut.id,
                          ) ||
                          (!selected.contains(shortcut.id) && full))
                      ? null
                      : (_) => onToggle(shortcut.id),
                  disabledColor: selected.contains(shortcut.id)
                      ? colorScheme.primary.withValues(alpha: 0.6)
                      : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  labelStyle: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: selected.contains(shortcut.id)
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  side: BorderSide.none,
                  iconTheme: IconThemeData(
                    color: selected.contains(shortcut.id)
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Drag the handle to move it to either edge.',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 11.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
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
    return AppCard(
      borderRadius: 16,
      child: Padding(
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
                fontFamily: 'Instrument Sans',
                fontSize: 11,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
                        LucideIcons.check,
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
                fontFamily: 'Instrument Sans',
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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
