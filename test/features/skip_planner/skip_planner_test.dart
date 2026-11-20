import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/features/skip_planner/model/skip_planner.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';

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

Attendance _attendance(
  String code,
  String attended,
  String total, {
  String type = 'Theory',
  String typeCode = 'ETH',
}) => Attendance(
  classNumber: '1',
  faculty: 'Someone',
  courseId: code,
  courseCode: code,
  courseName: code,
  courseType: type,
  courseTypeCode: typeCode,
  courseSlot: 'MON',
  attendedClasses: attended,
  totalClasses: total,
  attendancePercentage: '75',
  betweenAttendancePercentage: '',
  debarStatus: '',
);

Timetable _week({
  List<Day> mon = const [],
  List<Day> tue = const [],
  List<Day> wed = const [],
  List<Day> thu = const [],
  List<Day> fri = const [],
  List<Day> sat = const [],
  List<Day> sun = const [],
}) => Timetable(
  monday: ToMany<Day>()..addAll(mon),
  tuesday: ToMany<Day>()..addAll(tue),
  wednesday: ToMany<Day>()..addAll(wed),
  thursday: ToMany<Day>()..addAll(thu),
  friday: ToMany<Day>()..addAll(fri),
  saturday: ToMany<Day>()..addAll(sat),
  sunday: ToMany<Day>()..addAll(sun),
);

Timetable _timetable() => _week(
  mon: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
  wed: [_slot(code: 'MAT1007', start: '11:00', end: '11:50')],
  thu: [
    _slot(
      code: 'SWE5002',
      start: '14:00',
      end: '15:40',
      type: 'Lab',
      slot: 'L31+L32',
    ),
  ],
  fri: [
    _slot(code: 'MAT1007', start: '09:00', end: '09:50'),
    _slot(code: 'MGT1040', start: '14:00', end: '14:50'),
  ],
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
  Map<DateTime, String> closedDays = const <DateTime, String>{},
}) => SkipPlanner.compute(
  timetable: timetable,
  attendances: attendances,
  leaveAt: leaveAt,
  returnAt: returnAt,
  now: now ?? DateTime(2026, 10, 20),
  until: until,
  closedDays: closedDays,
);

SkipPlanRow _row(SkipPlan plan, String code, {bool? lab}) =>
    plan.rows.firstWhere(
      (row) => row.courseCode == code && (lab == null || row.isLab == lab),
    );

