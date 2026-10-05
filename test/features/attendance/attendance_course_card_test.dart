import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_course_card.dart';

Attendance _record({
  required String attended,
  required String total,
  String percentage = '',
  String code = 'MAT1007',
}) => Attendance(
  classNumber: '1',
  faculty: 'Amrendra Singh Gill',
  courseId: 'id',
  courseCode: code,
  courseName: 'Discrete Mathematics',
  courseType: 'Lecture',
  courseTypeCode: 'L',
  courseSlot: 'MON',
  attendedClasses: attended,
  totalClasses: total,
  attendancePercentage: percentage,
  betweenAttendancePercentage: '',
  debarStatus: '',
);

Future<void> _pumpCard(WidgetTester tester, Attendance record) {
  return tester.pumpWidget(
    MaterialApp(
      theme: getThemeData(isDarkMode: false),
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: AttendanceCourseCard(attendance: record),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('course card shows the guidance beside the percentage', (
    tester,
  ) async {
    await _pumpCard(tester, _record(attended: '25', total: '29', percentage: '86'));

    expect(find.text('Can skip 4'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('Discrete Mathematics'), findsOneWidget);
  });

  testWidgets('below the threshold it tells you to attend', (tester) async {
    await _pumpCard(tester, _record(attended: '12', total: '17', percentage: '71'));

    expect(find.text('Attend 3'), findsOneWidget);
  });

  testWidgets('right on the threshold it says do not skip', (tester) async {
    await _pumpCard(tester, _record(attended: '23', total: '30', percentage: '77'));

    expect(find.text("Don't skip"), findsOneWidget);
  });

  testWidgets('guidance uses the status palette, not a hardcoded colour', (
    tester,
  ) async {
    await _pumpCard(tester, _record(attended: '25', total: '29', percentage: '86'));

    final status = AppStatusColors.light;
    final text = tester.widget<Text>(find.text('Can skip 4'));
    expect(text.style?.color, status.success);
    expect(text.style?.fontFamily, 'Instrument Sans');

    final danger = tester.widget<Text>(
      find.text('Can skip 4'),
    );
    expect(danger.style?.color, isNot(status.danger));
  });

  testWidgets('an empty course reports no classes yet', (tester) async {
    await _pumpCard(tester, _record(attended: '0', total: '0', percentage: '0'));

    expect(find.text('No classes yet'), findsOneWidget);
  });
}