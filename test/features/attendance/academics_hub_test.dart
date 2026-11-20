import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/models/user_preferences.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/academics_hub_page.dart';

class _Prefs extends UserPreferencesNotifier {
  _Prefs(this._prefs);
  final UserPreferences _prefs;

  @override
  UserPreferences build() => _prefs;
}

Future<void> mount(WidgetTester tester, UserPreferences prefs) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [userPreferencesProvider.overrideWith(() => _Prefs(prefs))],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const AcademicsHubPage(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a new install opens on the grid', (tester) async {
    await mount(tester, UserPreferences());

    final attendance = tester.getRect(find.text('Attendance'));
    final marks = tester.getRect(find.text('Marks'));
    expect((attendance.center.dy - marks.center.dy).abs(), lessThan(2));
  });

  testWidgets('the list shows one full-width card per option', (tester) async {
    await mount(tester, UserPreferences(academicsListView: true));

    final attendance = tester.getRect(find.text('Attendance'));
    final marks = tester.getRect(find.text('Marks'));

    expect(
      marks.top,
      greaterThan(attendance.bottom),
      reason: 'stacked one under the other',
    );
    expect(find.text('Biometric Log'), findsOneWidget);
  });

  testWidgets('the grid puts two options on a row, icon above the name', (
    tester,
  ) async {
    await mount(tester, UserPreferences());

    final attendance = tester.getRect(find.text('Attendance'));
    final marks = tester.getRect(find.text('Marks'));
    final exams = tester.getRect(find.text('Exam Schedule'));

    // Attendance and Marks share a row; Exam Schedule starts the next one.
    expect((attendance.center.dy - marks.center.dy).abs(), lessThan(2));
    expect(marks.center.dx, greaterThan(attendance.center.dx));
    expect(exams.top, greaterThan(attendance.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every title is short enough for one line in the grid', (
    tester,
  ) async {
    await mount(tester, UserPreferences());

    // "Digital Assignment Upload" and "Academic Calendar" used to wrap and made
    // their rows taller than the rest.
    expect(find.text('Digital Assignment Upload'), findsNothing);
    expect(find.text('Academic Calendar'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('DA Upload'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DA Upload'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    double heightOf(String title) => tester
        .getRect(
          find
              .ancestor(of: find.text(title), matching: find.byType(AppCard))
              .first,
        )
        .height;

    // Tiles in a row are as tall as the taller of the two.
    expect(heightOf('Course Page'), heightOf('Exam Schedule'));

    // And no title is longer than the longest one that already fit.
    for (final title in [
      'Attendance',
      'Marks',
      'Exam Schedule',
      'Course Page',
      'Calendar',
      'Grades',
      'Biometric Log',
      'DA Upload',
      'Outing',
      'Faculty Info',
      'Open VTOP',
      'More',
      'Skip Planner',
      'GPA Planner',
      'Payments',
      'Capstone',
    ]) {
      expect(title.length, lessThanOrEqualTo(13), reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Course Page is on the hub, always', (tester) async {
    // It has no hide switch, so even with every optional page hidden it stays.
    await mount(
      tester,
      UserPreferences(
        hideGrades: true,
        hideBiometric: true,
        hideDigitalAssignments: true,
        hideOuting: true,
        hideFacultyInfo: true,
        hideOpenVtop: true,
        hideAcademicCalendar: true,
      ),
    );

    expect(find.text('Course Page'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
  });

  testWidgets('the hub is every earlier tile plus More, twelve in all', (
    tester,
  ) async {
    await mount(tester, UserPreferences());
    await tester.scrollUntilVisible(
      find.text('More'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    const tiles = [
      'Attendance', 'Marks', 'Exam Schedule', 'Course Page', 'Calendar',
      'Grades', 'Biometric Log', 'DA Upload', 'Outing', 'Faculty Info',
      'Open VTOP', 'More', //
    ];
    for (final t in tiles) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: t);
    }
    // An even number, so the grid has no half-empty last row.
    expect(tiles.length, 12);
  });

  testWidgets('the planners, payments and capstone are not on the hub itself', (
    tester,
  ) async {
    await mount(tester, UserPreferences());

    for (final t in [
      'Skip Planner',
      'GPA Planner',
      'Payments',
      'Capstone',
      'Improve CGPA',
    ]) {
      expect(find.text(t, skipOffstage: false), findsNothing, reason: t);
    }
  });

  testWidgets('More is always there, even with every optional tile hidden', (
    tester,
  ) async {
    await mount(
      tester,
      UserPreferences(
        hideGrades: true,
        hideBiometric: true,
        hideDigitalAssignments: true,
        hideOuting: true,
        hideFacultyInfo: true,
        hideOpenVtop: true,
        hideAcademicCalendar: true,
      ),
    );

    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('behind More: the skip planner, GPA planner, payments, capstone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWith(() => _Prefs(UserPreferences())),
        ],
        child: MaterialApp(
          theme: getThemeData(isDarkMode: true),
          home: const MorePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('More'), findsOneWidget);
    for (final t in ['Skip Planner', 'GPA Planner', 'Payments', 'Capstone']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // The CGPA improver is inside the GPA planner only, never a tile of its own.
    expect(find.text('Improve CGPA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the biometric log can be hidden', (tester) async {
    await mount(tester, UserPreferences(hideBiometric: true));

    expect(find.text('Biometric Log'), findsNothing);
    expect(find.text('Attendance'), findsOneWidget);
  });

  testWidgets('tiles in a row are the same height even when a title wraps', (
    tester,
  ) async {
    await mount(tester, UserPreferences());

    // "Exam Schedule" and "Course Page" share a row.
    final exam = tester.getRect(
      find
          .ancestor(
            of: find.text('Exam Schedule'),
            matching: find.byType(AppCard),
          )
          .first,
    );
    final course = tester.getRect(
      find
          .ancestor(
            of: find.text('Course Page'),
            matching: find.byType(AppCard),
          )
          .first,
    );

    expect(exam.top, course.top);
    expect(exam.height, course.height);
  });
}
