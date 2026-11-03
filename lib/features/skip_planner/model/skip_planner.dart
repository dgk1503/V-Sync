import 'package:flutter/foundation.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/utils/parse_class_time.dart';

/// Minimum attendance VIT requires to sit a class.
///
/// Shared with [AttendanceStanding] rather than redeclared, so the two can never
/// disagree about the rule.
const double kSkipPlannerThreshold = 75.0;

/// Where a subject lands once the planned absence is applied.
///
/// Exactly three, deliberately: "safe but tight" and "just above the line" mean
/// the same thing to a student deciding whether to go.
enum SkipStatus {
  /// Above the threshold, and still able to skip at least one more.
  safe,

  /// Above the threshold, but one further skip drops it below.
  atEdge,

  /// Below the threshold.
  below,
}

/// One day's contribution to a subject's missed total.
class SkipDay {
  const SkipDay({required this.date, required this.periods});

  final DateTime date;
  final int periods;
}

/// One subject's projection under a planned absence.
///
/// The three class counts are the whole model:
///
/// ```text
/// A   attendance already recorded by VTOP, final up to `now`
/// T   classes already counted in that total
/// F   classes between now and the leave, assumed attended
/// M   classes starting inside [leave, return), assumed missed
/// R   classes after the return up to the term's FAT, assumed attended
/// ```
class SkipPlanRow {
  const SkipPlanRow({
    required this.courseCode,
    required this.courseName,
    required this.missedTheory,
    required this.missedLab,
    required this.attended,
    required this.total,
    required this.futureBefore,
    required this.remainingAfter,
    this.days = const [],
  });

  final String courseCode;
  final String courseName;

  /// Periods this plan costs, split by kind.
  final int missedTheory;
  final int missedLab;

  final int attended;
  final int total;

  /// Classes between now and the leave, assumed attended.
  final int futureBefore;

  /// Classes after the return, up to the FAT, assumed attended.
  final int remainingAfter;

  /// What each missed day contributes, so the total can be audited.
  ///
  /// A single "14 classes missed" is indistinguishable from a bug, which is
  /// exactly the report this exists to answer.
  final List<SkipDay> days;

  int get missed => missedTheory + missedLab;

  /// Straight after the absence: the classes so far, plus everything between
  /// now and the leave, over the same total plus what is being missed.
  ///
  /// `(A + F) / (T + F + M)`
  double get afterLeave => hasNoHistory
      ? 0
      : total + futureBefore + missed == 0
      ? 0
      : (attended + futureBefore) / (total + futureBefore + missed) * 100;

  /// By the end of the term, assuming every class after the return is attended.
  ///
  /// `(A + F + R) / (T + F + M + R)`
  double get atEndOfTerm => hasNoHistory
      ? 0
      : total + futureBefore + missed + remainingAfter == 0
      ? 0
      : (attended + futureBefore + remainingAfter) /
            (total + futureBefore + missed + remainingAfter) *
            100;

  /// Where this subject ends up. The end-of-term figure is the one the status
  /// rules are written against, because that is the number that has to stay
  /// above the threshold on the last day of teaching.
  double get projected => atEndOfTerm;

  double get current => total == 0 ? 0 : attended / total * 100;

  bool get hasTheory => missedTheory > 0;
  bool get hasLab => missedLab > 0;

  /// Whether this subject carries both kinds of slot.
  bool get hasBoth => hasTheory && hasLab;

  /// A compact label for the kinds this plan costs, e.g. "Theory + Lab".
  String get kindLabel {
    if (hasBoth) return 'Theory + Lab';
    if (hasLab) return 'Lab';
    return 'Theory';
  }

  SkipStatus get status {
    // A course with nothing recorded yet has no standing to lose. Reporting it
    // as "drops below" would flag every subject at the start of the semester.
    if (hasNoHistory) return SkipStatus.safe;

    final projectedPercent = projected;
    if (projectedPercent < kSkipPlannerThreshold) return SkipStatus.below;

    // One more miss after the planned ones.
    final afterOneMore =
        (attended + futureBefore) /
            (total + futureBefore + missed + 1) *
        100;
    if (afterOneMore < kSkipPlannerThreshold) return SkipStatus.atEdge;
    return SkipStatus.safe;
  }

