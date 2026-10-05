import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

void main() {
  group('countdown colour', () {
    // A countdown is the user's own marker. It was a hardcoded pink literal
    // that ignored the theme, so it neither followed dark mode nor guaranteed
    // separation from the other marks on the grid.

    testWidgets('differs from every status colour in light mode', (tester) async {
      late Color countdown;
      late AppStatusColors status;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: Builder(
            builder: (context) {
              countdown = AppCalendarColors.of(context).countdown;
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

    testWidgets('dark mode resolves its own countdown colour', (tester) async {
      late Color countdown;
      late AppStatusColors status;
      late Brightness brightness;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: true),
          home: Builder(
            builder: (context) {
              countdown = AppCalendarColors.of(context).countdown;
              status = AppStatusColors.of(context);
              brightness = Theme.of(context).colorScheme.brightness;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(brightness, Brightness.dark);
      expect(
        countdown,
        const Color(0xFFB39DFF),
        reason: 'the lighter violet is the one that reads on a dark surface',
      );
      expect(countdown, isNot(status.success));
      expect(countdown, isNot(status.warning));
      expect(countdown, isNot(status.danger));
      expect(countdown, isNot(status.neutral));
    });

    testWidgets('differs from every status colour in dark mode', (tester) async {
      late Color countdown;
      late AppStatusColors status;

      await tester.pumpWidget(
        MaterialApp(
          theme: getThemeData(isDarkMode: true),
          home: Builder(
            builder: (context) {
              countdown = AppCalendarColors.of(context).countdown;
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

  group('a countdown is still marked', () {
    test('so it cannot be mistaken for an unmarked teaching day', () {
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.countdown), isTrue);
    });
  });
}
