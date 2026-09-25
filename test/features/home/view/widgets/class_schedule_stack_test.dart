import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/class_schedule_stack.dart';

void main() {
  final now = DateTime(2026, 9, 25, 10, 0);

  test('orders ongoing class before all remaining classes', () {
    final entries = buildClassScheduleEntries([
      _class('Past', '08:00', '08:50'),
      _class('Upcoming', '10:50', '11:40'),
      _class('Current', '09:30', '10:30'),
    ], now: now);

    expect(entries.map((entry) => entry.classInfo.courseName), [
      'Current',
      'Upcoming',
    ]);
    expect(entries.first.isOngoing, isTrue);
  });

  testWidgets('shows the free-day card when today has no remaining classes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: Scaffold(
          body: ClassScheduleStack(classes: const [], now: now),
        ),
      ),
    );

    expect(find.text('Free for the rest of the day'), findsOneWidget);
  });

  testWidgets('swiping the top card moves it to the back of the stack', (
    tester,
  ) async {
    final stackKey = GlobalKey<ClassScheduleStackState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: Scaffold(
          body: ClassScheduleStack(
            key: stackKey,
            now: now,
            classes: [
              _class('Current', '09:30', '10:30'),
              _class('Upcoming', '10:50', '11:40'),
              _class('Late', '12:05', '12:55'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Room 204'), findsNothing);
    final progressBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progressBar.value, closeTo(0.5, 0.001));
    expect(find.text('ONGOING'), findsOneWidget);
    expect(stackKey.currentState!.currentEntry.classInfo.courseName, 'Current');

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(
      stackKey.currentState!.currentEntry.classInfo.courseName,
      'Upcoming',
    );
    expect(find.text('NEXT · IN 50 MIN'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(stackKey.currentState!.currentEntry.classInfo.courseName, 'Current');
    expect(tester.takeException(), isNull);
  });
}

Day _class(String name, String start, String end) {
  return Day(courseName: name, venue: '204', startTime: start, endTime: end);
}
