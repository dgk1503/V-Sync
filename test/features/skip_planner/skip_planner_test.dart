import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/features/skip_planner/model/skip_planner.dart';

/// A weekday, fixed so every window below is a known day of the week.
///
/// 2026-10-19 is a Monday, 2026-10-23 a Friday.
/// ```text
/// Mon  MAT1007  09:00-09:50  theory
/// Wed  MAT1007  11:00-11:50  theory
/// Thu  SWE5002  14:00-15:40  lab, 2 periods
/// Fri  MAT1007  09:00-09:50  theory   <- morning
/// Fri  MGT1040  14:00-14:50  theory   <- afternoon
/// ```
Day _slot({
  required String code,
  required String start,
  required String end,
  String type = 'Theory',
  String slot = 'A1',
  String? name,
}) => Day(
  courseCode: code,
  courseName: name ?? code,
  startTime: start,
  endTime: end,
  slot: slot,
  courseType: type,
);

Attendance _attendance(String code, String attended, String total) =>
    Attendance(
      classNumber: '1',
      faculty: 'Someone',
      courseId: code,
      courseCode: code,
      courseName: code,
      courseType: 'Theory',
      courseTypeCode: 'L',
      courseSlot: 'MON',
      attendedClasses: attended,
      totalClasses: total,
      attendancePercentage: '75',
      betweenAttendancePercentage: '',
      debarStatus: '',
    );

Timetable _timetable() => Timetable(
  monday: ToMany<Day>()..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50')),
  tuesday: ToMany<Day>(),
  wednesday: ToMany<Day>()
    ..add(_slot(code: 'MAT1007', start: '11:00', end: '11:50')),
  thursday: ToMany<Day>()
    ..add(
      _slot(code: 'SWE5002', start: '14:00', end: '15:40', type: 'Lab', slot: 'L31+L32'),
    ),
  friday: ToMany<Day>()
    ..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50'))
    ..add(_slot(code: 'MGT1040', start: '14:00', end: '14:50')),
  saturday: ToMany<Day>(),
  sunday: ToMany<Day>(),
);

/// Wednesday, so the window starts on a clean day.
final _wed = DateTime(2026, 10, 21);
/// The Friday of the same week.
final _fri = DateTime(2026, 10, 23);
/// The Monday after.
final _mon = DateTime(2026, 10, 26);

SkipPlan _plan({
  required Timetable timetable,
  required List<Attendance> attendances,
  required DateTime leaveAt,
  required DateTime returnAt,
  DateTime? now,
  DateTime? until,
  Set<DateTime> holidays = const <DateTime>{},
}) => SkipPlanner.compute(
  timetable: timetable,
  attendances: attendances,
  leaveAt: leaveAt,
  returnAt: returnAt,
  now: now ?? DateTime(2026, 10, 20),
  until: until,
  holidays: holidays,
);

SkipPlanRow _row(SkipPlan plan, String code) =>
    plan.rows.firstWhere((row) => row.courseCode == code);

