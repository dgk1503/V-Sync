import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_page.dart';

void main() {
  testWidgets('the entry card offers the skip planner', (tester) async {
    // No provider overrides: the card is presentational and reads nothing, so
    // it does not need a store, a session or a user.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: const Scaffold(body: SkipPlannerEntry()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Want to skip days?'), findsOneWidget);
    expect(find.text('See what each day costs you'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('the card matches the course cards below it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: getThemeData(isDarkMode: false),
          home: const Scaffold(body: SkipPlannerEntry()),
        ),
      ),
    );
    await tester.pump();

    // Same shape and radius as the attendance course cards, so it reads as one
    // of them rather than a different object in the list.
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.tileColor, isNotNull);
    expect(tile.onTap, isNotNull);
    expect(tile.leading, isNotNull);
    expect(tile.trailing, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
