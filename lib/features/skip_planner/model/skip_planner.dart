import 'package:flutter/foundation.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_standing.dart';
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
  /// Above the threshold, with room to skip at least one more class.
  safe,

  /// At or just above the threshold: one further miss drops it below.
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

/// A day inside the absence that the academic calendar closes.
///
/// Shown to the student so they can see *why* a day they will be away costs
/// nothing: the college is shut, so there is no class to miss.
class SkipClosure {
  const SkipClosure({
    required this.date,
    required this.reason,
    required this.classesSaved,
  });

  final DateTime date;

  /// The calendar's own wording, e.g. "Deepavali" or "No Instructional Day".
  final String reason;

  /// Periods the timetable would have held that day, inside the absence.
  final int classesSaved;
}

/// One subject's projection under a planned absence.
///
/// A theory part and a lab part of the same course are **separate rows**: VTOP
/// reports their attendance separately, and mixing them would measure the lab
/// periods against the theory record.
///
/// The class counts are the whole model:
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
    required this.isLab,
    required this.missed,
    required this.attended,
    required this.total,
    required this.futureBefore,
    required this.remainingAfter,
    this.days = const [],
  });

  final String courseCode;
  final String courseName;

  /// Whether this row is the lab part of the course.
  final bool isLab;

  /// Periods this plan costs.
  final int missed;

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

  int get missedTheory => isLab ? 0 : missed;
  int get missedLab => isLab ? missed : 0;

  /// "Lab" or "Theory".
  String get kindLabel => isLab ? 'Lab' : 'Theory';

  /// True when the subject has no attendance recorded yet, so the projection
  /// carries no information and the UI should say so.
  bool get hasNoHistory => total == 0;

  /// Attended by the end of term: everything so far, plus every class before
  /// the leave and after the return.
  int get _endAttended => attended + futureBefore + remainingAfter;

  /// Held by the end of term, including the classes being missed.
  int get _endTotal => total + futureBefore + missed + remainingAfter;

  double get current => total == 0 ? 0 : attended / total * 100;

  /// Straight after the absence: the classes so far, plus everything between
  /// now and the leave, over the same total plus what is being missed.
  ///
  /// `(A + F) / (T + F + M)`
  double get afterLeave {
    if (hasNoHistory) return 0;
    final held = total + futureBefore + missed;
    return held == 0 ? 0 : (attended + futureBefore) / held * 100;
  }

  /// The three figures above as VTOP would print them: whole numbers, rounded up.
  int get currentPercent => vtopPercent(attended, total);

  int get afterLeavePercent {
    if (hasNoHistory) return 0;
    return vtopPercent(attended + futureBefore, total + futureBefore + missed);
  }

  int get atEndOfTermPercent {
    if (hasNoHistory) return 0;
    return vtopPercent(_endAttended, _endTotal);
  }

  /// By the end of the term, assuming every class after the return is attended.
  ///
  /// `(A + F + R) / (T + F + M + R)`
  double get atEndOfTerm {
    if (hasNoHistory) return 0;
    return _endTotal == 0 ? 0 : _endAttended / _endTotal * 100;
  }

  /// Where this subject ends up. The end-of-term figure is the one the status
  /// rules are written against, because that is the number that has to stay
  /// above the threshold on the last day of teaching.
  double get projected => atEndOfTerm;

  /// How many more of the remaining classes could be skipped on top of this
  /// plan and still finish at or above the threshold.
  ///
  /// Integer arithmetic on purpose, so exactly 75% never flickers between
  /// "safe" and "below" on floating point rounding. Skipping `k` classes that
  /// are already counted as attended keeps the total and lowers the attended:
  ///
  /// ```text
  /// 100 * (a - k) >= 75 * t   ->   k <= (4a - 3t) / 4
  /// ```
  int get _spareUncapped {
    final slack = 4 * _endAttended - 3 * _endTotal;
    return slack < 0 ? -1 : slack ~/ 4;
  }

  /// [_spareUncapped], limited to the classes that actually remain.
  int get canStillSkip {
    if (hasNoHistory) return 0;
    final spare = _spareUncapped;
    if (spare <= 0) return 0;
    final remaining = futureBefore + remainingAfter;
    return spare < remaining ? spare : remaining;
  }

  SkipStatus get status {
    // A course with nothing recorded yet has no standing to lose. Reporting it
    // as "drops below" would flag every subject at the start of the semester.
    if (hasNoHistory) return SkipStatus.safe;

    final spare = _spareUncapped;
    if (spare < 0) return SkipStatus.below;
    if (spare == 0) return SkipStatus.atEdge;
    return SkipStatus.safe;
  }

  /// A copy with the counts replaced, so the status rules can be exercised
  /// against a hand-built projection.
  SkipPlanRow copyWith({
    int? missed,
    int? attended,
    int? total,
    int? futureBefore,
    int? remainingAfter,
    List<SkipDay>? days,
  }) => SkipPlanRow(
    courseCode: courseCode,
    courseName: courseName,
    isLab: isLab,
    missed: missed ?? this.missed,
    attended: attended ?? this.attended,
    total: total ?? this.total,
    futureBefore: futureBefore ?? this.futureBefore,
    remainingAfter: remainingAfter ?? this.remainingAfter,
    days: days ?? this.days,
  );
}