void main() {
  group('the trip from the bug report', () {
    // Fri  A 08:00  B 09:00  C 10:00  D 11:00  E 14:00
    // Mon  A 08:00  B 09:00             <- no instructional day
    // Wed  A 08:00  B 09:00  C 10:00
    // Sunday is an ordinary Sunday: no classes.
    Timetable week() => _week(
      mon: [
        _slot(code: 'A', start: '08:00', end: '08:50'),
        _slot(code: 'B', start: '09:00', end: '09:50'),
      ],
      wed: [
        _slot(code: 'A', start: '08:00', end: '08:50'),
        _slot(code: 'B', start: '09:00', end: '09:50'),
        _slot(code: 'C', start: '10:00', end: '10:50'),
      ],
      fri: [
        _slot(code: 'A', start: '08:00', end: '08:50'),
        _slot(code: 'B', start: '09:00', end: '09:50'),
        _slot(code: 'C', start: '10:00', end: '10:50'),
        _slot(code: 'D', start: '11:00', end: '11:50'),
        _slot(code: 'E', start: '14:00', end: '14:50'),
      ],
    );

    final attendances = [
      _attendance('A', '40', '50'),
      _attendance('B', '40', '50'),
      _attendance('C', '40', '50'),
      _attendance('D', '40', '50'),
      _attendance('E', '40', '50'),
    ];

    final friday = DateTime(2026, 10, 23);
    final wednesday = DateTime(2026, 10, 28);
    final monday = DateTime(2026, 10, 26);

    test('attends two Friday classes, skips three, is back for Wednesday', () {
      final plan = _plan(
        timetable: week(),
        attendances: attendances,
        // Skip from the third class on Friday (C, 10:00)...
        leaveAt: DateTime(2026, 10, 23, 10, 0),
        // ...and be back in time for B on Wednesday (09:00), so A is missed.
        returnAt: DateTime(2026, 10, 28, 9, 0),
        now: DateTime(2026, 10, 22, 12),
        closedDays: {monday: 'No Instructional Day'},
      );

      // Friday: C, D, E missed. Wednesday: A missed. B is attended both days.
      expect(_row(plan, 'C').missed, 1);
      expect(_row(plan, 'D').missed, 1);
      expect(_row(plan, 'E').missed, 1);
      expect(_row(plan, 'A').missed, 1);
      expect(plan.rows.any((row) => row.courseCode == 'B'), isFalse);
      expect(plan.totalMissed, 4);

      final a = _row(plan, 'A');
      expect(a.days.single.date, wednesday);
    });

    test('the Monday closure is reported as classes saved, not as misses', () {
      final plan = _plan(
        timetable: week(),
        attendances: attendances,
        leaveAt: DateTime(2026, 10, 23, 10, 0),
        returnAt: DateTime(2026, 10, 28, 9, 0),
        now: DateTime(2026, 10, 22, 12),
        closedDays: {monday: 'No Instructional Day'},
      );

      expect(plan.closures, hasLength(1));
      expect(plan.closures.single.date, monday);
      expect(plan.closures.single.reason, 'No Instructional Day');
      // A and B would both have met on Monday.
      expect(plan.closures.single.classesSaved, 2);
      expect(plan.classesSaved, 2);
    });

    test('without the calendar the same Monday is counted as missed', () {
      final plan = _plan(
        timetable: week(),
        attendances: attendances,
        leaveAt: DateTime(2026, 10, 23, 10, 0),
        returnAt: DateTime(2026, 10, 28, 9, 0),
        now: DateTime(2026, 10, 22, 12),
      );

      // 4 as before, plus Monday's A and B.
      expect(plan.totalMissed, 6);
      expect(plan.closures, isEmpty);
    });

    test('a closed day costs nothing before the leave or after the return', () {
      final plan = _plan(
        timetable: week(),
        attendances: attendances,
        leaveAt: friday,
        returnAt: DateTime(2026, 10, 24),
        now: DateTime(2026, 10, 19, 7),
        until: DateTime(2026, 11, 6),
        // Monday the 26th is after the return, so it would be R.
        closedDays: {monday: 'No Instructional Day'},
      );

      // A meets Mon, Wed and Fri. After the return the open days are Wed 28,
      // Fri 30, Mon Nov 2 and Wed Nov 4 - Monday the 26th is closed, so it
      // does not count, and the FAT day (Nov 6) is an exam, not a class.
      expect(_row(plan, 'A').remainingAfter, 4);
    });
  });

  group('the requested model', () {
    test('1. a full day with 2 theory + 1 lab misses 4 periods', () {
      final timetable = _week(
        thu: [
          _slot(
            code: 'SWE5002',
            start: '14:00',
            end: '15:40',
            type: 'Lab',
            slot: 'L31+L32',
          ),
        ],
        fri: [
          _slot(code: 'MAT1007', start: '09:00', end: '09:50'),
          _slot(code: 'MGT1040', start: '14:00', end: '14:50'),
        ],
      );

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
        closedDays: {_fri: 'Deepavali'},
      );

      expect(
        plan.rows.any((row) => row.courseCode == 'MGT1040'),
        isFalse,
        reason: 'the only Friday class is cancelled',
      );
      expect(_row(plan, 'SWE5002').missed, 2);
      expect(plan.closures.single.reason, 'Deepavali');
      expect(plan.closures.single.classesSaved, 2);
    });

    test('4. classes already begun are not counted again', () {
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

      expect(plan.totalMissed, 2);
    });

    test('5. a theory slot string naming several slots is still one class', () {
      // VTOP lists every slot the course holds in the week ("A1+A2"), not just
      // this day's, so a 50 minute theory class is one period.
      final timetable = _week(
        mon: [
          _slot(code: 'MAT1007', start: '09:00', end: '09:50', slot: 'A1+A2'),
        ],
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: DateTime(2026, 10, 19),
        returnAt: DateTime(2026, 10, 20),
        now: DateTime(2026, 10, 18),
      );

      expect(plan.isEmpty, isFalse);
      expect(_row(plan, 'MAT1007').missed, 1);
    });

    test('5b. a real Friday: two 2-period labs and four theory classes', () {
      // Theory slot strings list the whole week ("C1+TC1+TCC1"); only the labs
      // name their own periods. A whole Friday is 4 lab + 4 theory periods.
      final timetable = _week(
        fri: [
          _slot(
            code: 'SWE2007',
            start: '08:00',
            end: '09:40',
            type: 'ELA',
            slot: 'L1+L2',
          ),
          _slot(
            code: 'SWE2001',
            start: '09:50',
            end: '11:30',
            type: 'ELA',
            slot: 'L3+L4',
          ),
          _slot(
            code: 'SWE2001',
            start: '14:00',
            end: '14:50',
            type: 'ETH',
            slot: 'A1+TA1',
          ),
          _slot(
            code: 'SWE1002',
            start: '15:00',
            end: '15:50',
            type: 'ETH',
            slot: 'C1+TC1+TCC1',
          ),
          _slot(
            code: 'MAT1007',
            start: '16:00',
            end: '16:50',
            type: 'ETH',
            slot: 'D1+TD1',
          ),
          _slot(
            code: 'STS2010',
            start: '17:00',
            end: '17:50',
            type: 'ETH',
            slot: 'E1+TE1+TEE1',
          ),
        ],
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [
          _attendance(
            'SWE2007',
            '5',
            '10',
            type: 'Embedded Lab',
            typeCode: 'ELA',
          ),
          _attendance(
            'SWE2001',
            '5',
            '10',
            type: 'Embedded Lab',
            typeCode: 'ELA',
          ),
          _attendance('SWE2001', '5', '10'),
          _attendance('SWE1002', '5', '10'),
          _attendance('MAT1007', '5', '10'),
          _attendance('STS2010', '5', '10'),
        ],
        leaveAt: DateTime(2026, 10, 23),
        returnAt: DateTime(2026, 10, 24),
        now: DateTime(2026, 10, 22),
      );

      expect(plan.missedLab, 4);
      expect(plan.missedTheory, 4);
      expect(_row(plan, 'SWE1002').missed, 1);
    });

    test('6. the hand-computed example', () {
      // A=29, T=34, 4 missed, nothing else in the window so F=R=0.
      // (29 + 0) / (34 + 0 + 4) = 29/38 = 76.3%
      final timetable = _week(
        fri: [
          _slot(code: 'MAT1007', start: '09:00', end: '09:50'),
          _slot(code: 'MAT1007', start: '10:00', end: '10:50', slot: 'A2'),
          _slot(code: 'MAT1007', start: '11:00', end: '11:50', slot: 'A3'),
          _slot(code: 'MAT1007', start: '14:00', end: '14:50', slot: 'B1'),
        ],
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [_attendance('MAT1007', '29', '34')],
        leaveAt: _fri,
        returnAt: _mon,
        now: DateTime(2026, 10, 22),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.missed, 4);
      expect(mat.futureBefore, 0);
      expect(
        mat.remainingAfter,
        0,
        reason: 'no `until`, so nothing is counted',
      );
      expect(mat.afterLeave, closeTo(76.315, 0.01));
      expect(mat.atEndOfTerm, closeTo(76.315, 0.01));
    });

    test('7. a same-day window misses only the classes inside it', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        leaveAt: DateTime(2026, 10, 23, 14, 0),
        returnAt: DateTime(2026, 10, 23, 23, 59),
      );

      expect(plan.totalMissed, 1);
      expect(_row(plan, 'MGT1040').missed, 1);
    });
  });

  group('F, M and R', () {
    test('F counts classes between now and the leave', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _wed,
        returnAt: _mon,
        now: DateTime(2026, 10, 18, 8, 0),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.futureBefore, greaterThan(0), reason: 'Monday is ahead');
      expect(
        mat.missed,
        2,
        reason: 'Wednesday and Friday are inside the window',
      );
    });

    test('R counts classes after the return up to the FAT', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [_attendance('MAT1007', '80', '100')],
        leaveAt: _fri,
        returnAt: _mon,
        now: DateTime(2026, 10, 22),
        until: DateTime(2026, 11, 6),
      );

      final mat = _row(plan, 'MAT1007');
      expect(mat.missed, 1, reason: 'Friday morning only');
      expect(mat.remainingAfter, greaterThan(0));
    });

    test('the FAT day itself is an exam, not a class', () {
      final timetable = _week(
        wed: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
        fri: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
      );
      final attendances = [_attendance('MAT1007', '80', '100')];

      final examOnFriday = _plan(
        timetable: timetable,
        attendances: attendances,
        leaveAt: _wed,
        returnAt: DateTime(2026, 10, 22),
        now: DateTime(2026, 10, 20),
        until: _fri,
      );
      final examAfterFriday = _plan(
        timetable: timetable,
        attendances: attendances,
        leaveAt: _wed,
        returnAt: DateTime(2026, 10, 22),
        now: DateTime(2026, 10, 20),
        until: DateTime(2026, 10, 24),
      );

      expect(_row(examOnFriday, 'MAT1007').remainingAfter, 0);
      expect(_row(examAfterFriday, 'MAT1007').remainingAfter, 1);
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
        expect(
          fromDays,
          row.missed,
          reason: '${row.courseCode} must reconcile',
        );
      }
    });

    test('only subjects the absence actually costs appear', () {
      final plan = _plan(
        timetable: _timetable(),
        attendances: [
          _attendance('MAT1007', '80', '100'),
          _attendance('MGT1040', '80', '100'),
        ],
        // Only Friday afternoon is missed; MAT1007 meets before and after.
        leaveAt: DateTime(2026, 10, 23, 12),
        returnAt: _mon,
        now: DateTime(2026, 10, 18),
        until: DateTime(2026, 11, 6),
      );

      expect(plan.rows.map((row) => row.courseCode), ['MGT1040']);
    });
  });

  group('theory and lab of one course', () {
    test('each part is measured against its own attendance', () {
      final timetable = _week(
        tue: [
          _slot(code: 'CSE1005', start: '09:00', end: '09:50', type: 'ETH'),
          _slot(
            code: 'CSE1005',
            start: '14:00',
            end: '15:40',
            type: 'ELA',
            slot: 'L1+L2',
          ),
        ],
      );

      final plan = _plan(
        timetable: timetable,
        attendances: [
          _attendance(
            'CSE1005',
            '20',
            '24',
            type: 'Embedded Theory',
            typeCode: 'ETH',
          ),
          _attendance(
            'CSE1005',
            '10',
            '10',
            type: 'Embedded Lab',
            typeCode: 'ELA',
          ),
        ],
        leaveAt: DateTime(2026, 10, 20),
        returnAt: DateTime(2026, 10, 21),
      );

      final theory = _row(plan, 'CSE1005', lab: false);
      final lab = _row(plan, 'CSE1005', lab: true);
      expect(plan.rows, hasLength(2));

      expect(theory.missed, 1);
      expect(theory.attended, 20);
      expect(theory.total, 24);

      expect(lab.missed, 2, reason: 'the lab names two periods');
      expect(lab.attended, 10);
      expect(lab.total, 10);
    });

    test('the scraper course-type codes are recognised as labs', () {
      expect(
        SkipPlanner.isLabSlot(
          _slot(code: 'X', start: '09:00', end: '09:50', type: 'ELA'),
        ),
        isTrue,
      );
      expect(
        SkipPlanner.isLabSlot(
          _slot(code: 'X', start: '09:00', end: '09:50', type: 'LO'),
        ),
        isTrue,
      );
      expect(
        SkipPlanner.isLabSlot(
          _slot(code: 'X', start: '09:00', end: '09:50', type: 'Lab'),
        ),
        isTrue,
      );
      expect(
        SkipPlanner.isLabSlot(
          _slot(code: 'X', start: '09:00', end: '09:50', type: 'ETH'),
        ),
        isFalse,
      );
      expect(
        SkipPlanner.isLabSlot(
          _slot(code: 'X', start: '09:00', end: '09:50', type: 'TH'),
        ),
        isFalse,
      );
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
      final timetable = _week(
        thu: [
          _slot(
            code: 'SWE5002',
            // 195 minutes, which would round to 4 against a 50-minute period.
            start: '14:00',
            end: '17:15',
            type: 'Lab',
            slot: 'L31+L32',
          ),
        ],
        mon: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
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
      final timetable = _week(
        sat: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
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
      expect(plan.isEmpty, isTrue);
    });
  });

  group('the FAT period holds no classes', () {
    // Thu 22 Oct, Fri 23 Oct and Mon 26 Oct each have one MAT1007 slot, and the
    // FAT starts on Fri 23 Oct. From then on the timetable's slots are exams.
    final timetable = _week(
      thu: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
      fri: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
      mon: [_slot(code: 'MAT1007', start: '09:00', end: '09:50')],
    );
    final attendances = [_attendance('MAT1007', '30', '36')];
    final fatStart = DateTime(2026, 10, 23);

    test('a trip that starts inside the FAT misses nothing', () {
      final plan = _plan(
        timetable: timetable,
        attendances: attendances,
        leaveAt: DateTime(2026, 10, 23),
        returnAt: DateTime(2026, 10, 28),
        now: DateTime(2026, 10, 21),
        until: fatStart,
      );

      expect(plan.isEmpty, isTrue);
    });

    test('a trip that runs into the FAT is charged only for real classes', () {
      final plan = _plan(
        timetable: timetable,
        attendances: attendances,
        leaveAt: DateTime(2026, 10, 22),
        returnAt: DateTime(2026, 10, 28),
        now: DateTime(2026, 10, 21),
        until: fatStart,
      );

      // Only Thursday's class is ever held; Friday and Monday are FAT days.
      expect(_row(plan, 'MAT1007').missed, 1);
    });
  });

  group('degenerate input', () {
    test('no timetable gives an empty plan', () {
      expect(
        SkipPlanner.compute(
          timetable: null,
          attendances: [_attendance('MAT1007', '80', '100')],
          leaveAt: _wed,
          returnAt: _mon,
          now: DateTime(2026, 10, 20),
        ).isEmpty,
        isTrue,
      );
    });

    test('a return before the leave gives an empty plan', () {
      expect(
        _plan(
          timetable: _timetable(),
          attendances: [_attendance('MAT1007', '80', '100')],
          leaveAt: _mon,
          returnAt: _wed,
        ).isEmpty,
        isTrue,
      );
    });

    test('a slot with no parseable time is skipped, not fatal', () {
      final broken = _week(
        fri: [_slot(code: 'MAT1007', start: '-', end: '-')],
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
      expect(row.afterLeave, 0);
      expect(row.atEndOfTerm, 0);
      expect(row.projected, 0);
      expect(row.status, SkipStatus.safe);
    });
  });

  group('statuses', () {
    SkipPlanRow rowOf(
      int attended,
      int total,
      int missed, {
      int future = 0,
      int remaining = 0,
    }) => SkipPlanRow(
      courseCode: 'X',
      courseName: 'X',
      isLab: false,
      missed: missed,
      attended: attended,
      total: total,
      futureBefore: future,
      remainingAfter: remaining,
    );

    SkipStatus statusFor(int attended, int total, int missed) =>
        rowOf(attended, total, missed).status;

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

    test('exactly 75% is not below, whatever floating point says', () {
      // 3/4 and 75/100 and 150/200 are all exactly on the line.
      expect(statusFor(3, 4, 0), SkipStatus.atEdge);
      expect(statusFor(150, 200, 0), SkipStatus.atEdge);
    });

    test('the end-of-term position decides the status, not the day after', () {
      // 70/100 would be below today, but 30 more classes all attended lift the
      // term to 100/130 = 76.9%, which is above the line.
      expect(rowOf(70, 100, 0, remaining: 30).status, isNot(SkipStatus.below));
    });

    test('canStillSkip is capped by the classes that remain', () {
      // 90/100, 1 missed, 4 to come: plenty of slack, but only 4 classes left.
      final row = rowOf(90, 100, 1, remaining: 4);
      expect(row.canStillSkip, 4);
    });

    test('canStillSkip is zero on the edge and below it', () {
      expect(rowOf(75, 100, 0).canStillSkip, 0);
      expect(rowOf(60, 100, 5, remaining: 10).canStillSkip, 0);
    });
  });

  group('the academic calendar feeds the planner', () {
    CalendarChip chip(
      DateTime date,
      CalendarDayKind kind,
      String title, [
      String? detail,
    ]) => CalendarChip(date: date, kind: kind, title: title, detail: detail);

    test('only real closures are taken, with their own wording', () {
      final months = [
        CalendarMonth(
          year: 2026,
          month: 10,
          chips: [
            chip(DateTime(2026, 10, 1), CalendarDayKind.exam, 'CAT - II'),
            chip(
              DateTime(2026, 10, 2),
              CalendarDayKind.holiday,
              'Holiday',
              'Mahatma Gandhi Jayanti',
            ),
            // VTOP marks every Sunday "Holiday"; that is filler, not a closure.
            chip(
              DateTime(2026, 10, 4),
              CalendarDayKind.holiday,
              'Holiday',
              'Holiday',
            ),
            chip(
              DateTime(2026, 10, 12),
              CalendarDayKind.noClasses,
              'No Instructional Day',
              'No Instructional Day',
            ),
            chip(
              DateTime(2026, 10, 13),
              CalendarDayKind.instructional,
              'WorkingDay',
            ),
          ],
        ),
      ];

      expect(AttendanceProjection.closedDays(months), {
        DateTime(2026, 10, 2): 'Mahatma Gandhi Jayanti',
        DateTime(2026, 10, 12): 'No Instructional Day',
      });
    });

    test('a no-instructional day outranks a holiday label on the same day', () {
      final months = [
        CalendarMonth(
          year: 2026,
          month: 10,
          chips: [
            chip(
              DateTime(2026, 10, 12),
              CalendarDayKind.holiday,
              'Holiday',
              'Festival',
            ),
            chip(
              DateTime(2026, 10, 12),
              CalendarDayKind.noClasses,
              'No Instructional Day',
              'No Instructional Day',
            ),
          ],
        ),
      ];

      expect(
        AttendanceProjection.closedDays(months)[DateTime(2026, 10, 12)],
        'No Instructional Day',
      );
    });

    test('a vacation is a closure, not an exam', () {
      CalendarDayKind kindOf(String description, String label) =>
          CalendarEventClassifier.classify(
            CalendarEvent(description: description, label: label),
          );

      // "vacation" contains "cat": as a substring match it used to be an exam,
      // which hid it from the planner.
      expect(kindOf('Winter Vacation', 'Vacation'), CalendarDayKind.holiday);
      expect(kindOf('Venue location change', 'Notice'), CalendarDayKind.event);
      expect(kindOf('CAT - II', 'Exam Days'), CalendarDayKind.exam);
      expect(kindOf('Final Assessment Test', 'FAT'), CalendarDayKind.exam);
    });
  });
}
