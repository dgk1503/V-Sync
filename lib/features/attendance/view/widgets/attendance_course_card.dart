import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_standing.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_calculator_page.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_advice_text.dart';
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
    final standing = AttendanceStanding.of(attendance);

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
          // Percentage on the left, guidance on the right of the same row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AttendancePercentageText(
                  attendancePercentage:
                      double.tryParse(attendance.attendancePercentage) ?? 0.0,
                ),
              ),
              Padding(
                // Optically centres the small caption against the large
                // percentage beside it.
                padding: const EdgeInsets.only(top: 10, left: 12),
                child: AttendanceAdviceText(standing: standing),
              ),
            ],
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
                fontWeight: FontWeight.w500,
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
