import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';

import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/home/model/general_outing_report.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/outing_reports_viewmodel.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/attendance_viewmodel.dart';
import 'package:vit_ap_student_app/features/skip_planner/model/skip_planner.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

/// Plans an absence and shows what it costs every class.
///
/// The projection is [SkipPlanner], a pure function; this screen only reads the
/// student's own timetable, attendance and academic calendar and feeds them in.
/// Everything updates as the dates change, because the plan is derived on every
/// build rather than stored.
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
      ref.read(timetableViewModelProvider.notifier).refreshTimetable();
      ref.read(calendarViewmodelProvider.notifier).ensureLoaded();
      ref.read(generalOutingReportsViewModelProvider.notifier)
          .fetchGeneralOutingReports(silentRefresh: true);
      _autofillFromUpcomingOuting();
    });
  }

  /// Offers the next outing still ahead of the student.
  ///
  /// Students apply for leave before they know they will miss a class, so the
  /// outing they have already filed is usually the absence they are trying to
  /// model. Filling it in saves typing dates the app already holds - but it is
  /// an offer, never a silent overwrite: anything already entered stands, and
  /// the student is told what was filled in.
  void _autofillFromUpcomingOuting() {
    final outing = _upcomingOuting;
    if (outing == null) return;
    if (_leaveAt != null || _returnAt != null) return;

    final from = _parseOutingDate(outing.fromDate, outing.fromTime);
    final to = _parseOutingDate(outing.toDate, outing.toTime);
    if (from == null || to == null) return;

    setState(() {
      _leaveAt = from;
      _returnAt = to.isAfter(from) ? to : from.add(const Duration(days: 1));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Autofilled from the outing '
          '${_formatOutingRange(outing.fromDate)} to '
          '${_formatOutingRange(outing.toDate)}.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String _formatOutingRange(String raw) {
    final parsed = _parseDateOnly(raw);
    return parsed == null ? raw : DateFormat('d MMM').format(parsed);
  }

  static DateTime? _parseDateOnly(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// Days with no classes, from the academic calendar, as bare dates.
  ///
  /// Only closures that actually remove a class count. VTOP marks every Sunday
  /// as a holiday with the note "Holiday", and those are filler - excluding
  /// them is pointless on a Sunday and, worse, wrong on any day carrying the
  /// same filler title. Named holidays and no-instructional days are the ones
  /// that cancel real classes.
  Set<DateTime> get _holidays {
    final months = ref.watch(calendarViewmodelProvider).asData?.value;
    if (months == null) return const {};

    final dates = <DateTime>{};
    for (final month in months) {
      for (final chip in month.chips) {
        if (chip.kind != CalendarDayKind.holiday &&
            chip.kind != CalendarDayKind.noClasses) {
          continue;
        }
        if (CalendarEventClassifier.isOrdinarySunday(chip)) continue;
        dates.add(DateTime(chip.date.year, chip.date.month, chip.date.day));
      }
    }
    return dates;
  }

  Future<void> _pickLeave() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _leaveAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      // Midnight, so the whole of the chosen day is away. The time picker is
      // still offered for the case where a half-day is meant - leaving at
      // 12:30 keeps the morning's classes attended - but defaulting to the
      // current time produced overnight windows that contained no classes.
      initialTime: _leaveAt == null
          ? const TimeOfDay(hour: 0, minute: 0)
          : TimeOfDay.fromDateTime(_leaveAt!),
    );
    if (!mounted) return;

    setState(() {
      final picked = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
      _leaveAt = picked;

      // Returning before you leave is never what the user meant. Rather than
      // accept it silently, or refuse the edit, nudge the return forward so
      // the pair is always a real interval.
      if (_returnAt != null && !_returnAt!.isAfter(picked)) {
        _returnAt = picked.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickReturn() async {
    final now = DateTime.now();
    final earliest = _leaveAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: _returnAt != null && _returnAt!.isAfter(earliest)
          ? _returnAt!
          : earliest,
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      // End of the day by the same reasoning: "back on Friday" means the trip
      // runs through it unless a time says otherwise.
      initialTime: _returnAt == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay.fromDateTime(_returnAt!),
    );
    if (!mounted) return;

    setState(() {
      final picked = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
      // Can only ever be equal here, never earlier: the picker's firstDate is
      // the departure. Equal means "back the instant they left", which covers
      // nothing but is a valid answer, so nudge it forward instead.
      _returnAt = picked.isAfter(earliest) ? picked : earliest.add(const Duration(days: 1));
    });
  }

  void _reset() {
    setState(() {
      _leaveAt = null;
      _returnAt = null;
    });
  }

  /// Fills the planner from an outing already filed with the warden.
  void _applyOuting(GeneralOutingReport outing) {
    final from = _parseOutingDate(outing.fromDate, outing.fromTime);
    final to = _parseOutingDate(outing.toDate, outing.toTime);
    if (from == null || to == null) return;

    setState(() {
      _leaveAt = from;
      // Leaving before returning is impossible by construction, and equal
      // endpoints are nudged so the window covers at least one class.
      _returnAt = to.isAfter(from) ? to : from.add(const Duration(days: 1));
    });
  }

  static DateTime? _parseOutingDate(String date, String time) {
    final parts = date.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    // Outing times arrive as `HH:mm`; a missing or malformed one falls back to
    // midnight rather than throwing the whole range away.
    final timeParts = time.trim().split(':');
    final hour = timeParts.length == 2 ? int.tryParse(timeParts[0]) : null;
    final minute = timeParts.length == 2 ? int.tryParse(timeParts[1]) : null;

    return DateTime(year, month, day, hour ?? 0, minute ?? 0);
  }

  List<GeneralOutingReport> get _outings {
    final reports =
        ref.watch(generalOutingReportsViewModelProvider)?.asData?.value ??
        const <GeneralOutingReport>[];
    // Only approved ones: a pending or rejected request is not a plan yet, and
    // offering it would have the user model a trip that may not happen.
    return reports
        .where((outing) => outing.status.trim().toLowerCase() == 'approved')
        .toList(growable: false);
  }

  /// The next approved outing still ahead of today, or null.
  ///
  /// "Ahead" means its end date has not passed, so an outing in progress is
  /// still the one worth offering and a completed one is not. Ties fall back to
  /// the earliest start, so a long trip is offered before a short one later on.
  GeneralOutingReport? get _upcomingOuting {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final candidates = <(GeneralOutingReport, DateTime)>[];
    for (final outing in _outings) {
      final from = _parseOutingDate(outing.fromDate, outing.fromTime);
      if (from == null) continue;
      candidates.add((outing, DateTime(from.year, from.month, from.day)));
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (outing, _) in candidates) {
      final to = _parseOutingDate(outing.toDate, outing.toTime);
      final end = to == null
          ? null
          : DateTime(to.year, to.month, to.day);
      if (end != null && end.isBefore(todayOnly)) continue;
      return outing;
    }
    return null;
  }

  /// The end of a same-day window: the leave moment itself, so "leave and
  /// return on the same date" means the classes that begin at or after it.
  static DateTime _sameDayEdge(DateTime leaveAt) => leaveAt;

  /// The last day of teaching: the start of the next FAT, or the last day the
  /// academic calendar covers when it lists none.
  ///
  /// The terminal projection counts classes up to here, because that is the
  /// number that still has to be above 75% on the last day of class.
  DateTime? _endOfTerm() {
    final months = ref.watch(calendarViewmodelProvider).asData?.value;
    if (months == null || months.isEmpty) return null;

    final fatDate = AttendanceProjection.firstDayWhere(
      months,
      DateTime.now(),
      (kind, text) => kind == CalendarDayKind.exam && text.contains('fat'),
    );
    if (fatDate != null) return fatDate;

    // No FAT listed: fall back to the latest day the calendar covers, which is
    // the best available answer for "the end of term".
    final last = months.last;
    var lastDay = DateTime(last.year, last.month);
    for (final chip in last.chips) {
      if (chip.date.isAfter(lastDay)) lastDay = chip.date;
    }
    return lastDay;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final timetable = ref.watch(timetableViewModelProvider)?.asData?.value;
    final attendanceLoading = ref.watch(attendanceViewModeProvider)?.isLoading == true;
    // Attendance is only ever as fresh as the last refresh, and the
    // projection is arithmetic on top of it.
    final lastSynced = ref.watch(userPreferencesProvider).attendanceLastSync;

    final leaveAt = _leaveAt;
    final returnAt = _returnAt;
    final canProject = leaveAt != null && returnAt != null;
    final now = DateTime.now();

    // "Leave from" is the first day missed; "Back on" is the first day attended
    // again, so the window is [leaveStart 00:00, returnDate 00:00). Normalised
    // here rather than at pick time, so a narrowed time can still be applied
    // to a day-edge window.
    final windowStart = leaveAt == null
        ? null
        : DateTime(leaveAt.year, leaveAt.month, leaveAt.day);
    final windowEnd = returnAt == null
        ? null
        : (leaveAt != null && returnAt.year == leaveAt.year &&
                  returnAt.month == leaveAt.month &&
                  returnAt.day == leaveAt.day
              ? _sameDayEdge(leaveAt)
              : DateTime(returnAt.year, returnAt.month, returnAt.day));

    final plan = canProject
        ? SkipPlanner.compute(
            timetable: timetable,
            attendances: user?.attendance.toList() ?? const [],
            leaveAt: windowStart!,
            returnAt: windowEnd!,
            now: now,
            // The last day of teaching, so the terminal projection knows how
            // many classes are still to come after the student is back.
            until: _endOfTerm(),
            holidays: _holidays,
          )
        : const SkipPlan.empty();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When will you be away?',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "We'll show how each class holds up",
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              _LeaveAndReturnCard(
                leaveAt: leaveAt,
                returnAt: returnAt,
                onPickLeave: _pickLeave,
                onPickReturn: _pickReturn,
              ),
              const SizedBox(height: 12),

              // Outings already filed with the warden are the most common
              // reason to plan a skip, so offer them rather than making the
              // user retype dates the app already has.
              if (_outings.isNotEmpty) ...[
                _OutingPresets(
                  outings: _outings,
                  onPick: _applyOuting,
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
                const SizedBox(height: 20),

                if (plan.isEmpty)
                  const _NoClassesMissed()
                else ...[
                  Text(
                    'If you skip these classes',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final row in plan.byRisk) ...[
                    _SubjectRow(row: row),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Based on your timetable',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

/// Approved outings the student has already filed, offered as one-tap fills.
///
/// The most common reason to plan a skip is a trip that is already booked, so
/// retyping dates the app already holds would be busywork.
class _OutingPresets extends StatelessWidget {
  const _OutingPresets({required this.outings, required this.onPick});

  final List<GeneralOutingReport> outings;
  final ValueChanged<GeneralOutingReport> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From your outings',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final outing in outings)
                InkWell(
                  onTap: () => onPick(outing),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _label(outing),
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12.5,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Place · 3–5 Oct", so a chip is identifiable without opening anything.
  static String _label(GeneralOutingReport outing) {
    final place = outing.placeOfVisit.trim();
    final from = _short(outing.fromDate);
    final to = _short(outing.toDate);
    final range = from == null || to == null
        ? ''
        : from == to
        ? from
        : '$from – $to';

    if (place.isEmpty) return range.isEmpty ? 'Outing' : range;
    return range.isEmpty ? place : '$place · $range';
  }

  static String? _short(String date) {
    final parts = date.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (day == null || month == null) return null;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day ${months[month - 1]}';
  }
}

/// The two date/time fields.
class _LeaveAndReturnCard extends StatelessWidget {
  const _LeaveAndReturnCard({
    required this.leaveAt,
    required this.returnAt,
    required this.onPickLeave,
    required this.onPickReturn,
  });

  final DateTime? leaveAt;
  final DateTime? returnAt;
  final VoidCallback onPickLeave;
  final VoidCallback onPickReturn;

  static String _format(DateTime? value) =>
      value == null ? 'Select' : DateFormat('EEE, d MMM').format(value);

  static String _time(DateTime? value) =>
      value == null ? '--:--' : DateFormat('h:mm a').format(value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _Field(
            label: 'Leaving',
            date: _format(leaveAt),
            time: _time(leaveAt),
            icon: Icons.calendar_today_outlined,
            onTap: onPickLeave,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
          _Field(
            label: 'Back on',
            date: _format(returnAt),
            time: _time(returnAt),
            icon: Icons.calendar_today_outlined,
            onTap: onPickReturn,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.date,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String date;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 13,
                      color: colors.onSurface,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
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
                    '${plan.missedTheory} theory  ·  ${plan.missedLab} lab',
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
                    'Last synced ${DateFormat('d MMM, h:mm a').format(lastSynced!)}',
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
            const SizedBox(width: 16),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ],
          TextButton(
            onPressed: onReset,
            child: const Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One subject's projection.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.row});

  final SkipPlanRow row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);

    final (Color tint, Color? background, String label) = switch (row.status) {
      SkipStatus.safe => (status.success, null, 'Safe'),
      SkipStatus.atEdge => (status.warning, null, 'Right on the edge'),
      SkipStatus.below => (status.danger, status.dangerContainer, 'Drops below 75%'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: background ?? colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: background != null ? tint : colors.outlineVariant,
          width: background != null ? 1.2 : 0.75,
        ),
      ),
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
                      row.courseCode,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Theory and lab spelled out, so a lab student can see that
                    // the two periods a lab costs is what is driving the drop.
                    Row(
                      children: [
                        Text(
                          'misses ${row.missed}',
                          style: TextStyle(
                            fontFamily: 'Instrument Sans',
                            fontSize: 12.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (row.hasBoth || row.hasLab) ...[
                          const SizedBox(width: 6),
                          _KindBadge(label: row.kindLabel),
                        ],

                          // The total is only trustworthy if it can be taken apart, so a
                          // subject spanning several days shows them rather than a bare number.
                          if (row.days.length > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              _dayBreakdown(row.days),
                              style: TextStyle(
                                fontFamily: 'Instrument Sans',
                                fontSize: 11.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    row.hasNoHistory
                        ? '—'
                        : '${row.afterLeave.round()}% now · '
                              '${row.atEndOfTerm.round()}% after FAT',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.hasNoHistory ? 'No records yet' : label,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

    /// "2 ? 3 ? 2" - the periods missed on each day, so the total can be checked.
    static String _dayBreakdown(List<SkipDay> days) {
      final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
      return sorted.map((day) => '${day.periods}').join(' ? ');
}
  }

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 11,
          color: colors.onSurfaceVariant,
        ),
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
            "You'll see every class the absence costs, and whether it still leaves you above 75%.",
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
            'Nothing on your timetable falls in that window.',
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
