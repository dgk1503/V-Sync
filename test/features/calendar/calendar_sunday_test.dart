import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

/// 2026-10-04 is a Sunday, 2026-10-05 a Monday.
CalendarChip _chip(int day, CalendarDayKind kind, {String title = 'Holiday'}) =>
    CalendarChip(date: DateTime(2026, 10, day), kind: kind, title: title);

void main() {
  group('ordinary Sundays', () {
    // VTOP marks every Sunday as a holiday with the note "Holiday". Ring them
    // all and about a seventh of the grid is green for no reason, which is
    // exactly what makes a real closure invisible.
    test('a bare Sunday holiday is not marked', () {
      final sunday = _chip(4, CalendarDayKind.holiday, title: 'Holiday');
      expect(CalendarEventClassifier.isOrdinarySunday(sunday), isTrue);
      expect(CalendarEventClassifier.ringKindFor([sunday]), isNull);
    });

    test('a named Sunday holiday is still a closure', () {
      // Independence Day falling on a Sunday is a real holiday.
      final sunday = _chip(4, CalendarDayKind.holiday, title: 'Independence Day');
      expect(CalendarEventClassifier.isOrdinarySunday(sunday), isFalse);
      expect(
        CalendarEventClassifier.ringKindFor([sunday]),
        CalendarDayKind.holiday,
      );
    });

    test('the same title on a weekday is still a closure', () {
      final monday = _chip(5, CalendarDayKind.holiday, title: 'Holiday');
      expect(CalendarEventClassifier.isOrdinarySunday(monday), isFalse);
      expect(
        CalendarEventClassifier.ringKindFor([monday]),
        CalendarDayKind.holiday,
      );
    });

    test('title matching ignores case and padding', () {
      for (final title in const ['holiday', 'Holiday', '  HOLIDAY  ']) {
        expect(
          CalendarEventClassifier.isOrdinarySunday(
            _chip(4, CalendarDayKind.holiday, title: title),
          ),
          isTrue,
          reason: '"$title" is VTOP\'s filler, not a holiday name',
        );
      }
    });

    test('a Sunday that is an exam is still marked', () {
      final sunday = _chip(11, CalendarDayKind.exam, title: 'CAT - I');
      expect(CalendarEventClassifier.ringKindFor([sunday]), CalendarDayKind.exam);
    });

    test('a countdown on a Sunday still wins the ring', () {
      final chips = [
        _chip(4, CalendarDayKind.holiday, title: 'Holiday'),
        _chip(4, CalendarDayKind.countdown, title: 'Exam 2'),
      ];
      expect(
        CalendarEventClassifier.ringKindFor(chips),
        CalendarDayKind.countdown,
      );
    });

    test('a Sunday with a real closure alongside keeps the closure', () {
      // The filler must not suppress a genuine holiday on the same day.
      final chips = [
        _chip(4, CalendarDayKind.holiday, title: 'Holiday'),
        _chip(4, CalendarDayKind.noClasses, title: 'No Instructional Day'),
      ];
      expect(CalendarEventClassifier.ringKindFor(chips), CalendarDayKind.noClasses);
    });
  });
}
