import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_standing.dart';

/// The one-line guidance that sits to the right of a course's percentage:
/// `Can skip 4`, `Don't skip`, `Attend 3` or `No classes yet`.
///
/// Plain coloured text rather than a pill, so it reads as an annotation on the
/// number beside it instead of competing with the course title.
class AttendanceAdviceText extends StatelessWidget {
  final AttendanceStanding standing;

  const AttendanceAdviceText({
    super.key,
    required this.standing,
  });

  @override
  Widget build(BuildContext context) {
    final status = AppStatusColors.of(context);
    final color = switch (standing.kind) {
      AttendanceAdviceKind.canSkip => status.success,
      AttendanceAdviceKind.atEdge => status.warning,
      AttendanceAdviceKind.mustAttend => status.danger,
      AttendanceAdviceKind.none => status.neutral,
    };

    return Text(
      standing.advice,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Instrument Sans',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}