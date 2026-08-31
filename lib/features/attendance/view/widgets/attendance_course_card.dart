import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_calculator_page.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_percentage_text.dart';

class AttendanceCourseCard extends StatelessWidget {
  final Attendance attendance;

  const AttendanceCourseCard({
    super.key,
    required this.attendance,
  });

  bool _shouldShowDebarStatus() {
    final debarStatus = attendance.debarStatus.trim();
    return debarStatus.contains('Debarred') ||
        debarStatus.contains('Permitted');
  }

  bool _isOnlyDebarred() {
    final debarStatus = attendance.debarStatus.trim();
    return debarStatus.contains('Debarred') &&
        !debarStatus.contains('Permitted');
  }

  @override
  Widget build(BuildContext context) {
    final isDebarred = _isOnlyDebarred();
    final showDebarStatus = _shouldShowDebarStatus();

    return ListTile(
      tileColor: isDebarred
          ? Colors.red.withValues(alpha: 0.06)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttendancePercentageText(
            attendancePercentage:
                double.tryParse(attendance.attendancePercentage) ?? 0.0,
          ),
          const SizedBox(height: 12),
          Text(
            attendance.courseName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Text(
            attendance.courseCode,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (showDebarStatus) ...[
            const SizedBox(height: 4),
            Text(
              attendance.debarStatus,
              style: TextStyle(
                color: isDebarred ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AttendanceCalculatorPage(attendance: attendance),
          ),
        );
      },
    );
  }
}