/// The whole plan, plus the totals a summary line needs.
class SkipPlan {
  const SkipPlan({required this.rows, this.closures = const []});

  const SkipPlan.empty() : rows = const [], closures = const [];

  /// Only subjects the absence actually costs a class.
  final List<SkipPlanRow> rows;

  /// Days inside the absence the academic calendar closes, with the classes
  /// each one saves.
  final List<SkipClosure> closures;

  bool get isEmpty => rows.isEmpty;

  int get totalMissed => rows.fold(0, (sum, row) => sum + row.missed);

  int get missedTheory => rows.fold(0, (sum, row) => sum + row.missedTheory);

  int get missedLab => rows.fold(0, (sum, row) => sum + row.missedLab);

  /// Periods the calendar's closures remove from the absence.
  int get classesSaved =>
      closures.fold(0, (sum, closure) => sum + closure.classesSaved);

  /// Subjects in the order they should be seen: worst first. Equal projections
  /// fall back to the number of classes at stake, so the plan that costs the
  /// most comes first among ties.
  List<SkipPlanRow> get byRisk {
    final sorted = [...rows]
      ..sort((a, b) {
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
  /// The window carries real times: a class is missed when it **starts** at or
  /// after [leaveAt] and strictly before [returnAt]. That is what makes a half
  /// day expressible - leave at the start of the third class on a Friday and
  /// the first two are attended, come back for the second class on Wednesday
  /// and the first is missed.
  ///
  /// [closedDays] are the days the academic calendar says have no classes
  /// (holiday, no-instructional day), keyed by date with the calendar's own
  /// wording. No class is held on them, so none is missed, attended or counted
  /// towards the term.
  ///
  /// [until] is the end of teaching - the FAT - and is what
  /// [SkipPlanRow.remainingAfter] counts towards, exclusive: FAT day itself is
  /// an exam, not a class. Without one the terminal projection equals the
  /// immediate one, which is honest.
  static SkipPlan compute({
    required Timetable? timetable,
    required List<Attendance> attendances,
    required DateTime leaveAt,
    required DateTime returnAt,
    required DateTime now,
    DateTime? until,
    Map<DateTime, String> closedDays = const <DateTime, String>{},
  }) {
    if (timetable == null || !returnAt.isAfter(leaveAt)) {
      return const SkipPlan.empty();
    }

    final closed = <DateTime, String>{
      for (final entry in closedDays.entries) _dateOnly(entry.key): entry.value,
    };

    // Only used when a slot does not name its own periods.
    final periodMinutes = _periodLengthInMinutes(timetable);

    final byKind = <String, Attendance>{};
    final byCode = <String, List<Attendance>>{};
    for (final attendance in attendances) {
      final code = attendance.courseCode.trim();
      if (code.isEmpty) continue;
      // A course can appear twice - once theory, once lab - and each carries
      // its own counts. Within one kind the first row wins.
      byKind.putIfAbsent(
        _key(code, isLabAttendance(attendance)),
        () => attendance,
      );
      byCode.putIfAbsent(code, () => <Attendance>[]).add(attendance);
    }

    final missed = <String, int>{};
    final futureBefore = <String, int>{};
    final remainingAfter = <String, int>{};
    final names = <String, String>{};
    final codes = <String, String>{};
    final labs = <String, bool>{};
    final perDay = <String, Map<DateTime, int>>{};
    final closures = <DateTime, _ClosureTally>{};

    final today = _dateOnly(now);
    final lastDayOfWindow = DateTime(
      returnAt.year,
      returnAt.month,
      returnAt.day + 1,
    );
    // Teaching stops when the FAT starts: from then on the timetable's slots
    // are exam days, not classes, so nothing on or after [until] can be missed
    // or attended. Without this, a trip that reached into the FAT period was
    // charged for classes that are never held.
    final endExclusive = until == null ? lastDayOfWindow : _dateOnly(until);

    for (
      var day = today;
      day.isBefore(endExclusive);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final slots = _slotsOn(timetable, day);
      if (slots.isEmpty) continue;

      final closure = closed[day];

      for (final slot in slots) {
        final start = _slotStart(day, slot);
        if (start == null) continue;

        // Only classes still to come. Anything already started is inside the
        // attendance VTOP has recorded, and counting it again would double it.
        if (!start.isAfter(now)) continue;

        final code = (slot.courseCode ?? '').trim();
        if (code.isEmpty) continue;

        final periods = _periodCount(slot, periodMinutes);
        final inWindow = !start.isBefore(leaveAt) && start.isBefore(returnAt);

        // A closed day holds no class at all. Inside the absence that is worth
        // telling the student about; outside it, it simply does not exist.
        if (closure != null) {
          if (inWindow) {
            closures.putIfAbsent(day, () => _ClosureTally(closure)).periods +=
                periods;
          }
          continue;
        }

        final isLab = isLabSlot(slot);
        final key = _key(code, isLab);
        codes[key] = code;
        labs[key] = isLab;
        names[key] = (slot.courseName ?? code).trim();

        if (inWindow) {
          missed[key] = (missed[key] ?? 0) + periods;
          final days = perDay.putIfAbsent(key, () => <DateTime, int>{});
          days[day] = (days[day] ?? 0) + periods;
        } else if (start.isBefore(leaveAt)) {
          // Between now and the leave: assumed attended.
          futureBefore[key] = (futureBefore[key] ?? 0) + periods;
        } else {
          // After the return, up to the end of teaching: assumed attended.
          remainingAfter[key] = (remainingAfter[key] ?? 0) + periods;
        }
      }
    }

    final rows = <SkipPlanRow>[];
    for (final key in missed.keys) {
      final code = codes[key]!;
      final isLab = labs[key]!;
      final attendance = _attendanceFor(byKind, byCode, code, isLab);
      final days = perDay[key] ?? const <DateTime, int>{};
      rows.add(
        SkipPlanRow(
          courseCode: code,
          courseName: _firstNonEmpty(attendance?.courseName, names[key], code),
          isLab: isLab,
          missed: missed[key] ?? 0,
          attended: int.tryParse(attendance?.attendedClasses.trim() ?? '') ?? 0,
          total: int.tryParse(attendance?.totalClasses.trim() ?? '') ?? 0,
          futureBefore: futureBefore[key] ?? 0,
          remainingAfter: remainingAfter[key] ?? 0,
          days: [
            for (final entry in days.entries)
              SkipDay(date: entry.key, periods: entry.value),
          ]..sort((a, b) => a.date.compareTo(b.date)),
        ),
      );
    }

    final closureList = [
      for (final entry in closures.entries)
        SkipClosure(
          date: entry.key,
          reason: entry.value.reason,
          classesSaved: entry.value.periods,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    _diagnose(rows, closureList);
    return SkipPlan(rows: rows, closures: closureList);
  }

  /// Whether a timetable slot is a lab.
  ///
  /// The scraper stores the short course-type code (`ELA` for an embedded lab,
  /// `LO` for lab-only, `ETH`/`TH` for theory) rather than a word, so a plain
  /// `== 'Lab'` never matches real data.
  static bool isLabSlot(Day slot) => _looksLikeLab(slot.courseType);

  /// Whether an attendance row is the lab part of its course.
  static bool isLabAttendance(Attendance attendance) =>
      _looksLikeLab(attendance.courseTypeCode) ||
      _looksLikeLab(attendance.courseType);

  static bool _looksLikeLab(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    return text == 'ela' || text == 'lo' || text.contains('lab');
  }

  static String _key(String code, bool isLab) =>
      '$code|${isLab ? 'lab' : 'th'}';

  /// The attendance row for a course's theory or lab part.
  ///
  /// When the exact kind is missing but the course has only one row, that row is
  /// used: a slot whose type the scraper could not classify should still be
  /// measured against something rather than against nothing.
  static Attendance? _attendanceFor(
    Map<String, Attendance> byKind,
    Map<String, List<Attendance>> byCode,
    String code,
    bool isLab,
  ) {
    final exact = byKind[_key(code, isLab)];
    if (exact != null) return exact;
    final all = byCode[code];
    if (all != null && all.length == 1) return all.first;
    return null;
  }

  static String _firstNonEmpty(String? a, String? b, String fallback) {
    if (a != null && a.trim().isNotEmpty) return a.trim();
    if (b != null && b.trim().isNotEmpty) return b.trim();
    return fallback;
  }

  /// How many attendance periods a slot counts for.
  ///
  /// Labs and theory are read differently, because VTOP names their slots
  /// differently:
  ///
  /// * A **lab** slot is the session itself: "L31+L32" is that day's two
  ///   periods, so the names are authoritative.
  /// * A **theory** slot string lists every slot the course occupies across the
  ///   whole week ("A1+TA1"), not just the one on this day. Counting its `+`
  ///   would charge a single 50 minute class as two or three. Theory is
  ///   therefore measured by its clock span against the period length.
  ///
  /// When no period length could be derived a slot counts as one, the ordinary
  /// case rather than a failure: the plan must never come back empty just
  /// because the timetable's naming was not what was expected.
  static int _periodCount(Day slot, int? periodMinutes) {
    if (isLabSlot(slot)) {
      final named = _slotsNamed(slot);
      if (named > 1) return named;
    }
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
  /// Read from the **most common** duration among theory slots, which are one
  /// period each. Never from the shortest slot overall and never from a lab: a
  /// lab's span is several periods, so treating it as one would set the period
  /// length to a whole session and make every theory slot a fraction of one.
  /// With no theory slot at all, the most common duration of up to an hour is
  /// the best remaining guess.
  ///
  /// Null is a legitimate answer. Labs that name their periods are counted
  /// correctly regardless.
  static int? _periodLengthInMinutes(Timetable timetable) {
    final theory = <int, int>{};
    final any = <int, int>{};
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      for (final slot in _slotsForWeekday(timetable, weekday)) {
        final start = parseClassTime(slot.startTime);
        final end = parseClassTime(slot.endTime);
        if (start == null || end == null) continue;
        final minutes = end.difference(start).inMinutes;
        if (minutes <= 0) continue;
        if (!isLabSlot(slot)) theory[minutes] = (theory[minutes] ?? 0) + 1;
        if (minutes <= 60) any[minutes] = (any[minutes] ?? 0) + 1;
      }
    }
    final durations = theory.isNotEmpty ? theory : any;
    if (durations.isEmpty) return null;

    return durations.entries.reduce((a, b) {
      final byCount = a.value.compareTo(b.value);
      if (byCount != 0) return byCount > 0 ? a : b;
      return a.key < b.key ? a : b;
    }).key;
  }

  /// Everything needed to explain a total, in one line per subject.
  ///
  /// The reported failures were an unexplainable number, so the number now
  /// arrives with its working. Debug only, so a release build pays nothing.
  static void _diagnose(List<SkipPlanRow> rows, List<SkipClosure> closures) {
    if (!kDebugMode) return;
    debugPrint(
      '[skip-planner] rows=${rows.length} '
      'closedInWindow=${closures.map((c) => c.date.toIso8601String().substring(0, 10)).toList()}',
    );
    for (final row in rows) {
      debugPrint(
        '[skip-planner]   ${row.courseCode} ${row.kindLabel} '
        'A=${row.attended} T=${row.total} F=${row.futureBefore} '
        'M=${row.missed} R=${row.remainingAfter}',
      );
    }
  }

  static List<Day> _slotsForWeekday(Timetable timetable, int weekday) =>
      switch (weekday) {
        DateTime.monday => timetable.monday.toList(),
        DateTime.tuesday => timetable.tuesday.toList(),
        DateTime.wednesday => timetable.wednesday.toList(),
        DateTime.thursday => timetable.thursday.toList(),
        DateTime.friday => timetable.friday.toList(),
        DateTime.saturday => timetable.saturday.toList(),
        _ => timetable.sunday.toList(),
      };

  static List<Day> _slotsOn(Timetable timetable, DateTime day) =>
      _slotsForWeekday(timetable, day.weekday);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _slotStart(DateTime day, Day slot) {
    final time = parseClassTime(slot.startTime);
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }
}

/// Running total for one closed day while the window is scanned.
class _ClosureTally {
  _ClosureTally(this.reason);

  final String reason;
  int periods = 0;
}
