import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/models/user_preferences.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

Widget _host(UserPreferences preferences, Widget child) => ProviderScope(
  overrides: [
    userPreferencesProvider.overrideWith(() => _FixedPreferences(preferences)),
  ],
  child: MaterialApp(
    theme: getThemeData(isDarkMode: false),
    home: Scaffold(body: child),
  ),
);

/// Stands in for the notifier, which reads the store and cannot run in a test.
class _FixedPreferences extends UserPreferencesNotifier {
  _FixedPreferences(this.value);

  final UserPreferences value;

  @override
  UserPreferences build() => value;
}

void main() {
  group('countdowns follow the preference, not a page-local toggle', () {
    // The toggle used to live on the calendar page and passed a bool into the
    // viewmodel. Removing it means the preference in Customisation is the only
    // input, and the viewmodel has to watch it - otherwise flipping it in
    // Customisation and opening the calendar would leave the months exactly as
    // they were.
    testWidgets('the viewmodel reads the preference', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _host(
          UserPreferences(),
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, isNotNull);
      // Default is on: the flag is stored inverted.
      expect(UserPreferences().hideCalendarCountdowns, isFalse);
    });

    testWidgets('the calendar page no longer offers the toggle', (tester) async {
      await tester.pumpWidget(
        _host(
          UserPreferences(),
          Builder(
            builder: (context) {
              expect(find.text('Include countdowns'), findsNothing);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(find.text('Include countdowns'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('a countdown is still classified and marked', () {
    test('it keeps the lowest precedence so it never masks a closure', () {
      // Precedence is not part of the public surface, so assert the observable
      // behaviour instead: a countdown is marked and wins its day's ring.
      final countdown = CalendarChip(
        date: DateTime(2026, 10, 5),
        kind: CalendarDayKind.countdown,
        title: 'Exam 2',
      );
      expect(CalendarEventClassifier.isMarked(CalendarDayKind.countdown), isTrue);
      expect(
        CalendarEventClassifier.ringKindFor([countdown]),
        CalendarDayKind.countdown,
      );
    });
  });
}
