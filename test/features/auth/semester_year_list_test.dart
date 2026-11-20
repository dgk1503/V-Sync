import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/auth/view/widgets/semester_year_list.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

final semesters = [
  const SemesterInfo(id: 'w26', name: 'Winter Semester 2025-26'),
  const SemesterInfo(id: 'f26', name: 'Fall Semester 2025-26'),
  const SemesterInfo(id: 'w25', name: 'Winter Semester 2024-25'),
  const SemesterInfo(id: 'f25', name: 'Fall Semester 2024-25'),
  const SemesterInfo(id: 'f24', name: 'Fall Semester 2023-24'),
];

Future<void> mount(
  WidgetTester tester, {
  String? selectedId,
  String? currentId,
  ValueChanged<SemesterInfo>? onSelect,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: getThemeData(isDarkMode: true),
      home: Scaffold(
        body: SemesterYearList(
          semesters: semesters,
          selectedId: selectedId,
          currentId: currentId,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a heading per academic year, newest first', (
    tester,
  ) async {
    await mount(tester);

    final newest = tester.getTopLeft(find.text('2025-26')).dy;
    final older = tester.getTopLeft(find.text('2024-25')).dy;
    final oldest = tester.getTopLeft(find.text('2023-24')).dy;
    expect(newest, lessThan(older));
    expect(older, lessThan(oldest));
    expect(find.text('2 semesters'), findsNWidgets(2));
    expect(find.text('1 semester'), findsOneWidget);
  });

  testWidgets('opens the newest year and folds the rest', (tester) async {
    await mount(tester);

    expect(find.text('Winter Semester'), findsOneWidget);
    expect(find.text('Fall Semester'), findsOneWidget);
    // Only the newest year's two rows are showing.
    expect(find.textContaining('Semester'), findsNWidgets(2));
  });

  testWidgets('opens the year that holds the current semester', (tester) async {
    await mount(tester, currentId: 'f25');

    expect(find.text('current'), findsOneWidget);
    // 2024-25 is open, 2025-26 is not.
    expect(find.text('Winter Semester'), findsOneWidget);
    final current = find.ancestor(
      of: find.text('current'),
      matching: find.byType(Row),
    );
    expect(current, findsWidgets);
  });

  testWidgets('a year can be folded and opened again', (tester) async {
    await mount(tester);

    await tester.tap(find.text('2025-26'));
    await tester.pumpAndSettle();
    expect(find.text('Winter Semester'), findsNothing);

    await tester.tap(find.text('2024-25'));
    await tester.pumpAndSettle();
    expect(find.text('Winter Semester'), findsOneWidget);
  });

  testWidgets('tapping a semester reports it', (tester) async {
    SemesterInfo? tapped;
    await mount(tester, onSelect: (s) => tapped = s);

    await tester.tap(find.text('Fall Semester'));
    await tester.pump();

    expect(tapped?.id, 'f26');
  });

  testWidgets('a selected semester shows a check and is never hidden', (
    tester,
  ) async {
    await mount(tester, selectedId: 'f24');

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // 2023-24 holds the selection, so it is the one open.
    expect(find.text('Fall Semester'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
