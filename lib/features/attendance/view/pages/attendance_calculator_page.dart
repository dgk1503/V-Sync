import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/providers/color_theme_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_bottom_sheet.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_calendar_card.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/detailed_attendance_viewmodel.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

class AttendanceCalculatorPage extends ConsumerStatefulWidget {
  final Attendance attendance;

  const AttendanceCalculatorPage({super.key, required this.attendance});

  @override
  ConsumerState<AttendanceCalculatorPage> createState() =>
      _AttendanceCalculatorPageState();
}

class _AttendanceCalculatorPageState
    extends ConsumerState<AttendanceCalculatorPage> {
  late int attended;
  late int total;
  bool editCurrent = false;

  @override
  void initState() {
    super.initState();
    attended = int.tryParse(widget.attendance.attendedClasses) ?? 0;
    total = int.tryParse(widget.attendance.totalClasses) ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Always ask for this course's records: the viewmodel paints the cached
      // copy first and then refreshes, so this costs nothing on a warm start.
      ref
          .read(detailedAttendanceViewmodelProvider.notifier)
          .fetchDetailedAttendance(
            courseId: widget.attendance.courseId,
            courseType: widget.attendance.courseTypeCode,
          );
      // The calendar below is a different provider that nothing else warms, so
      // without this the "N left until FAT" count is blank until the user
      // happens to open Academics > Calendar first. `ensureLoaded` is a no-op
      // when the cache is still fresh.
      ref.read(calendarViewmodelProvider.notifier).ensureLoaded();
    });
  }

  double get _currentPercentage => total == 0 ? 0.0 : (attended / total) * 100;

  Color _pctColor(double pct, ColorScheme cs) {
    if (pct >= 75) return const Color(0xFF2E7D32);
    if (pct >= 65) return const Color(0xFFE65100);
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorTheme = ref.watch(colorThemeProvider);
    final isGoldTheme = colorTheme == AppColorTheme.gold && isDark;
    final isEmeraldTheme = colorTheme == AppColorTheme.emerald && isDark;
    final isRedDark = colorTheme == AppColorTheme.red && isDark;
    final isPinkLight = colorTheme == AppColorTheme.pink && !isDark;
    final isGoldLight = colorTheme == AppColorTheme.gold && !isDark;
    final isRedLight = colorTheme == AppColorTheme.red && !isDark;

    // Accent heading color for themed modes.
    Color headingColor() {
      if (isEmeraldTheme) return EmeraldPalette.primaryText;
      if (isGoldTheme) return GoldPalette.primaryText;
      if (isRedDark) return RedPalette.primaryText;
      if (isGoldLight) return const Color(0xFFB08D26);
      if (isPinkLight) return const Color(0xFFC2185B);
      if (isRedLight) return const Color(0xFFB71C1C);
      return cs.onSurface;
    }

    final presentColor = const Color(0xFF2E7D32);
    final absentColor = cs.error;
    final cardBg = isDark ? cs.surfaceContainer : cs.surfaceContainerLow;
    final cardBorder = cs.outlineVariant;
    final captionColor = cs.onSurfaceVariant;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        title: Text(
          'Attendance Calculator',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: headingColor(),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                showAttendanceBottomSheet(context, widget.attendance),
            icon: Icon(Icons.list_alt, size: 18, color: captionColor),
            label: Text(
              'Details',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                color: captionColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Course header ──
            _buildCourseHeader(cs, headingColor(), captionColor),
            const SizedBox(height: 20),

            // ── Current attendance card ──
            _buildCurrentCard(
              cs,
              cardBg,
              cardBorder,
              captionColor,
              presentColor,
              absentColor,
              isDark,
            ),
            const SizedBox(height: 16),

            // ── Day-wise attendance, month by month ──
            _buildCalendarCard(cs, cardBg, cardBorder, captionColor),

            // ── Attendance Details (inline) ──
            _buildDetailsHeader(cs, captionColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseHeader(ColorScheme cs, Color heading, Color caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.attendance.courseName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: heading,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.attendance.courseCode}  •  ${widget.attendance.faculty}',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 13,
            color: caption,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentCard(
    ColorScheme cs,
    Color cardBg,
    Color cardBorder,
    Color caption,
    Color presentColor,
    Color absentColor,
    bool isDark,
  ) {
    final pct = _currentPercentage;
    final pctCol = _pctColor(pct, cs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 0.75),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: caption),
              const SizedBox(width: 8),
              Text(
                'Current Attendance',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Edit',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12,
                  color: caption,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: editCurrent,
                  onChanged: (v) => setState(() => editCurrent = v),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isDark ? Colors.white : Colors.black;
                    }
                    return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isDark ? Colors.white24 : Colors.black26;
                    }
                    return cardBorder;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Percentage ring + number
          SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 10,
                    backgroundColor: cardBorder,
                    valueColor: AlwaysStoppedAnimation(pctCol),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: pctCol,
                      ),
                    ),
                    Text(
                      '$attended / $total',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attended / Skipped counters
          Row(
            children: [
              Expanded(
                child: _buildCounter(
                  cs: cs,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  label: 'Attended',
                  value: attended,
                  color: presentColor,
                  enable: editCurrent,
                  onInc: () => setState(() {
                    attended++;
                    total++;
                  }),
                  onDec: () {
                    if (attended > 0) {
                      setState(() {
                        attended--;
                        total--;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCounter(
                  cs: cs,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  label: 'Skipped',
                  value: total - attended,
                  color: absentColor,
                  enable: editCurrent,
                  onInc: () => setState(() {
                    total++;
                  }),
                  onDec: () {
                    if (total > attended) {
                      setState(() {
                        total--;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Day-wise attendance as month grids, plus how many classes are left before
  /// the next FAT. Both need data the calculator does not hold, so they are
  /// watched here rather than threaded through the route.
  Widget _buildCalendarCard(
    ColorScheme cs,
    Color cardBg,
    Color cardBorder,
    Color caption,
  ) {
    final courseCode = widget.attendance.courseCode.trim();
    // The calendar viewmodel already exposes the flattened, date-ordered months.
    final months =
        ref.watch(calendarViewmodelProvider).asData?.value ??
        const <CalendarMonth>[];
    final timetable = ref.watch(timetableViewModelProvider)?.asData?.value;
    final detailsState = ref.watch(detailedAttendanceViewmodelProvider);
    final details = detailsState?.asData?.value;
    // "Still fetching", "VTOP could not be reached" and "nothing posted" all
    // used to render as the same line of text, so a broken fetch looked
    // identical to an empty course.
    final emptyReason = switch (detailsState) {
      null => EmptyReason.loading,
      AsyncLoading() => EmptyReason.loading,
      AsyncError() => EmptyReason.failed,
      _ => EmptyReason.notPosted,
    };
    // VTOP marks a FAT day as an exam, but only says "FAT" in the entry's
    // description. Fall back to the next exam of any kind so the count still
    // appears when VTOP words the entry differently.
    final fatDate = months.isEmpty
        ? null
        : (AttendanceProjection.firstDayWhere(
                months,
                DateTime.now(),
                (kind, text) =>
                    kind == CalendarDayKind.exam && text.contains('fat'),
              ) ??
              AttendanceProjection.firstDayWhere(
                months,
                DateTime.now(),
                (kind, _) => kind == CalendarDayKind.exam,
              ));
    final classesLeft = (fatDate == null || timetable == null || courseCode.isEmpty)
        ? null
        : AttendanceProjection.classesLeftUntil(
            courseCode: courseCode,
            timetable: timetable,
            months: months,
            now: DateTime.now(),
            until: fatDate,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Calendar',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ClassesLeftCaption(classesLeft: classesLeft),
          if ((classesLeft ?? 0) > 0) const SizedBox(height: 14),
          AttendanceMonthCard(
            details: details ?? const [],
            emptyReason: emptyReason,
          ),
        ],
      ),
    );
  }

  Widget _buildCounter({
    required ColorScheme cs,
    required Color cardBg,
    required Color cardBorder,
    required String label,
    required int value,
    required Color color,
    bool enable = true,
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 0.75),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (enable)
                GestureDetector(
                  onTap: onDec,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.remove, size: 16, color: color),
                  ),
                )
              else
                const SizedBox(width: 28),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              if (enable)
                GestureDetector(
                  onTap: onInc,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.add, size: 16, color: color),
                  ),
                )
              else
                const SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsHeader(ColorScheme cs, Color caption) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        title: Text(
          'Attendance Details',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        iconColor: cs.onSurfaceVariant,
        collapsedIconColor: cs.onSurfaceVariant,
        children: [_buildDetailContent(cs)],
      ),
    );
  }

  Widget _buildDetailContent(ColorScheme cs) {
    // We show a placeholder — full detail is in the bottom sheet accessible
    // via the "Details" button in the app bar, or via the course card.
    return GestureDetector(
      onTap: () => showAttendanceBottomSheet(context, widget.attendance),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 0.75),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'View day-wise attendance',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
