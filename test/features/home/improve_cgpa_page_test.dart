import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/models/exam_schedule.dart';
import 'package:vit_ap_student_app/core/models/grade_history.dart';
import 'package:vit_ap_student_app/core/models/mark.dart';
import 'package:vit_ap_student_app/core/models/mentor_details.dart';
import 'package:vit_ap_student_app/core/models/profile.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';
import 'package:vit_ap_student_app/features/home/view/pages/improve_cgpa_page.dart';

class _FakeUser extends CurrentUserNotifier {
  _FakeUser(this._user);
  final User _user;

  @override
  User? build() => _user;
}

Course course(
  String code,
  String grade,
  double credits,
  String month, {
  String title = '',
}) => Course(
  courseCode: code,
  courseTitle: title.isEmpty ? 'Course $code' : title,
  courseType: 'ETL',
  credits: credits.toStringAsFixed(1),
  grade: grade,
  examMonth: month,
  courseDistribution: 'UC',
);

User user(List<Course> courses, {String cgpa = '9.00'}) {
  final history = GradeHistory(
    creditsRegistered: '0',
    creditsEarned: '0',
    cgpa: cgpa,
    courses: ToMany<Course>(items: courses),
  );
  final profile = Profile(
    applicationNumber: '1',
    studentName: 'Test',
    dob: '',
    gender: '',
    bloodGroup: '',
    email: '',
    gradeHistory: ToOne<GradeHistory>(target: history),
    mentorDetails: ToOne<MentorDetails>(),
  );
  return User(
    profile: ToOne<Profile>(target: profile),
    attendance: ToMany<Attendance>(),
    timetable: ToOne<Timetable>(),
    examSchedule: ToMany<ExamSchedule>(),
    marks: ToMany<Mark>(),
  );
}

Future<void> mount(WidgetTester tester, User u) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWith(() => _FakeUser(u))],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const ImproveCgpaPage(),
      ),
    ),
  );
  await tester.pump();
}

/// Opens the grade menu of [code] and chooses [letter].
Future<void> choose(WidgetTester tester, String code, String letter) async {
  final card = find
      .ancestor(of: find.text('Course $code'), matching: find.byType(AppCard))
      .first;
  await tester.tap(
    find.descendant(of: card, matching: find.byTooltip('Change grade')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(PopupMenuItem<PlannerGrade>),
          matching: find.text(letter),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  final twoSemesters = [
    course('A1', 'A', 4, 'Jan-2026'),
    course('A2', 'B', 4, 'Jan-2026'),
    course('B1', 'A', 4, 'Jun-2026'),
  ];

  testWidgets('shows every semester with its GPA, and the CGPA', (
    tester,
  ) async {
    await mount(tester, user(twoSemesters));

    expect(find.text('Jan 2026'), findsOneWidget);
    expect(find.text('Jun 2026'), findsOneWidget);
    expect(find.text('Course A1'), findsOneWidget);
    expect(find.text('Course B1'), findsOneWidget);
    // VTOP's CGPA in both columns until something is tried, and the June
    // semester's own GPA (one A).
    expect(find.text('9.00'), findsNWidgets(3));
    expect(find.text('No changes yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a better grade lifts the semester GPA and the CGPA', (
    tester,
  ) async {
    await mount(tester, user(twoSemesters));

    await choose(tester, 'A2', 'S');

    // Jan 2026: (4*9 + 4*10) / 8 = 9.50, up from 8.50.
    expect(find.textContaining('8.50'), findsOneWidget);
    expect(find.textContaining('9.50'), findsOneWidget);
    // CGPA: B(8) to S(10) is +8 points over 12 credits = +0.67.
    expect(find.text('9.67'), findsOneWidget);
    expect(find.textContaining('+0.67'), findsOneWidget);
    expect(find.text('Was B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lower grade shows the loss', (tester) async {
    await mount(tester, user(twoSemesters));

    await choose(tester, 'B1', 'C');

    // A(9) to C(7) on a 4-credit course: -8 points over 12 credits = -0.67.
    expect(find.text('8.33'), findsOneWidget);
    expect(find.textContaining('−0.67'), findsOneWidget);
  });

  testWidgets('choosing the grade it already has is no change', (tester) async {
    await mount(tester, user(twoSemesters));

    await choose(tester, 'A1', 'A');

    expect(find.text('No changes yet'), findsOneWidget);
  });

  testWidgets('Reset puts every grade back', (tester) async {
    await mount(tester, user(twoSemesters));

    await choose(tester, 'A2', 'S');
    expect(find.text('9.67'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('No changes yet'), findsOneWidget);
    expect(find.text('9.67'), findsNothing);
  });

  testWidgets('a pass/fail course has no menu and says so', (tester) async {
    await mount(
      tester,
      user([
        course('A1', 'A', 4, 'Jan-2026'),
        course('NC1', 'P', 2, 'Jan-2026'),
      ]),
    );

    expect(find.byTooltip('Change grade'), findsOneWidget);
    expect(find.text('Counts for no points'), findsOneWidget);
  });

  testWidgets('no grades yet is said plainly', (tester) async {
    await mount(tester, user(const []));

    expect(find.text('No grades yet'), findsOneWidget);
  });
}
