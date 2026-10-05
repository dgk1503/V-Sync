import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';

CalendarEvent _event(String description, String label) =>
    CalendarEvent(description: description, label: label);

void main() {
  group('CalendarEventClassifier', () {
    test('reads VTOP working days as instructional', () {
      expect(
        CalendarEventClassifier.classify(
          _event('Instructional Day - General (Semester)', 'WorkingDay'),
        ),
        CalendarDayKind.instructional,
      );
    });

    test('reads non-instructional days as no classes', () {
      expect(
        CalendarEventClassifier.classify(
          _event('No instructional day', 'No Instructional Day'),
        ),
        CalendarDayKind.noClasses,
      );
    });

    test('reads holidays', () {
      expect(
        CalendarEventClassifier.classify(_event('Holiday - Deepavali', 'Deepavali')),
        CalendarDayKind.holiday,
      );
      expect(
        CalendarEventClassifier.classify(_event('Holiday', 'Holiday')),
        CalendarDayKind.holiday,
      );
    });

    test('reads exams and lab FATs', () {
      expect(
        CalendarEventClassifier.classify(_event('Lab FAT', 'Lab FAT')),
        CalendarDayKind.exam,
      );
      expect(
        CalendarEventClassifier.classify(_event('Final Assessment Test', 'FAT')),
        CalendarDayKind.exam,
      );
      expect(
        CalendarEventClassifier.classify(_event('CAT-1 Examination', 'Exam')),
        CalendarDayKind.exam,
      );
    });

    test('falls back to event rather than dropping unknown labels', () {
      expect(
        CalendarEventClassifier.classify(_event('Something new', 'Mystery')),
        CalendarDayKind.event,
      );
    });

    test('prefers the label for a short chip, else the head of the description', () {
      expect(
        CalendarEventClassifier.shortLabel(
          _event('Instructional Day - General (Semester)', 'WorkingDay'),
        ),
        'WorkingDay',
      );
      expect(
        CalendarEventClassifier.shortLabel(_event('Holiday - Deepavali', '')),
        'Holiday',
      );
    });

    test('a closure outranks a countdown so a real day is never masked', () {
      int rank(CalendarDayKind kind) => CalendarChip(
            date: DateTime(2026, 11, 3),
            kind: kind,
            title: 'x',
          ).precedence;
      expect(rank(CalendarDayKind.noClasses), greaterThan(rank(CalendarDayKind.countdown)));
      expect(rank(CalendarDayKind.exam), greaterThan(rank(CalendarDayKind.instructional)));
      expect(rank(CalendarDayKind.instructional), greaterThan(rank(CalendarDayKind.countdown)));
    });

    test('builds a chip per event on a day', () {
      final chips = CalendarEventClassifier.chipsFor(
        CalendarDay(
          date: '2026-11-03',
          day: 3,
          weekday: 'Tuesday',
          events: [_event('Lab FAT', 'Lab FAT')],
        ),
      );
      expect(chips, hasLength(1));
      expect(chips.single.kind, CalendarDayKind.exam);
      expect(chips.single.date, DateTime(2026, 11, 3));
    });
  });
}