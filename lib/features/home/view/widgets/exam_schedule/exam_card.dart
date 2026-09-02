import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/models/exam_schedule.dart';

enum _ExamStatus { today, upcoming, completed, debarred, unknown }

class ExamCard extends StatelessWidget {
  final Subject exam;
  final VoidCallback? onTap;

  const ExamCard({
    super.key,
    required this.exam,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final status = _statusForExam(exam);
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    // Sub-text greys tuned per mode for readability (brighter in dark).
    final subTextColor = isDark
        ? const Color(0xFFB8C0CC)
        : const Color(0xFF6B7280);

    // Compact formatted date: "17-Aug-2026" -> "17 Aug 2026"
    final formattedDate = exam.date.replaceAll('-', ' ');

    // Combine seat location + number as "R6C3(27)"
    final seatLoc = exam.seatLocation.trim();
    final seatNo = exam.seatNumber.trim();
    final seatCombined = seatLoc.isEmpty && seatNo.isEmpty
        ? '—'
        : seatNo.isEmpty
            ? seatLoc
            : seatLoc.isEmpty
                ? seatNo
                : '$seatLoc($seatNo)';

    final venueText =
        exam.venue.trim().isEmpty ? '—' : exam.venue.trim();
    final timeText =
        exam.examTime.trim().isEmpty ? '—' : exam.examTime.trim();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.75,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: date • status
                Row(
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: subTextColor,
                      ),
                    ),
                    const Spacer(),
                    _StatusDot(label: statusLabel, color: statusColor),
                  ],
                ),

                const SizedBox(height: 10),

                // Course title
                Text(
                  exam.courseTitle,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 3),

                // Course code
                Text(
                  exam.courseCode,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: subTextColor,
                  ),
                ),

                const SizedBox(height: 12),

                // Divider
                Container(
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),

                const SizedBox(height: 12),

                // Bottom stats — labels removed so time can stretch.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 24,
                      child: _StatCell(value: timeText),
                    ),
                    _VerticalDivider(color: colorScheme.outlineVariant),
                    Expanded(
                      flex: 10,
                      child: _StatCell(value: venueText),
                    ),
                    _VerticalDivider(color: colorScheme.outlineVariant),
                    Expanded(
                      flex: 11,
                      child: _StatCell(value: seatCombined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ExamStatus _statusForExam(Subject exam) {
    // Debarred check: if venue/seat hints at debarred, prioritize red.
    final combined =
        '${exam.venue} ${exam.seatLocation} ${exam.seatNumber}'.toLowerCase();
    if (combined.contains('debar')) return _ExamStatus.debarred;

    final examDate = _parseExamDate(exam.date);
    if (examDate == null) return _ExamStatus.unknown;

    final today = _stripTime(DateTime.now());
    final examDay = _stripTime(examDate);

    if (examDay.isAtSameMomentAs(today)) return _ExamStatus.upcoming;
    if (examDay.isAfter(today)) return _ExamStatus.upcoming;
    return _ExamStatus.completed;
  }

  String _statusLabel(_ExamStatus status) {
    switch (status) {
      case _ExamStatus.today:
        return 'Today';
      case _ExamStatus.upcoming:
        return 'Upcoming';
      case _ExamStatus.completed:
        return 'Completed';
      case _ExamStatus.debarred:
        return 'Debarred';
      case _ExamStatus.unknown:
        return 'Scheduled';
    }
  }

  Color _statusColor(_ExamStatus status) {
    switch (status) {
      case _ExamStatus.completed:
        return const Color(0xFF22C55E); // green
      case _ExamStatus.upcoming:
      case _ExamStatus.today:
        return const Color(0xFFF59E0B); // orange / amber
      case _ExamStatus.debarred:
        return const Color(0xFFEF4444); // red
      case _ExamStatus.unknown:
        return const Color(0xFF9CA3AF);
    }
  }

  DateTime? _parseExamDate(String dateStr) {
    try {
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) return null;

      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12
      };

      final day = int.tryParse(dateParts[0]);
      final month = months[dateParts[1]];
      final year = int.tryParse(dateParts[2]);

      if (day == null || month == null || year == null) return null;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime _stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;

  const _StatCell({required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final Color color;
  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: color,
    );
  }
}
