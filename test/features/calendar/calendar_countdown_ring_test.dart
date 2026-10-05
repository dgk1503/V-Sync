import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

CalendarChip _chip(CalendarDayKind kind, {String title = 'x'}) => CalendarChip(
  date: DateTime(2026, 10, 5),
  kind: kind,
  title: title,
);

void main() {
  group('ringKindFor', () {
    // The bug this pins: the grid handed each cell only the leading chip on a
    // day, and countdowns sort last because their precedence is lowest. Nearly
    // every day in a semester also carries a VTOP entry, so countdowns reached
    // the events list but never got a circle.
    test('a countdown on its own is marked', () {
      expect(
        CalendarEventClassifier.ringKindFor([_chip(CalendarDayKind.countdown)]),
        CalendarDayKind.countdown,
      );
    });

    test('a countdown alongside a working day still wins the ring', () {
      // Sort order as it really arrives: VTOP's entry first, countdown last.
      final chips = [
        _chip(CalendarDayKind.instructional, title: 'WorkingDay'),
        _chip(CalendarDayKind.countdown, title: 'Exam 2'),
      ];

      expect(
        CalendarEventClassifier.ringKindFor(chips),
        CalendarDayKind.countdown,
      );
    });

    test('a countdown outranks a holiday sharing the day', () {
      final chips = [
        _chip(CalendarDayKind.holiday, title: 'Holiday'),
        _chip(CalendarDayKind.countdown, title: 'Exam 2'),
      ];

      expect(
        CalendarEventClassifier.ringKindFor(chips),
        CalendarDayKind.countdown,
      );
    });

    test('a plain teaching day is not marked', () {
      expect(
        CalendarEventClassifier.ringKindFor([
          _chip(CalendarDayKind.instructional, title: 'WorkingDay'),
        ]),
        isNull,
      );
    });

    test('a holiday without a countdown is still marked', () {
      expect(
        CalendarEventClassifier.ringKindFor([_chip(CalendarDayKind.holiday)]),
        CalendarDayKind.holiday,
      );
    });

    test('a closure outranks an exam when there is no countdown', () {
      // precedence order: noClasses > holiday > exam
      final chips = [
        _chip(CalendarDayKind.exam, title: 'CAT - I'),
        _chip(CalendarDayKind.holiday, title: 'Holiday'),
      ];

      expect(
        CalendarEventClassifier.ringKindFor(chips),
        CalendarDayKind.holiday,
      );
    });

    test('an empty day is not marked', () {
      expect(CalendarEventClassifier.ringKindFor(const []), isNull);
    });
  });

  group('the ring colour matches the list', () {
    testWidgets('both read from one place, so they cannot drift', (tester) async {
      late Color fromList;
      late Color fromGrid;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: Builder(
            builder: (context) {
              // This is what the events list uses for its badge.
              fromList = CalendarEventClassifier.colorFor(
                context,
                CalendarDayKind.countdown,
              );
              // And this is what the day cell now uses for its ring.
              fromGrid = CalendarEventClassifier.colorFor(
                context,
                CalendarEventClassifier.ringKindFor([
                  _chip(CalendarDayKind.instructional, title: 'WorkingDay'),
                  _chip(CalendarDayKind.countdown, title: 'Exam 2'),
                ])!,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(fromGrid, fromList);
    });

    testWidgets('the countdown ring is violet, not a status colour', (
      tester,
    ) async {
      late Color countdown;
      late AppStatusColors status;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: Builder(
            builder: (context) {
              countdown = CalendarEventClassifier.colorFor(
                context,
                CalendarDayKind.countdown,
              );
              status = AppStatusColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(countdown, isNot(status.success));
      expect(countdown, isNot(status.warning));
      expect(countdown, isNot(status.danger));
      expect(countdown, isNot(status.neutral));
    });
  });
}
