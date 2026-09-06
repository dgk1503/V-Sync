import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/segmented_tab_switcher.dart';
import 'package:vit_ap_student_app/core/utils/show_toast.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/mess_menu_viewmodel.dart';

class MessMenuSection extends ConsumerStatefulWidget {
  const MessMenuSection({super.key});

  @override
  ConsumerState<MessMenuSection> createState() => _MessMenuSectionState();
}

class _MessMenuSectionState extends ConsumerState<MessMenuSection>
    with SingleTickerProviderStateMixin {
  static const _mealNames = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

  late final TabController _mealTabController;
  late DateTime _selectedDate;
  bool _mealTouchedManually = false;
  bool _autoSyncingMeal = false;
  Timer? _clockTicker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _mealTabController = TabController(
      length: _mealNames.length,
      vsync: this,
      initialIndex: _mealForTime(now),
    );
    _mealTabController.addListener(() {
      if (_mealTabController.indexIsChanging) return;
      if (!_autoSyncingMeal) _mealTouchedManually = true;
      setState(() {});
    });
    // Follow the time of day until the user picks a meal themselves.
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _mealTouchedManually) return;
      final meal = _mealForTime(DateTime.now());
      if (meal != _mealTabController.index) {
        _autoSyncingMeal = true;
        _mealTabController.index = meal;
        _autoSyncingMeal = false;
      }
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _mealTabController.dispose();
    super.dispose();
  }

  int _mealForTime(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (minutes < 10 * 60 + 30) return 0; // Breakfast
    if (minutes < 15 * 60) return 1; // Lunch
    if (minutes < 18 * 60 + 30) return 2; // Snacks
    return 3; // Dinner
  }

  void _openManageSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MessMenuManageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(messMenuProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Keep the browsed date inside the uploaded menu's month: snap to
    // today when viewing the current month, otherwise to the first day
    // that has data.
    if (menu != null) {
      final inMenuMonth =
          _selectedDate.year == menu.year && _selectedDate.month == menu.month;
      if (!inMenuMonth) {
        final now = DateTime.now();
        if (menu.month == now.month && menu.year == now.year) {
          _selectedDate = DateTime(now.year, now.month, now.day);
        } else {
          _selectedDate = DateTime(menu.year, menu.month, menu.firstDay ?? 1);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Row(
            children: [
              AccentGradientText(
                'Mess Menu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openManageSheet,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  menu?.monthName ?? 'Upload',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (menu == null)
          // First-time hint
          GestureDetector(
            onTap: _openManageSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.document_upload_copy,
                    size: 26,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your mess menu',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _buildDateNavigator(context, menu),
          const SizedBox(height: 14),
          _buildMealSwitcher(context),
          const SizedBox(height: 6),
          _buildMenuItems(context, menu),
        ],
      ],
    );
  }

  Widget _buildDateNavigator(BuildContext context, MessMenu menu) {
    final colorScheme = Theme.of(context).colorScheme;
    final minDay = menu.firstDay ?? 1;
    final maxDay = menu.lastDay ?? 31;

    final canGoBack = _selectedDate.day > minDay;
    final canGoForward = _selectedDate.day < maxDay;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoBack
              ? () => setState(() {
                  _selectedDate = _selectedDate.subtract(
                    const Duration(days: 1),
                  );
                })
              : null,
          icon: Icon(
            Iconsax.arrow_left_2_copy,
            size: 18,
            color: canGoBack
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${DateFormat('d MMM').format(_selectedDate)} · '
          '${DateFormat('EEE').format(_selectedDate)}',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: canGoForward
              ? () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                })
              : null,
          icon: Icon(
            Iconsax.arrow_right_3_copy,
            size: 18,
            color: canGoForward
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSwitcher(BuildContext context) {
    // Same capsule segmented control as attendance/marks/exam: all four
    // meals fit on screen, the pill slides with taps and swipes.
    return SegmentedTabSwitcher(
      controller: _mealTabController,
      labels: _mealNames,
    );
  }

  Widget _buildMenuItems(BuildContext context, MessMenu menu) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedMeal = _mealTabController.index;

    final dayMenu = menu.menuFor(_selectedDate.day);
    final items = dayMenu?.forMeal(selectedMeal) ?? const [];

    // Swipe left/right on the menu area to move between meals; the capsule
    // pill follows the controller's animation.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        const threshold = 120.0;
        if (velocity < -threshold &&
            _mealTabController.index < _mealNames.length - 1) {
          _mealTabController.animateTo(_mealTabController.index + 1);
        } else if (velocity > threshold && _mealTabController.index > 0) {
          _mealTabController.animateTo(_mealTabController.index - 1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: items.isEmpty
            ? Padding(
                key: ValueKey('empty-$selectedMeal-${_selectedDate.day}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: Text(
                    dayMenu == null
                        ? 'No menu for this day'
                        : 'No ${_mealNames[selectedMeal].toLowerCase()} listed',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : Padding(
                key: ValueKey('items-$selectedMeal-${_selectedDate.day}'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.outlineVariant.withValues(alpha: 0),
                                colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                                colorScheme.outlineVariant.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                items[i],
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Draggable bottom sheet to import or delete the mess menu Excel file.
class _MessMenuManageSheet extends ConsumerWidget {
  const _MessMenuManageSheet();

  Future<void> _importFromPicker(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (file == null) return;

    final path = file.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();

    final ok = await ref
        .read(messMenuProvider.notifier)
        .importFromBytes(Uint8List.fromList(bytes));

    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      showToast(context, 'Mess menu imported');
    } else {
      showToast(context, 'Could not read a mess menu from that file');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(messMenuProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mess menu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                menu == null
                    ? 'No menu uploaded yet'
                    : '${menu.monthName} ${menu.year} · '
                          '${menu.days.length} days',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _SheetAction(
                icon: Iconsax.document_upload_copy,
                title: 'Insert Excel file',
                subtitle: 'Upload your mess menu (.xlsx)',
                onTap: () => _importFromPicker(context, ref),
              ),
              const SizedBox(height: 10),
              if (menu != null)
                _SheetAction(
                  icon: Iconsax.trash_copy,
                  title: 'Delete menu',
                  subtitle: 'Remove the uploaded menu from this device',
                  destructive: true,
                  onTap: () async {
                    await ref.read(messMenuProvider.notifier).delete();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = destructive ? Colors.red : colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.75),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
