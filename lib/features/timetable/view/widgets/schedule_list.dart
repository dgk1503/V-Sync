import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/utils/format_to_12_hour.dart';
import 'package:vit_ap_student_app/core/utils/get_classes.dart';

/// Neutral (non-themed) text colors for the timetable — class content
/// stays monochrome in every accent theme; only the day chips and the
/// background aura carry the theme color.
Color _neutralText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

Color _neutralMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB3B3B3)
        : const Color(0xFF4D4D4D);

class ScheduleList extends ConsumerStatefulWidget {
  final String day;
  final Future<void> Function()? onRefresh;

  const ScheduleList({super.key, required this.day, this.onRefresh});

  @override
  ConsumerState<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends ConsumerState<ScheduleList> {
  OverlayEntry? _overlayEntry;
  Day? _selectedClass;

  /// Labs run ~2 hours (e.g. 8:00 - 9:50), theory runs 50 minutes.
  bool _isLab(Day classInfo) => isLabClass(classInfo);

  int _parseMinutes(String? time) {
    if (time == null || time.isEmpty) return 0;
    try {
      final parts = time.trim().split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted && _selectedClass != null) {
      setState(() => _selectedClass = null);
    }
  }

  void _toggleDetails(Day classInfo) {
    if (_selectedClass == classInfo) {
      _removeOverlay();
      return;
    }

    _removeOverlay();
    setState(() => _selectedClass = classInfo);
    _overlayEntry = OverlayEntry(
      builder: (context) => _DetailsOverlay(
        onDismiss: _removeOverlay,
        child: _ClassDetailsCard(classInfo: classInfo),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Fading hairline that separates consecutive classes without turning
  /// the list into a stack of boxes.
  Widget _classDivider(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.7),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  /// Slightly stronger gradient divider between Morning and Afternoon.
  Widget _sectionDivider(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    String title,
    List<Day> classes,
  ) {
    if (classes.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 20, bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
              ),
        ),
      ),
      for (var i = 0; i < classes.length; i++) ...[
        if (i > 0) _classDivider(context),
        _ClassRow(
          classInfo: classes[i],
          isSelected: _selectedClass == classes[i],
          isLab: _isLab(classes[i]),
          onTap: () => _toggleDetails(classes[i]),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final timetable = user?.timetable.target;

    if (timetable == null) return const SizedBox.shrink();

    final classes = getClassesForDay(timetable, widget.day)
      ..sort((a, b) =>
          _parseMinutes(a.startTime).compareTo(_parseMinutes(b.startTime)));

    if (classes.isEmpty) return const SizedBox.shrink();

    // Morning: the last morning slot is the 12:00-12:50 theory class
    // (labs start no later than 11:45), so anything starting before
    // 1:00 PM is morning. Afternoon classes begin at 2:00 PM.
    final morning =
        classes.where((c) => _parseMinutes(c.startTime) < 780).toList();
    final afternoon =
        classes.where((c) => _parseMinutes(c.startTime) >= 780).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh?.call();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          ..._buildSection(context, 'Morning', morning),
          if (morning.isNotEmpty && afternoon.isNotEmpty)
            _sectionDivider(context),
          ..._buildSection(context, 'Afternoon', afternoon),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }
}

/// Blurred barrier + centered details card shown above everything.
class _DetailsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  final Widget child;

  const _DetailsOverlay({
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withValues(alpha: 0.2),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  child: child,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth - 32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The minimal per-class row shown inline in the list.
class _ClassRow extends StatelessWidget {
  final Day classInfo;
  final bool isSelected;
  final bool isLab;
  final VoidCallback onTap;

  const _ClassRow({
    required this.classInfo,
    required this.isSelected,
    required this.isLab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.surfaceContainerLow
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    classInfo.courseName ?? 'N/A',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _neutralText(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TypePill(isLab: isLab),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Iconsax.clock_copy,
                  size: 13,
                  color: _neutralMuted(context),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatTimeRange(classInfo.startTime, classInfo.endTime),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: _neutralMuted(context),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 10,
                      color: _neutralMuted(context),
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    classInfo.venue ?? 'N/A',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: _neutralMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final bool isLab;

  const _TypePill({required this.isLab});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: isLab ? _neutralText(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: isLab
            ? null
            : Border.all(color: colorScheme.outlineVariant, width: 1.2),
      ),
      child: Text(
        isLab ? 'LAB' : 'THEORY',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isLab
              ? Theme.of(context).colorScheme.surface
              : _neutralText(context),
        ),
      ),
    );
  }
}

/// Full detail card revealed when a class is tapped.
class _ClassDetailsCard extends StatelessWidget {
  final Day classInfo;

  const _ClassDetailsCard({required this.classInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLab = isLabClass(classInfo);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    classInfo.courseName ?? 'N/A',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _neutralText(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TypePill(isLab: isLab),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _DetailRow(label: 'Faculty', value: classInfo.faculty),
            _DetailRow(label: 'Course code', value: classInfo.courseCode),
            _DetailRow(
                label: 'Timing',
                value:
                    formatTimeRange(classInfo.startTime, classInfo.endTime)),
            _DetailRow(label: 'Slot', value: classInfo.slot),
            _DetailRow(label: 'Venue', value: classInfo.venue),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: _neutralMuted(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value!.trim().isEmpty) ? 'N/A' : value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _neutralText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

