import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/attendance_viewmodel.dart';
import 'package:vit_ap_student_app/features/calendar/model/term_end.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/features/skip_planner/model/skip_planner.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

/// Plans an absence and shows what it costs every class.
///
/// The projection is [SkipPlanner], a pure function; this screen only reads the
/// student's own timetable, attendance and academic calendar and feeds them in.
/// Everything updates as the dates change, because the plan is derived on every
/// build rather than stored.
///
/// The absence is a pair of real moments, a date and a time each, picked with the
/// platform's own date and time pickers. A class is missed when it starts at or
/// after the leaving time and before the return time, so a half day is just a
/// time: leave at 3 PM on Friday, be back at 10 AM on Wednesday.
class SkipPlannerPage extends ConsumerStatefulWidget {
  const SkipPlannerPage({super.key});

  @override
  ConsumerState<SkipPlannerPage> createState() => _SkipPlannerPageState();
}

class _SkipPlannerPageState extends ConsumerState<SkipPlannerPage> {
  DateTime? _leaveAt;
  DateTime? _returnAt;

  @override
  void initState() {
    super.initState();
    // The calendar and the timetable are what the plan is built from. Neither
    // is fetched by this screen's own navigation, so ask for them on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A saved timetable is enough to plan from, and asking VTOP for another
      // one can mean a fresh login and an OTP email for nothing. Only fetch
      // when there is none to show.
      if (ref.read(currentUserProvider)?.timetable.target == null) {
        ref.read(timetableViewModelProvider.notifier).refreshTimetable();
      }
      ref.read(calendarViewmodelProvider.notifier).ensureLoaded();
    });
  }

  // ----------------------------------------------------------------- picking

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _on(DateTime day, int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickLeaveDate() async {
    final today = _dateOnly(DateTime.now());
    final current = _leaveAt == null ? null : _dateOnly(_leaveAt!);

    final date = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today)
          ? current
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    setState(() {
      // A new day keeps the time already chosen; the first time round that is
      // midnight, which means "from the first class of the day".
      _leaveAt = _on(date, _leaveAt?.hour ?? 0, _leaveAt?.minute ?? 0);
      _keepReturnAfterLeave();
    });
  }

  Future<void> _pickLeaveTime() async {
    if (_leaveAt == null) {
      await _pickLeaveDate();
      if (_leaveAt == null || !mounted) return;
    }
    final leave = _leaveAt!;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(leave),
      helpText: 'Leaving at',
    );
    if (time == null || !mounted) return;

    setState(() {
      _leaveAt = _on(leave, time.hour, time.minute);
      _keepReturnAfterLeave();
    });
  }

  Future<void> _pickReturnDate() async {
    if (_leaveAt == null) {
      await _pickLeaveDate();
      if (_leaveAt == null || !mounted) return;
    }
    final first = _dateOnly(_leaveAt!);
    final current = _returnAt == null ? null : _dateOnly(_returnAt!);

    final date = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : first,
      firstDate: first,
      lastDate: _dateOnly(DateTime.now()).add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    setState(() {
      final previous = _returnAt;
      var hour = previous?.hour ?? 0;
      var minute = previous?.minute ?? 0;
      final sameDay = _dateOnly(date) == first;
      final atMidnight = hour == 0 && minute == 0;
      final atEndOfDay = hour == 23 && minute == 59;

      // Back on the day of leaving can only mean "after the classes I skipped",
      // so it starts from the end of that day. Any later day starts from its
      // first class, unless the student has already chosen a time.
      if (sameDay && (previous == null || atMidnight)) {
        hour = 23;
        minute = 59;
      } else if (!sameDay && atEndOfDay) {
        hour = 0;
        minute = 0;
      }
      _returnAt = _on(date, hour, minute);
      _keepReturnAfterLeave();
    });
  }

  Future<void> _pickReturnTime() async {
    if (_returnAt == null) {
      await _pickReturnDate();
      if (_returnAt == null || !mounted) return;
    }
    final back = _returnAt!;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(back),
      helpText: 'Back at',
    );
    if (time == null || !mounted) return;

    final picked = _on(back, time.hour, time.minute);
    if (!picked.isAfter(_leaveAt!)) {
      _say('Pick a time after you leave.');
      return;
    }
    setState(() => _returnAt = picked);
  }

  /// Returning before you leave is never what the user meant. Rather than
  /// accept it silently, or refuse the edit, nudge the return forward so the
  /// pair is always a real interval.
  void _keepReturnAfterLeave() {
    final leave = _leaveAt;
    final back = _returnAt;
    if (leave == null || back == null) return;
    if (!back.isAfter(leave)) {
      _returnAt = DateTime(leave.year, leave.month, leave.day + 1);
    }
  }

  void _reset() {
    setState(() {
      _leaveAt = null;
      _returnAt = null;
    });
  }

  // ---------------------------------------------------------------- calendar

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // The freshly fetched timetable when there is one, else the saved copy.
    final timetable =
        ref.watch(timetableViewModelProvider)?.asData?.value ??
        user?.timetable.target;
    final attendanceLoading =
        ref.watch(attendanceViewModeProvider)?.isLoading == true;
    // Attendance is only ever as fresh as the last refresh, and the
    // projection is arithmetic on top of it.
    final lastSynced = ref.watch(userPreferencesProvider).attendanceLastSync;

    final calendar = ref.watch(calendarViewmodelProvider);
    final months = calendar.asData?.value ?? const <CalendarMonth>[];
    final calendarReady = months.isNotEmpty;
    final closedDays = AttendanceProjection.closedDays(months);
    final endOfTerm = TermEnd.of(months, DateTime.now());

    final leaveAt = _leaveAt;
    final returnAt = _returnAt;
    final canProject = leaveAt != null && returnAt != null;
    final now = DateTime.now();

    final plan = canProject
        ? SkipPlanner.compute(
            timetable: timetable,
            attendances: user?.attendance.toList() ?? const [],
            leaveAt: leaveAt,
            returnAt: returnAt,
            now: now,
            // The last day of teaching, so the terminal projection knows how
            // many classes are still to come after the student is back.
            until: endOfTerm?.date,
            closedDays: closedDays,
          )
        : const SkipPlan.empty();

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Skip planner',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick when you leave and when you are back. A class counts as '
                'missed if it starts between the two times, and the academic '
                'calendar takes out holidays.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              _TripCard(
                leaveAt: leaveAt,
                returnAt: returnAt,
                leaveClosure: leaveAt == null
                    ? null
                    : closedDays[_dateOnly(leaveAt)],
                returnClosure: returnAt == null
                    ? null
                    : closedDays[_dateOnly(returnAt)],
                onPickLeaveDate: _pickLeaveDate,
                onPickLeaveTime: _pickLeaveTime,
                onPickReturnDate: _pickReturnDate,
                onPickReturnTime: _pickReturnTime,
              ),
              const SizedBox(height: 12),

              if (!calendarReady) ...[
                _CalendarNotice(
                  loading: calendar.isLoading,
                  onRetry: () =>
                      ref.read(calendarViewmodelProvider.notifier).refresh(),
                ),
                const SizedBox(height: 12),
              ],

              if (!canProject)
                const _EmptyPrompt()
              else ...[
                _SummaryCard(
                  plan: plan,
                  onReset: _reset,
                  lastSynced: lastSynced,
                  attendanceLoading: attendanceLoading,
                ),
                const SizedBox(height: 12),

                if (plan.closures.isNotEmpty) ...[
                  _ClosuresCard(closures: plan.closures),
                  const SizedBox(height: 12),
                ],

                if (plan.isEmpty)
                  const _NoClassesMissed()
                else ...[
                  const SizedBox(height: 8),
                  Text(
                    'If you skip these classes',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final row in plan.byRisk) ...[
                    _SubjectRow(
                      row: row,
                      endLabel: endOfTerm?.isFat == true
                          ? 'By FAT'
                          : 'End of term',
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Assumes you attend every other class. Based on your '
                      'timetable and the academic calendar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The leave and return moments: a date and a time each.
class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.leaveAt,
    required this.returnAt,
    required this.leaveClosure,
    required this.returnClosure,
    required this.onPickLeaveDate,
    required this.onPickLeaveTime,
    required this.onPickReturnDate,
    required this.onPickReturnTime,
  });

  final DateTime? leaveAt;
  final DateTime? returnAt;
  final String? leaveClosure;
  final String? returnClosure;
  final VoidCallback onPickLeaveDate;
  final VoidCallback onPickLeaveTime;
  final VoidCallback onPickReturnDate;
  final VoidCallback onPickReturnTime;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateField(
            label: 'Leaving',
            value: leaveAt,
            closure: leaveClosure,
            onPickDate: onPickLeaveDate,
            onPickTime: onPickLeaveTime,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          _DateField(
            label: 'Back on',
            value: returnAt,
            closure: returnClosure,
            onPickDate: onPickReturnDate,
            onPickTime: onPickReturnTime,
          ),
        ],
      ),
    );
  }
}

