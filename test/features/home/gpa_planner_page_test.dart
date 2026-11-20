import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
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
import 'package:vit_ap_student_app/features/home/view/pages/gpa_planner_page.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

class _FakeUser extends CurrentUserNotifier {
  _FakeUser(this._user);
  final User _user;

  @override
  User? build() => _user;
}

class _NoTimetableFetch extends TimetableViewModel {
  @override
  AsyncValue<Timetable>? build() => null;
}

Day slot(String code, String type, String? credits) => Day(
  courseCode: code,
  courseName: 'Course $code',
  courseType: type,
  credits: credits,
);

User user({
  required List<Day> monday,
  String cgpa = '8.00',
  String done = '40',
  List<Map<String, Object?>>? courseTable,
}) {
  final history = GradeHistory(
    creditsRegistered: done,
    creditsEarned: done,
    cgpa: cgpa,
    courses: ToMany<Course>(),
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
  final timetable = Timetable(
    monday: ToMany<Day>()..addAll(monday),
    tuesday: ToMany<Day>(),
    wednesday: ToMany<Day>(),
    thursday: ToMany<Day>(),
    friday: ToMany<Day>(),
    saturday: ToMany<Day>(),
    sunday: ToMany<Day>(),
    courseTable: courseTable == null ? null : jsonEncode(courseTable),
  );
  return User(
    profile: ToOne<Profile>(target: profile),
    attendance: ToMany<Attendance>(),
    timetable: ToOne<Timetable>(target: timetable),
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
      overrides: [
        currentUserProvider.overrideWith(() => _FakeUser(u)),
        timetableViewModelProvider.overrideWith(_NoTimetableFetch.new),
      ],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const GpaPlannerPage(),
      ),
    ),
  );
  await tester.pump();
}

Finder inCourse(String code, Finder what) =>
    find.descendant(of: find.byKey(ValueKey('course-$code')), matching: what);

