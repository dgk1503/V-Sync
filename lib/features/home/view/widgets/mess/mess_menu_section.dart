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
import 'package:vit_ap_student_app/features/home/view/widgets/mess/mess_sheet_page.dart';
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
    final source = ref.watch(messSourceProvider);
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
                  fontWeight: FontWeight.w500,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Takes all the room the title leaves, so a longer label
              // ("November · Special") is not squeezed to half of it.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _openManageSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      _headerLabel(menu, source != null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (menu == null && source == null)
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
                      fontFamily: 'Instrument Sans',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (menu == null)
          // The file could not be read as a menu, so the original is shown.
          _DocumentCard(
            source: source!,
            onUpload: _openManageSheet,
            onView: () => _openSource(context, source),
          )
        else if (menu.hasEnded(DateTime.now()))
          // The month this menu was for is over: ask for the new one.
          _NextMonthCard(endedMonth: menu.monthName, onUpload: _openManageSheet)
        else ...[
          _buildDateNavigator(context, menu),
          const SizedBox(height: 14),
          _buildMealSwitcher(context),
          const SizedBox(height: 6),
          _buildMenuItems(context, menu),
          _buildEndingSoonHint(context),
        ],
        // Keep the last menu row clear of the floating navigation capsule.
        const SizedBox(height: 88),
      ],
    );
  }

  /// The word on the right of the title. It opens the sheet where the menu is
  /// uploaded, deleted and (when the workbook has several) chosen, so once a
  /// menu other than the first is chosen its name is shown here too.
  String _headerLabel(MessMenu? menu, bool hasSource) {
    if (menu == null) return hasSource ? 'Manage' : 'Upload';
    if (menu.sheetNames.length > 1) {
      final sheet = _effectiveSheet(menu);
      if (sheet != menu.sheetNames.first) return '${menu.monthName} · $sheet';
    }
    return menu.monthName;
  }

  /// The sheet in use: the one the student chose, or the first when they have
  /// not chosen yet or chose one this month's workbook does not have.
  String _effectiveSheet(MessMenu menu) {
    final chosen = ref.watch(messSheetProvider);
    return chosen != null && menu.sheetNames.contains(chosen)
        ? chosen
        : menu.sheetNames.first;
  }

  /// A quiet nudge for the last few days of the month, so the next menu is
  /// uploaded before the old one runs out rather than after.
  Widget _buildEndingSoonHint(BuildContext context) {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month + 1, 0).day - now.day;
    if (left > 2) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final text = left == 0
        ? 'This is the last day of this menu. Upload next month\'s menu from '
              'your email when it arrives.'
        : 'This menu ends in $left ${left == 1 ? 'day' : 'days'}. Upload next '
              'month\'s menu from your email when it arrives.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 12.5,
          height: 1.4,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
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
            fontFamily: 'Instrument Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
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

    final dayMenu = menu.menuFor(
      _selectedDate.day,
      sheet: _effectiveSheet(menu),
    );
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
                      fontFamily: 'Instrument Sans',
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
                                  fontFamily: 'Instrument Sans',
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

    final result = await ref
        .read(messMenuProvider.notifier)
        .importFile(Uint8List.fromList(bytes), file.name);

    if (!context.mounted) return;
    switch (result) {
      case MessImportResult.menu:
        Navigator.of(context).pop();
        showToast(context, 'Mess menu imported');
      case MessImportResult.document:
        Navigator.of(context).pop();
        showToast(
          context,
          "Couldn't read that as a day-by-day menu, so it's shown as the sheet it came as",
        );
      case MessImportResult.failed:
        showToast(context, 'Could not save that file');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(messMenuProvider);
    final source = ref.watch(messSourceProvider);
    final chosen = ref.watch(messSheetProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // A workbook can carry more than one mess menu ("Veg & Non-Veg",
    // "Special"). The student picks theirs here, once, and it is remembered.
    final names = menu?.sheetNames ?? const <String>[];
    final selected = chosen != null && names.contains(chosen)
        ? chosen
        : (names.isEmpty ? null : names.first);

    // Sized to its content and scrollable if the screen is short, and kept
    // clear of the system navigation bar: the last action (Delete) must never
    // be pushed below the edge of the screen.
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  menu != null
                      ? '${menu.monthName} ${menu.year} · '
                            '${menu.days.length} days'
                      : source != null
                      ? 'Showing the original file: ${source.name}'
                      : 'No menu uploaded yet',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (selected != null && names.length > 1) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Show menu',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SheetPills(
                    names: names,
                    selected: selected,
                    onSelect: (name) =>
                        ref.read(messSheetProvider.notifier).choose(name),
                  ),
                ],
                const SizedBox(height: 20),
                _SheetAction(
                  icon: Iconsax.document_upload_copy,
                  title: 'Insert Excel file',
                  subtitle: 'Upload your mess menu (.xlsx)',
                  onTap: () => _importFromPicker(context, ref),
                ),
                const SizedBox(height: 10),
                if (source != null) ...[
                  _SheetAction(
                    icon: Iconsax.document_upload_copy,
                    title: 'View original sheet',
                    subtitle: source.name,
                    onTap: () => _openSource(context, source),
                  ),
                  const SizedBox(height: 10),
                ],
                if (menu != null || source != null)
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
          ),
        ),
      ),
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
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
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

/// Opens the spreadsheet a menu came from, as a table inside the app.
Future<void> _openSource(BuildContext context, MessSource source) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MessSheetPage(source: source)),
  );
}

/// Shown instead of the day-by-day menu when the file could not be read as one.
///
/// Hostels send their menus in different shapes. A menu the reader half
/// understands would look authoritative and be wrong, so the original file is
/// shown instead, as it came.
class _DocumentCard extends StatelessWidget {
  final MessSource source;
  final VoidCallback onUpload;
  final VoidCallback onView;

  const _DocumentCard({
    required this.source,
    required this.onUpload,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stale = source.isFromEarlierMonth(DateTime.now());

    TextStyle body() => TextStyle(
      fontFamily: 'Instrument Sans',
      fontSize: 13,
      height: 1.4,
      color: colorScheme.onSurfaceVariant,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 22,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "This file couldn't be read as a day-by-day menu, so it's shown as "
            'the sheet it came as.',
            style: body(),
          ),
          if (stale) ...[
            const SizedBox(height: 8),
            Text(
              'Added in ${DateFormat('MMMM').format(source.importedAt)}. If '
              "this month's menu is out, upload it from your email.",
              style: body(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View menu',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onUpload,
                child: const Text(
                  'Upload another',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown once the month a menu was for has finished.
///
/// Showing the old menu would put last month's food under today's date; the
/// useful thing is to ask for the new one, which the hostel emails each month.
class _NextMonthCard extends StatelessWidget {
  final String endedMonth;
  final VoidCallback onUpload;

  const _NextMonthCard({required this.endedMonth, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thisMonth = DateFormat('MMMM').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$endedMonth's menu is over",
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Download $thisMonth's mess menu (.xlsx) from your email and "
            'upload it here.',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              elevation: 0,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Upload $thisMonth's menu",
              style: const TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The menus a workbook carries, as the same selected-pill the rest of the app
/// uses for a choice among a few.
class _SheetPills extends StatelessWidget {
  final List<String> names;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SheetPills({
    required this.names,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.zero,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in names)
            Semantics(
              button: true,
              selected: name == selected,
              child: InkWell(
                onTap: () => onSelect(name),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: name == selected
                        ? colors.primary
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: name == selected
                          ? colors.onPrimary
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
