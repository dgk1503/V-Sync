import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/model/term_end.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';

CalendarChip chip(
  DateTime date,
  CalendarDayKind kind, {
  String title = 'x',
  String? detail,
}) => CalendarChip(date: date, kind: kind, title: title, detail: detail);

CalendarMonth month(int year, int m, List<CalendarChip> chips) =>
    CalendarMonth(year: year, month: m, chips: chips);

void main() {
  // The real shape of the November calendar: lab FATs in the last teaching
  // week (they are instructional days), then the theory FAT from Monday 16th.
  final november = month(2026, 11, [
    chip(
      DateTime(2026, 11, 5),
      CalendarDayKind.exam,
      title: 'LAB FAT',
      detail: 'Instructional Day - General (Semester)',
    ),
    chip(
      DateTime(2026, 11, 13),
      CalendarDayKind.exam,
      title: 'LAB FAT',
      detail: 'Instructional Day - General (Semester)',
    ),
    chip(
      DateTime(2026, 11, 14),
      CalendarDayKind.exam,
      title: 'LAB FAT',
      detail: 'Instructional Day - General (Semester)',
    ),
    chip(
      DateTime(2026, 11, 16),
      CalendarDayKind.exam,
      title: 'FAT',
      detail: 'FAT - Theory',
    ),
    chip(
      DateTime(2026, 11, 17),
      CalendarDayKind.exam,
      title: 'FAT',
      detail: 'FAT - Theory',
    ),
  ]);
  final now = DateTime(2026, 11, 12, 10);

  test('the FAT starts on the first theory FAT day, not on a Lab FAT day', () {
    final end = TermEnd.of([november], now)!;

    expect(end.date, DateTime(2026, 11, 16));
    expect(end.isFat, isTrue);
  });

  test('Friday 13 and Saturday 14 are still teaching days', () {
    final end = TermEnd.of([november], now)!;

    expect(DateTime(2026, 11, 13).isBefore(end.date), isTrue);
    expect(DateTime(2026, 11, 14).isBefore(end.date), isTrue);
  });

  test('with only lab FATs listed there is no FAT to stop at', () {
    final labOnly = month(2026, 11, [
      chip(DateTime(2026, 11, 13), CalendarDayKind.exam, title: 'LAB FAT'),
    ]);

    final end = TermEnd.of([labOnly], now)!;

    expect(end.isFat, isFalse);
    expect(end.date, DateTime(2026, 11, 13)); // falls back to the last day
  });

  test('the fallback exam day also ignores lab exams', () {
    final months = [
      month(2026, 11, [
        chip(DateTime(2026, 11, 13), CalendarDayKind.exam, title: 'LAB FAT'),
        chip(
          DateTime(2026, 11, 16),
          CalendarDayKind.exam,
          title: 'End Semester Exam',
        ),
      ]),
    ];

    expect(AttendanceProjection.fatStart(months, now), isNull);
    expect(AttendanceProjection.examStart(months, now), DateTime(2026, 11, 16));
  });

  test('a FAT today counts as starting today', () {
    final end = TermEnd.of([november], DateTime(2026, 11, 16, 9))!;
    expect(end.date, DateTime(2026, 11, 16));
  });

  test('no calendar means no end', () {
    expect(TermEnd.of(const [], now), isNull);
  });
}
