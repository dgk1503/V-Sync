import 'package:flutter/material.dart';

class AttendancePercentageText extends StatelessWidget {
  final double attendancePercentage;
  final Color? lowAttendanceColor;
  final Color? textColor;
  final FontWeight? textFontWeight;
  final double? fontSize;

  const AttendancePercentageText({
    super.key,
    required this.attendancePercentage,
    this.lowAttendanceColor,
    this.textColor,
    this.textFontWeight,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isLowAttendance =
        attendancePercentage < 75 && attendancePercentage > 0;
    final deficit = isLowAttendance ? (75 - attendancePercentage).ceil() : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${attendancePercentage.toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isLowAttendance
                ? lowAttendanceColor ?? Colors.red
                : textColor ?? Theme.of(context).colorScheme.onSurface,
            fontSize: fontSize ?? 36,
            fontWeight: textFontWeight ?? FontWeight.w500,
          ),
        ),
        if (isLowAttendance) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 6),
            child: Text(
              '-$deficit%',
              style: TextStyle(
                color: lowAttendanceColor ?? Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