void main() {
  testWidgets('lists a course that never meets, from the course table', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0')],
        courseTable: [
          {
            'course_code': 'MAT1007',
            'course_name': 'Course MAT1007',
            'course_type': 'Embedded Theory',
            'type_code': 'ETH',
            'credits': '3.0',
          },
          {
            'course_code': 'CSE4099',
            'course_name': 'Capstone Project',
            'course_type': 'Project',
            'type_code': 'PJT',
            'credits': '10.0',
          },
        ],
      ),
    );

    // The capstone has no slot in the weekly grid, yet it is a course to plan.
    expect(find.text('Capstone Project'), findsOneWidget);
    expect(find.text('CSE4099'), findsOneWidget);
    expect(inCourse('CSE4099', find.text('10 credits')), findsOneWidget);
    expect(
      find.textContaining('lists only the courses that meet'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a timetable saved before the table says it may be short', (
    tester,
  ) async {
    await mount(tester, user(monday: [slot('MAT1007', 'ETH', '3.0')]));

    expect(
      find.textContaining('lists only the courses that meet'),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('lists this semester\'s courses with their credits', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [
          slot('MAT1007', 'ETH', '3.0'),
          slot('CSE4007', 'ETH', '3.0'),
          slot('CSE4007', 'ELA', '1.0'),
        ],
      ),
    );

    expect(find.text('From your timetable'), findsOneWidget);
    expect(find.text('Course MAT1007'), findsOneWidget);
    expect(find.text('MAT1007'), findsOneWidget);
    expect(inCourse('MAT1007', find.text('3 credits')), findsOneWidget);
    // Theory 3 + lab 1.
    expect(inCourse('CSE4007', find.text('4 credits')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pencils in the grade the target needs and says it is reached', (
    tester,
  ) async {
    // 8.00 over 40 credits, 7 credits to plan. The default target is 8.2, which
    // needs 9.34 grade points: only an S gets there.
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );

    expect(
      find.textContaining('This plan reaches your target of 8.2'),
      findsOneWidget,
    );
    expect(find.textContaining('roughly an S average'), findsOneWidget);
  });

  testWidgets('changing one grade re-checks the plan against the target', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );
    expect(find.textContaining('reaches your target'), findsOneWidget);

    // An F in the 4-credit course drags the plan well below the target.
    await tester.tap(inCourse('CSE4007', find.text('F')));
    await tester.pump();

    expect(find.textContaining('short of your target'), findsOneWidget);
    expect(find.textContaining('reaches your target'), findsNothing);

    // And "Back to suggested" undoes it.
    await tester.tap(find.text('Back to suggested'));
    await tester.pump();
    expect(find.textContaining('reaches your target'), findsOneWidget);
  });

  testWidgets('a lower target lowers the grade each course needs', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );

    // Walk the target down to 7.5: (7.5*47 - 320)/7 = 4.64 -> an E is enough.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byIcon(Icons.remove_rounded).first);
      await tester.pump();
    }
    await tester.pump();

    expect(find.textContaining('reaches your target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing credits are asked for, not guessed silently', (
    tester,
  ) async {
    await mount(tester, user(monday: [slot('MAT1007', 'ETH', null)]));

    expect(find.textContaining('Some credits are missing'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('MAT1007'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a timetable course\'s credits can be changed', (tester) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );
    expect(inCourse('MAT1007', find.text('3 credits')), findsOneWidget);

    await tester.tap(inCourse('MAT1007', find.byIcon(Icons.add_rounded)));
    await tester.pump();
    expect(inCourse('MAT1007', find.text('4 credits')), findsOneWidget);

    await tester.tap(inCourse('MAT1007', find.byIcon(Icons.remove_rounded)));
    await tester.pump();
    await tester.tap(inCourse('MAT1007', find.byIcon(Icons.remove_rounded)));
    await tester.pump();
    expect(inCourse('MAT1007', find.text('2 credits')), findsOneWidget);
    // The other course is untouched.
    expect(inCourse('CSE4007', find.text('4 credits')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a course with 10 credits can still be stepped', (tester) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0')],
        courseTable: [
          {
            'course_code': 'CSE4099',
            'course_name': 'Capstone Project',
            'course_type': 'Project',
            'type_code': 'PJT',
            'credits': '10.0',
          },
        ],
      ),
    );

    await tester.tap(inCourse('CSE4099', find.byIcon(Icons.add_rounded)));
    await tester.pump();
    expect(inCourse('CSE4099', find.text('11 credits')), findsOneWidget);
  });

  testWidgets('a timetable course can be removed, and restored', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );
    expect(find.text('Course MAT1007'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);

    await tester.tap(inCourse('MAT1007', find.byIcon(Icons.close_rounded)));
    await tester.pump();

    expect(find.text('Course MAT1007'), findsNothing);
    expect(find.text('Course CSE4007'), findsOneWidget);
    expect(find.text('1 course removed'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();

    expect(find.text('Course MAT1007'), findsOneWidget);
    expect(find.text('1 course removed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing every course leaves a page that can restore them', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );

    await tester.tap(inCourse('MAT1007', find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.tap(inCourse('CSE4007', find.byIcon(Icons.close_rounded)));
    await tester.pump();

    expect(find.text('2 courses removed'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    expect(find.text('Course MAT1007'), findsOneWidget);
    expect(find.text('Course CSE4007'), findsOneWidget);
  });

  testWidgets('the grade boxes are one even row, all the same size', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        monday: [slot('MAT1007', 'ETH', '3.0'), slot('CSE4007', 'ETH', '4.0')],
      ),
    );

    for (final code in ['MAT1007', 'CSE4007']) {
      final rects = [
        for (final g in ['S', 'A', 'B', 'C', 'D', 'E', 'F'])
          tester.getRect(
            find.ancestor(
              of: inCourse(code, find.text(g)),
              matching: find.byType(InkWell),
            ),
          ),
      ];
      // One row: every box starts at the same height ...
      expect(rects.map((r) => r.top).toSet().length, 1, reason: code);
      // ... is the same size ...
      expect(rects.map((r) => r.width.round()).toSet().length, 1, reason: code);
      expect(rects.map((r) => r.height.round()).toSet().length, 1);
      // ... and they run left to right without overlapping.
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
    }
    // The two cards line up with each other too.
    final a = tester.getRect(
      find.ancestor(
        of: inCourse('MAT1007', find.text('S')),
        matching: find.byType(InkWell),
      ),
    );
    final b = tester.getRect(
      find.ancestor(
        of: inCourse('CSE4007', find.text('S')),
        matching: find.byType(InkWell),
      ),
    );
    expect(a.width.round(), b.width.round());
    expect(a.left.round(), b.left.round());
  });

  testWidgets('with no timetable it offers to load one or add courses', (
    tester,
  ) async {
    await mount(tester, user(monday: const []));

    expect(find.text('No courses on your timetable'), findsOneWidget);
    expect(find.text('Load timetable'), findsOneWidget);

    await tester.tap(find.text('Add a course'));
    await tester.pump();

    expect(find.text('Courses you add'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
