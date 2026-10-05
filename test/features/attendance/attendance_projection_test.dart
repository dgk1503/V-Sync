import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:objectbox/objectbox.dart' show ToMany;
import 'package:vit_ap_student_app/core/models/timetable.dart';

Day _class(String code, String slot) => Day(
  startTime: '08:00',
  endTime: '08:50',
  courseName: 'Discrete Mathematics',
  slot: slot,
  courseCode: code,
  courseType: 'Lecture',
);

CalendarChip _chip(DateTime date, CalendarDayKind kind) => CalendarChip(
  date: date,
  kind: kind,
  title: 'x',
);

CalendarMonth _month(int year, int month, List<CalendarChip> chips) =>
    CalendarMonth(year: year, month: month, chips: chips);

void main() {
  // A course that meets twice a week on Monday and Thursday.
  Timetable timetable() => Timetable(
    monday: ToMany<Day>()..add(_class('MAT1007', 'A1')),
    tuesday: ToMany<Day>(),
    wednesday: ToMany<Day>(),
    thursday: ToMany<Day>()..add(_class('MAT1007', 'B1')),
    friday: ToMany<Day>(),
    saturday: ToMany<Day>(),
    sunday: ToMany<Day>(),
  );

  final now = DateTime(2026, 10, 5); // a Monday

  test('counts classes on instructional days only', () {
    final until = DateTime(2026, 10, 19); // three weeks later
    // Without a calendar every weekday is assumed instructional.
    final loose = AttendanceProjection.classesLeftUntil(
      courseCode: 'MAT1007',
      timetable: timetable(),
      months: const [],
      now: now,
      until: until,
    );
    // Oct 5 -> Oct 19 is two weeks: Mon 5, Thu 8, Mon 12, Thu 15 = 4.
    expect(loose, 4);
  });

  test('a holiday in the middle removes its classes', () {
    // Thursday 8 Oct is a holiday.
    final months = [
      _month(2026, 10, [
        _chip(DateTime(2026, 10, 8), CalendarDayKind.holiday),
      ]),
    ];
    final count = AttendanceProjection.classesLeftUntil(
      courseCode: 'MAT1007',
      timetable: timetable(),
      months: months,
      now: now,
      until: DateTime(2026, 10, 19),
    );
    expect(count, 3); // 4 minus the skipped Thursday
  });

  test('a no-instructional day removes its classes too', () {
    final months = [
      _month(2026, 10, [
        _chip(DateTime(2026, 10, 12), CalendarDayKind.noClasses),
      ]),
    ];
    expect(
      AttendanceProjection.classesLeftUntil(
        courseCode: 'MAT1007',
        timetable: timetable(),
        months: months,
        now: now,
        until: DateTime(2026, 10, 19),
      ),
      3, // 12 Oct is a Monday
    );
  });

  test('an exam day still counts as teaching unless marked otherwise', () {
    final months = [
      _month(2026, 10, [
        _chip(DateTime(2026, 10, 8), CalendarDayKind.exam),
      ]),
    ];
    expect(
      AttendanceProjection.classesLeftUntil(
        courseCode: 'MAT1007',
        timetable: timetable(),
        months: months,
        now: now,
        until: DateTime(2026, 10, 19),
      ),
      4,
    );
  });

  test('the target day itself is never counted', () {
    // FAT on Thursday 8 Oct. Only Monday 5 Oct precedes it, so exactly one
    // class is left ? the FAT day's own class is excluded.
    expect(
      AttendanceProjection.classesLeftUntil(
        courseCode: 'MAT1007',
        timetable: timetable(),
        months: const [],
        now: now,
        until: DateTime(2026, 10, 8),
      ),
      1,
    );
  });

  test('an unknown course counts nothing', () {
    expect(
      AttendanceProjection.classesLeftUntil(
        courseCode: 'ZZZ0000',
        timetable: timetable(),
        months: const [],
        now: now,
        until: DateTime(2026, 10, 19),
      ),
      0,
    );
  });

  test('finds the next FAT on the calendar', () {
    final months = [
      _month(2026, 10, [
        _chip(DateTime(2026, 10, 1), CalendarDayKind.exam),
        _chip(DateTime(2026, 10, 22), CalendarDayKind.exam),
      ]),
    ];
    final next = AttendanceProjection.firstDayWhere(
      months,
      now,
      (kind, _) => kind == CalendarDayKind.exam,
    );
    expect(next, DateTime(2026, 10, 22));
  });
}