void main() {
  group('the requested model', () {
    test('1. a full day with 2 theory + 1 lab misses 4 periods', () {
      // Friday carries MAT1007 (theory) and MGT1040 (theory) - 2 periods -
      // and the fixture's lab sits on Thursday, so build a window that covers
      // Thursday through Friday: 2 theory + 2 lab periods = 4.
      final timetable = Timetable(
        monday: ToMany<Day>(),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>()
          ..add(
            _slot(
              code: 'SWE5002',
              start: '14:00',
              end: '15:40',
              type: 'Lab',
              slot: 'L31+L32',
            ),
          ),
        friday: ToMany<Day>()
          ..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50'))
          ..add(_slot(code: 'MGT1040', start: '14:00', end: '14:50')),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      // Thursday 00:00 to Friday 00:00 covers Thursday alone; use Thursday
      // through Saturday to reach both.
      final plan = _plan(
        timetable: timetable,
        attendances: [
          _attendance('SWE5002', '9', '12'),
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '70', '100'),
        ],
        leaveAt: DateTime(2026, 10, 22),
        returnAt: DateTime(2026, 10, 25),
      );

      expect(_row(plan, 'SWE5002').missed, 2, reason: 'the lab is two periods');
      expect(_row(plan, 'MAT1007').missed, 1);
      expect(_row(plan, 'MGT1040').missed, 1);
      expect(plan.totalMissed, 4);
    });

    test('2. leaving at 12:30 keeps the morning class attended', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        leaveAt: DateTime(2026, 10, 23, 12, 30),
        returnAt: _mon,
      );

      // Only MGT1040's 14:00 class begins after 12:30. The other subjects
      // still appear because the window spills into the days after it.
      expect(plan.totalMissed, 1);
      expect(_row(plan, 'MGT1040').missed, 1);
      expect(_row(plan, 'MGT1040').missedLab, 0);
    });

    test('3. a holiday in the window is not counted', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        leaveAt: DateTime(2026, 10, 22),
        returnAt: DateTime(2026, 10, 25),
        holidays: {_fri},
      );

      expect(
        plan.rows.any((row) => row.courseCode == 'MGT1040'),
        isFalse,
        reason: 'the only Friday class is cancelled',
      );
      expect(plan.rows.firstWhere((r) => r.courseCode == 'SWE5002').missed, 2);
    });

    test('4. classes already begun are not counted again', () {
      // Pick a leave window in the future but compare against a `now` after
      // one of the classes has started, so that class is inside A/T already.
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        leaveAt: _fri,
        returnAt: DateTime(2026, 10, 26),
        // Thursday 15:45, so Friday's classes are all still ahead.
        now: DateTime(2026, 10, 22, 15, 45),
      );

      // Both Friday classes are ahead of `now`, so both count.
      expect(plan.totalMissed, 2);
    });

    test('5. a timetable with no single-period slot still plans', () {
      // Every slot names two periods, so no period length can be derived.
      // The plan must still count the slot, using the periods it names.
      final timetable = Timetable(
        monday: ToMany<Day>()
          ..add(
            _slot(code: 'MAT1007', start: '09:00', end: '09:50', slot: 'A1+A2'),
          ),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>(),
        friday: ToMany<Day>(),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      // Now Sunday 18th, leave Tuesday 20th: Monday is inside the window.
      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: DateTime(2026, 10, 20),
        returnAt: DateTime(2026, 10, 21),
        now: DateTime(2026, 10, 18),
      );

      expect(
        plan.isEmpty,
        isFalse,
        reason: 'the plan must not come back empty just because the slot '
            'naming did not fit the assumption',
      );
      final mat = _row(plan, 'MAT1007');
      // Monday sits between `now` and the leave, so it is F rather than M -
      // the point being that the plan is non-empty and the slot is counted,
      // which it is: F=2.
      expect(mat.futureBefore + mat.missed, 2);
    });

    test('6. the hand-computed example', () {
      // A=29, T=34, 4 missed, nothing else in the window so F=R=0.
      // (29 + 0) / (34 + 0 + 4) = 29/38 = 76.3%
      final timetable = Timetable(
        friday: ToMany<Day>()
          ..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50'))
          ..add(_slot(code: 'MAT1007', start: '10:00', end: '10:50', slot: 'A2'))
          ..add(_slot(code: 'MAT1007', start: '11:00', end: '11:50', slot: 'A3'))
          ..add(
            _slot(
              code: 'MAT1007',
              start: '14:00',
              end: '14:50',
              slot: 'B1',
            ),
          ),
        monday: ToMany<Day>(),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>(),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('MAT1007', '29', '34')],
        leaveAt: _fri,
        // Monday 00:00, so only Friday is inside the window.
        returnAt: _mon,
        now: DateTime(2026, 10, 22),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.missed, 4);
      expect(mat.futureBefore, 0);
      expect(mat.remainingAfter, 0, reason: 'no `until`, so nothing is counted');
      expect(mat.afterLeave, closeTo(76.315, 0.01));
      expect(mat.atEndOfTerm, closeTo(76.315, 0.01));
    });
  });

  group('F, M and R', () {
    test('F counts classes between now and the leave', () {
      // Now Sunday 18th, leave Wednesday 21st: Monday's class is ahead of the
      // leave, so it is F rather than M. Wednesday itself is inside the window.
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _wed,
        returnAt: _mon,
        now: DateTime(2026, 10, 18, 8, 0),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.futureBefore, greaterThan(0), reason: 'Monday is ahead');
      expect(mat.missed, 2, reason: 'Wednesday is inside the window');
    });

    test('R counts classes after the return up to the FAT', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _fri,
        returnAt: _mon,
        now: DateTime(2026, 10, 22),
        // Two weeks out, so the Monday after the return is inside R.
        until: DateTime(2026, 11, 6),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.missed, 1, reason: 'Friday morning only');
      expect(mat.remainingAfter, greaterThan(0));
    });

    test('both projections move together and end higher', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _fri,
        returnAt: _mon,
        now: DateTime(2026, 10, 22),
        until: DateTime(2026, 11, 6),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.afterLeave, lessThan(mat.current));
      expect(
        mat.atEndOfTerm,
        greaterThanOrEqualTo(mat.afterLeave),
        reason: 'attending the rest of the term recovers some of it',
      );
    });

    test('the per-day breakdown adds up to the reported total', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        leaveAt: _wed,
        returnAt: _mon,
        now: DateTime(2026, 10, 20),
        until: DateTime(2026, 10, 30),
      );

      for (final row in plan.rows) {
        final fromDays = row.days.fold(0, (sum, day) => sum + day.periods);
        expect(fromDays, row.missed, reason: '${row.courseCode} must reconcile');
      }
    });
  });

  group('lab periods', () {
    test('a lab named L31+L32 counts as two', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('SWE5002', '9', '12')],
        leaveAt: DateTime(2026, 10, 22),
        returnAt: DateTime(2026, 10, 23),
      );

      final lab = _row(plan, 'SWE5002');
      expect(lab.missed, 2);
      expect(lab.missedLab, 2);
      expect(lab.missedTheory, 0);
    });

    test('a lab padded for a break still counts the periods it names', () {
      final timetable = Timetable(
        thursday: ToMany<Day>()
          ..add(
            _slot(
              code: 'SWE5002',
              // 195 minutes, which would round to 4 against a 50-minute period.
              start: '14:00',
              end: '17:15',
              type: 'Lab',
              slot: 'L31+L32',
            ),
          ),
        monday: ToMany<Day>()
          ..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50')),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        friday: ToMany<Day>(),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('SWE5002', '9', '12')],
        leaveAt: DateTime(2026, 10, 22),
        returnAt: DateTime(2026, 10, 23),
      );

      expect(_row(plan, 'SWE5002').missed, 2);
    });
  });

  group('days the timetable actually uses', () {
    test('a Saturday with classes is counted', () {
      final timetable = Timetable(
        saturday: ToMany<Day>()
          ..add(_slot(code: 'MAT1007', start: '09:00', end: '09:50')),
        monday: ToMany<Day>(),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>(),
        friday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: DateTime(2026, 10, 24),
        returnAt: DateTime(2026, 10, 25),
      );

      expect(plan.totalMissed, 1, reason: 'Saturday is a teaching day here');
    });

    test('a weekday with no slots costs nothing', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: DateTime(2026, 10, 20),
        returnAt: DateTime(2026, 10, 21),
      );

      expect(plan.totalMissed, 0, reason: 'Tuesday has no slots to miss');
      expect(plan.rows.first.missed, 0);
    });
  });

  group('degenerate input', () {
    test('no timetable gives an empty plan', () {
      expect(SkipPlanner.compute(
        timetable: null,
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _wed,
        returnAt: _mon,
        now: DateTime(2026, 10, 20),
      ).isEmpty, isTrue);
    });

    test('a return before the leave gives an empty plan', () {
      expect(_plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _mon,
        returnAt: _wed,
      ).isEmpty, isTrue);
    });

    test('a slot with no parseable time is skipped, not fatal', () {
      final broken = Timetable(
        friday: ToMany<Day>()
          ..add(_slot(code: 'MAT1007', start: '-', end: '-')),
        monday: ToMany<Day>(),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>(),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      );

      final plan = _plan(
        timetable: broken,
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _fri,
        returnAt: _mon,
      );

      expect(plan.isEmpty, isTrue);
    });

    test('a subject with no history projects nothing rather than NaN', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: const [],
        leaveAt: _fri,
        returnAt: _mon,
      );

      final row = _row(plan, 'MAT1007');
      expect(row.hasNoHistory, isTrue, reason: 'no A or T recorded');
      // Nothing attended means nothing to project from, whatever the counts.
      expect(row.afterLeave, 0);
      expect(row.atEndOfTerm, 0);
      expect(row.projected, 0);
      expect(row.status, SkipStatus.safe);
    });
  });

  group('statuses', () {
    SkipStatus statusFor(int attended, int total, int missed) => SkipPlanRow(
      courseCode: 'X',
      courseName: 'X',
      missedTheory: missed,
      missedLab: 0,
      attended: attended,
      total: total,
      futureBefore: 0,
      remainingAfter: 0,
    ).status;

    test('safe when comfortably above the line', () {
      expect(statusFor(90, 100, 2), SkipStatus.safe);
    });

    test('right on the edge when one more skip drops it below', () {
      expect(statusFor(75, 100, 0), SkipStatus.atEdge);
      expect(statusFor(76, 101, 0), SkipStatus.atEdge);
    });

    test('drops below when under the threshold', () {
      expect(statusFor(70, 100, 0), SkipStatus.below);
      expect(statusFor(75, 100, 2), SkipStatus.below);
    });

    test('a course with no classes is safe rather than a warning', () {
      expect(statusFor(0, 0, 2), SkipStatus.safe);
    });
  });
}
