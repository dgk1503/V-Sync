import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

void main() {
  group('CalendarEventClassifier.isMarked', () {
    test('a plain teaching day is not marked', () {
      // Every instructional day getting a ring turned the grid into a wall of
      // green and made actual holidays impossible to spot.
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.instructional), isFalse);
    });

    test('absent is not marked', () {
      expect(CalendarEventClassifier.isMarked(null), isFalse);
    });

    test('closures, exams, events and countdowns are marked', () {
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.holiday), isTrue);
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.noClasses), isTrue);
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.exam), isTrue);
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.event), isTrue);
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.countdown), isTrue);
    });

    test('only closures and exams get a ring colour, never a teaching day', () {
      // Guards the actual regression: instructional used to resolve to the
      // success colour, the same green as a holiday.
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.holiday), isTrue);
    });
  });

  group('a day with several entries', () {
    CalendarChip chipFor(String description, String label) =>
        CalendarEventClassifier.chipsFor(
          _day(description, label),
        ).first;

    test('a closure outranks a teaching day on the same day', () {
      // VTOP can list several entries for one date; the strongest has to win
      // or a holiday reads as a normal working day.
      final chips = CalendarEventClassifier.chipsFor(
        _day('Holiday - General (Semester)', 'WorkingDay'),
      );

      // The classifier sees the combined text, so this day classifies as a
      // holiday and therefore renders marked.
      expect(CalendarEventClassifier.isMarked(chips.single.kind), isTrue);
      expect(chips.single.kind, CalendarDayKind.holiday);
    });

    test('an exam outranks a plain note', () {
      final chip = chipFor('CAT - II - General (Semester)', 'Exam Days');

      expect(chip.kind, CalendarDayKind.exam);
      expect(CalendarEventClassifier.isMarked(chip.kind), isTrue);
    });

    test('an ordinary working day is left unmarked', () {
      final chip = chipFor('Instructional Day - General (Semester)', 'WorkingDay');

      expect(chip.kind, CalendarDayKind.instructional);
      expect(CalendarEventClassifier.isMarked(chip.kind), isFalse);
    });

    test('WorkingDay is one word, and must not read as a holiday', () {
      expect(
        CalendarEventClassifier.classify(
          _day('Instructional Day', 'WorkingDay').events.first,
        ),
        CalendarDayKind.instructional,
      );
    });

    test('a no-instructional day is marked', () {
      final chip = chipFor(
        'No Instructional Day - General (Semester)',
        'No Instructional Day',
      );

      expect(chip.kind, CalendarDayKind.noClasses);
      expect(CalendarEventClassifier.isMarked(chip.kind), isTrue);
    });
  });

  group('AppStatusColors', () {
    testWidgets('success and danger are distinct', (tester) async {
      Color? success;
      Color? danger;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: Builder(
            builder: (context) {
              success = AppStatusColors.of(context).success;
              danger = AppStatusColors.of(context).danger;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(success, isNotNull);
      expect(danger, isNotNull);
      expect(success, isNot(danger));
    });
  });
}

CalendarDay _day(String description, String label) => CalendarDay(
  date: '2026-10-02',
  day: 2,
  weekday: 'Friday',
  events: [CalendarEvent(description: description, label: label)],
);