  /// True when the subject has no attendance recorded yet, so the projection
  /// carries no information and the UI should say so.
  bool get hasNoHistory => total == 0;

  /// A copy with the counts replaced, so the status rules can be exercised
  /// against a hand-built projection.
  SkipPlanRow copyWith({
    int? missedTheory,
    int? missedLab,
    int? attended,
    int? total,
    int? futureBefore,
    int? remainingAfter,
    List<SkipDay>? days,
  }) => SkipPlanRow(
    courseCode: courseCode,
    courseName: courseName,
    missedTheory: missedTheory ?? this.missedTheory,
    missedLab: missedLab ?? this.missedLab,
    attended: attended ?? this.attended,
    total: total ?? this.total,
    futureBefore: futureBefore ?? this.futureBefore,
    remainingAfter: remainingAfter ?? this.remainingAfter,
    days: days ?? this.days,
  );
}

/// The whole plan, plus the totals a summary line needs.
class SkipPlan {
  const SkipPlan({required this.rows});

  const SkipPlan.empty() : rows = const [];

  final List<SkipPlanRow> rows;

  bool get isEmpty => rows.isEmpty;

  int get totalMissed => rows.fold(0, (sum, row) => sum + row.missed);

  int get missedTheory => rows.fold(0, (sum, row) => sum + row.missedTheory);

  int get missedLab => rows.fold(0, (sum, row) => sum + row.missedLab);

  /// Subjects in the order they should be seen: worst first. Equal projections
  /// fall back to the number of classes at stake, so the plan that costs the
  /// most comes first among ties.
  List<SkipPlanRow> get byRisk {
    final sorted = [...rows]..sort((a, b) {
      final byProjected = a.projected.compareTo(b.projected);
      if (byProjected != 0) return byProjected;
      return b.missed.compareTo(a.missed);
    });
    return sorted;
  }
}


/// Projects attendance over a planned absence.
///
/// Pure on purpose: it reads only what it is handed, so the whole calculation
/// can be exercised without a store, a repository or a widget.
class SkipPlanner {
  const SkipPlanner._();