/// One moment: the date, and beside it the time as its own tappable pill, so
/// either can be changed without touching the other.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.closure,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final DateTime? value;
  final String? closure;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final moment = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          moment == null
                              ? 'Select a date'
                              : DateFormat('EEE, d MMM').format(moment),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Instrument Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: moment == null
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onPickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      moment == null
                          ? 'Time'
                          : DateFormat('h:mm a').format(moment),
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: moment == null
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (closure != null) ...[
          const SizedBox(height: 3),
          Text(
            'No classes: $closure',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12,
              color: status.warning,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown while the academic calendar is missing, because without it a holiday
/// in the window would be counted as a class the student misses.
class _CalendarNotice extends StatelessWidget {
  const _CalendarNotice({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else
            Icon(Icons.info_outline_rounded, size: 18, color: status.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'Loading the academic calendar'
                  : 'The academic calendar is not loaded, so holidays are not '
                        'taken out yet and the plan may count too many classes.',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 12.5,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (!loading)
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'Instrument Sans', fontSize: 13.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// "N classes missed" plus the theory/lab split, and Reset.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.plan,
    required this.onReset,
    required this.lastSynced,
    required this.attendanceLoading,
  });

  final SkipPlan plan;
  final VoidCallback onReset;
  final DateTime? lastSynced;
  final bool attendanceLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = plan.totalMissed;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total ${total == 1 ? 'class' : 'classes'} missed',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${plan.missedTheory} theory · ${plan.missedLab} lab',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (lastSynced != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Attendance synced ${DateFormat('d MMM, h:mm a').format(lastSynced!)}',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (attendanceLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            const SizedBox(width: 8),
          ],
          TextButton(
            onPressed: onReset,
            child: const Text(
              'Reset',
              style: TextStyle(fontFamily: 'Instrument Sans', fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Days in the absence the college is closed, and what each one saves.
///
/// This is the academic calendar made visible: the student sees which days were
/// taken out of the count instead of having to trust a smaller number.
class _ClosuresCard extends StatelessWidget {
  const _ClosuresCard({required this.closures});

  final List<SkipClosure> closures;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not counted, no classes',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (final closure in closures)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      DateFormat('EEE, d MMM').format(closure.date),
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      closure.reason,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'saves ${closure.classesSaved}',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One subject's projection.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.row, required this.endLabel});

  final SkipPlanRow row;

  /// "By FAT" when the calendar lists one, else "End of term".
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);

    final (Color tint, String label) = switch (row.status) {
      SkipStatus.safe => (status.success, 'Safe'),
      SkipStatus.atEdge => (status.warning, 'On the edge'),
      SkipStatus.below => (status.danger, 'Drops below 75%'),
    };

    final spare = row.canStillSkip;
    final hint = switch (row.status) {
      SkipStatus.safe => spare > 0 ? 'You could still skip $spare more' : null,
      SkipStatus.atEdge => 'No room for another miss',
      SkipStatus.below => null,
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.courseCode} · ${row.kindLabel}',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (row.hasNoHistory)
                Text(
                  'No records yet',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Misses ${row.missed} ${row.missed == 1 ? 'class' : 'classes'}',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12.5,
              color: colors.onSurface,
            ),
          ),
          // The total is only trustworthy if it can be taken apart, so a
          // subject spanning several days shows them rather than a bare number.
          if (row.days.length > 1) ...[
            const SizedBox(height: 2),
            Text(
              _dayBreakdown(row.days),
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 11.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (!row.hasNoHistory) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Now', value: '${row.currentPercent}%'),
                _Stat(label: 'After trip', value: '${row.afterLeavePercent}%'),
                _Stat(
                  label: endLabel,
                  value: '${row.atEndOfTermPercent}%',
                  color: tint,
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 10),
              Text(
                hint,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// "Fri 23 · 2   Wed 28 · 3": the periods missed on each day, so the
  /// total can be checked against the days.
  static String _dayBreakdown(List<SkipDay> days) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return sorted
        .map((day) => '${DateFormat('EEE d').format(day.date)}: ${day.periods}')
        .join('   ');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 11.5,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: color ?? colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 30,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Pick when you are away',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You'll see every class the absence costs, and whether it still "
            'leaves you above 75%.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoClassesMissed extends StatelessWidget {
  const _NoClassesMissed();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 30,
            color: status.success,
          ),
          const SizedBox(height: 12),
          Text(
            "You won't miss any classes",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing on your timetable is held in that window.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
