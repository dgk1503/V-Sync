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
import 'package:vit_ap_student_app/features/timetable/view/widgets/schedule_list.dart';

class _FakeUser extends CurrentUserNotifier {
  _FakeUser(this._user);
  final User _user;

  @override
  User? build() => _user;
}

Day cls(String name, String start, String end) => Day(
  courseName: name,
  courseCode: name,
  courseType: 'ETH',
  venue: '101-CB',
  startTime: start,
  endTime: end,
);

Future<void> mount(WidgetTester tester, List<Day> friday) async {
  final profile = Profile(
    applicationNumber: '1',
    studentName: 'T',
    dob: '',
    gender: '',
    bloodGroup: '',
    email: '',
    gradeHistory: ToOne<GradeHistory>(),
    mentorDetails: ToOne<MentorDetails>(),
  );
  final user = User(
    profile: ToOne<Profile>(target: profile),
    attendance: ToMany<Attendance>(),
    timetable: ToOne<Timetable>(
      target: Timetable(
        monday: ToMany<Day>(),
        tuesday: ToMany<Day>(),
        wednesday: ToMany<Day>(),
        thursday: ToMany<Day>(),
        friday: ToMany<Day>()..addAll(friday),
        saturday: ToMany<Day>(),
        sunday: ToMany<Day>(),
      ),
    ),
    examSchedule: ToMany<ExamSchedule>(),
    marks: ToMany<Mark>(),
  );

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWith(() => _FakeUser(user))],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const Scaffold(body: ScheduleList(day: 'Friday')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a gap inside a stretch of classes says how long it is', (
    tester,
  ) async {
    await mount(tester, [
      cls('A', '14:00', '14:50'),
      cls('B', '15:00', '15:50'),
      cls('C', '17:00', '17:50'),
    ]);

    // 15:50 -> 17:00 is one hour ten; 14:50 -> 15:00 is just the changeover.
    expect(find.text('Free for 1 hr 10 min'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
  });

  testWidgets('back to back classes show no free time', (tester) async {
    await mount(tester, [
      cls('A', '14:00', '14:50'),
      cls('B', '15:00', '15:50'),
      cls('C', '16:00', '16:50'),
    ]);

    expect(find.textContaining('Free for'), findsNothing);
    expect(find.byIcon(Icons.coffee_outlined), findsNothing);
  });

  testWidgets('lunch between morning and afternoon is not shown as free time', (
    tester,
  ) async {
    await mount(tester, [
      cls('Morning', '11:00', '11:50'),
      cls('Afternoon', '14:00', '14:50'),
    ]);

    expect(find.textContaining('Free for'), findsNothing);
    expect(find.text('MORNING'), findsOneWidget);
    expect(find.text('AFTERNOON'), findsOneWidget);
  });

  testWidgets('nothing is shown after the last class', (tester) async {
    await mount(tester, [cls('A', '14:00', '14:50')]);

    expect(find.textContaining('Free for'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