  /// Projects [attendances] over the window [leaveAt, returnAt).
  ///
  /// [until] is the end of teaching - the FAT - and is what
  /// [SkipPlanRow.remainingAfter] counts towards. Without one the terminal
  /// projection equals the immediate one, which is honest.
  static SkipPlan compute({
    required Timetable? timetable,
    required List<Attendance> attendances,
    required DateTime leaveAt,
    required DateTime returnAt,
    required DateTime now,
    DateTime? until,
    Set<DateTime> holidays = const <DateTime>{},
  }) {
    if (timetable == null || returnAt.isBefore(leaveAt)) {
      _diagnose(
        timetable: timetable,
        periodMinutes: null,
        daysScanned: 0,
        skippedNoSlots: 0,
        skippedHoliday: 0,
        missed: const {},
        detail: const {},
      );
      return const SkipPlan.empty();
    }

    // Only used when a slot does not name its own periods.
    final periodMinutes = _periodLengthInMinutes(timetable);

    final attendanceByCode = <String, Attendance>{};
    for (final attendance in attendances) {
      final code = attendance.courseCode.trim();
      if (code.isEmpty) continue;
      // A course can appear twice - once theory, once lab. Attendance is
      // reported per course, so the first row wins and the rest are ignored.
      attendanceByCode.putIfAbsent(code, () => attendance);
    }

    final missedTheory = <String, int>{};
    final missedLab = <String, int>{};
    final futureBefore = <String, int>{};
    final remainingAfter = <String, int>{};
    final names = <String, String>{};
    final perDay = <String, Map<DateTime, int>>{};

    var daysScanned = 0;
    var skippedNoSlots = 0;
    var skippedHoliday = 0;

    final today = _dateOnly(now);
    final lastDay = until == null ? _dateOnly(returnAt) : _dateOnly(until);

    for (var day = today;
        !day.isAfter(lastDay);
        day = DateTime(day.year, day.month, day.day + 1)) {
      daysScanned++;

      final slots = _slotsOn(timetable, day);
      if (slots.isEmpty) {
        skippedNoSlots++;
        continue;
      }
      if (holidays.contains(_dateOnly(day))) {
        skippedHoliday++;
        continue;
      }

      for (final slot in slots) {
        final start = _slotStart(day, slot);
        if (start == null) continue;

        // Only classes still to come. Anything already started is inside the
        // attendance VTOP has recorded, and counting it again would double it.
        if (!start.isAfter(now)) continue;

        final code = (slot.courseCode ?? '').trim();
        if (code.isEmpty) continue;
        names[code] = (slot.courseName ?? code).trim();

        final periods = _periodCount(slot, periodMinutes);

        // Missed when it begins inside the absence: on or after the leave, and
        // strictly before the return, which is the first day the student is
        // back and therefore attends.
        final inWindow = !start.isBefore(leaveAt) && start.isBefore(returnAt);

        if (inWindow) {
          if (slot.courseType == 'Lab') {
            missedLab[code] = (missedLab[code] ?? 0) + periods;
          } else {
            missedTheory[code] = (missedTheory[code] ?? 0) + periods;
          }
          perDay.putIfAbsent(code, () => <DateTime, int>{})[_dateOnly(day)] =
              (perDay[code]?[_dateOnly(day)] ?? 0) + periods;
        } else if (start.isBefore(leaveAt)) {
          // Between now and the leave: assumed attended.
          futureBefore[code] = (futureBefore[code] ?? 0) + periods;
        } else {
          // After the return, up to the end of teaching: assumed attended.
          remainingAfter[code] = (remainingAfter[code] ?? 0) + periods;
        }
      }
    }

    final codes = <String>{
      ...missedTheory.keys,
      ...missedLab.keys,
      ...futureBefore.keys,
      ...remainingAfter.keys,
    };

    final rows = <SkipPlanRow>[];
    for (final code in codes) {
      final attendance = attendanceByCode[code];
      final days = perDay[code] ?? const <DateTime, int>{};
      rows.add(
        SkipPlanRow(
          courseCode: code,
          courseName: names[code] ?? attendance?.courseName ?? code,
          missedTheory: missedTheory[code] ?? 0,
          missedLab: missedLab[code] ?? 0,
          attended: int.tryParse(attendance?.attendedClasses.trim() ?? '') ?? 0,
          total: int.tryParse(attendance?.totalClasses.trim() ?? '') ?? 0,
          futureBefore: futureBefore[code] ?? 0,
          remainingAfter: remainingAfter[code] ?? 0,
          days: [
            for (final entry in days.entries)
              SkipDay(date: entry.key, periods: entry.value),
          ],
        ),
      );
    }

    _diagnose(
      timetable: timetable,
      periodMinutes: periodMinutes,
      daysScanned: daysScanned,
      skippedNoSlots: skippedNoSlots,
      skippedHoliday: skippedHoliday,
      missed: {for (final row in rows) row.courseCode: row.missed},
      detail: {
        for (final row in rows)
          row.courseCode:
              'A=${row.attended} T=${row.total} F=${row.futureBefore} '
              'M=${row.missed} R=${row.remainingAfter}',
      },
    );

    return SkipPlan(rows: rows);
  }

  /// How many attendance periods a slot counts for.
  ///
  /// VTOP names them in the slot code: "L31+L32" is two periods, "A1" is one.
  /// That is authoritative and is always used when present - it is the number
  /// VTOP itself counts, and it survives a timing row padded for a break inside
  /// a session.
  ///
  /// The duration is a fallback for a slot whose code names one period but
  /// whose clock span says otherwise. When no period length could be derived
  /// the slot counts as one, which is the ordinary case rather than a failure:
  /// the plan must never come back empty just because the timetable's naming
  /// was not what was expected.
  static int _periodCount(Day slot, int? periodMinutes) {
    final named = _slotsNamed(slot);
    if (named > 1) return named;
    if (periodMinutes == null) return 1;

    final start = parseClassTime(slot.startTime);
    final end = parseClassTime(slot.endTime);
    if (start == null || end == null) return 1;

    final count = (end.difference(start).inMinutes / periodMinutes).round();
    return count < 1 ? 1 : count;
  }

  static int _slotsNamed(Day slot) =>
      RegExp(r'\+').allMatches(slot.slot ?? '').length + 1;

  /// The length of one period, in minutes, or null when the timetable does not
  /// say.
  ///
  /// Read from the **most common** duration among slots that name a single
  /// period. Never from the shortest slot overall: a lab's span is several
  /// periods, so treating it as one would set the period length to a whole
  /// session and make every theory slot count as a fraction of a period.
  ///
  /// Null is a legitimate answer. It only means the duration fallback is
  /// unavailable, and slots that name their periods - every lab - are counted
  /// correctly regardless.
  static int? _periodLengthInMinutes(Timetable timetable) {
    final durations = <int, int>{};
    for (final slot in _allSlots(timetable)) {
      if (_slotsNamed(slot) > 1) continue;

      final start = parseClassTime(slot.startTime);
      final end = parseClassTime(slot.endTime);
      if (start == null || end == null) continue;
      final minutes = end.difference(start).inMinutes;
      if (minutes <= 0) continue;
      durations[minutes] = (durations[minutes] ?? 0) + 1;
    }
    if (durations.isEmpty) return null;

    return durations.entries.reduce((a, b) {
      final byCount = a.value.compareTo(b.value);
      if (byCount != 0) return byCount > 0 ? a : b;
      return a.key < b.key ? a : b;
    }).key;
  }

  /// Everything needed to explain a total, in one line.
  ///
  /// The reported failures were an unexplainable number, so the number now
  /// arrives with its working. Debug only, so a release build pays nothing.
  static void _diagnose({
    required Timetable? timetable,
    required int? periodMinutes,
    required int daysScanned,
    required int skippedNoSlots,
    required int skippedHoliday,
    required Map<String, int> missed,
    required Map<String, String> detail,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[skip-planner] slots=${timetable == null ? 0 : _allSlots(timetable).length} '
      'periodMinutes=$periodMinutes daysScanned=$daysScanned '
      'skippedNoSlots=$skippedNoSlots skippedHoliday=$skippedHoliday '
      'missed=$missed',
    );
    detail.forEach((code, values) => debugPrint('[skip-planner]   $code $values'));
  }

  static List<Day> _allSlots(Timetable timetable) => [
    ..._slotsOn(timetable, DateTime(2026, 1, 5)),
    ..._slotsOn(timetable, DateTime(2026, 1, 6)),
    ..._slotsOn(timetable, DateTime(2026, 1, 7)),
    ..._slotsOn(timetable, DateTime(2026, 1, 8)),
    ..._slotsOn(timetable, DateTime(2026, 1, 9)),
    ..._slotsOn(timetable, DateTime(2026, 1, 10)),
    ..._slotsOn(timetable, DateTime(2026, 1, 11)),
  ];

  static List<Day> _slotsOn(Timetable timetable, DateTime day) =>
      switch (day.weekday) {
        DateTime.monday => timetable.monday.toList(),
        DateTime.tuesday => timetable.tuesday.toList(),
        DateTime.wednesday => timetable.wednesday.toList(),
        DateTime.thursday => timetable.thursday.toList(),
        DateTime.friday => timetable.friday.toList(),
        DateTime.saturday => timetable.saturday.toList(),
        _ => timetable.sunday.toList(),
      };

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _slotStart(DateTime day, Day slot) {
    final time = parseClassTime(slot.startTime);
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }
}
