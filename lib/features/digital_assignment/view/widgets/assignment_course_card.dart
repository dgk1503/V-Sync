import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/digital_assignment/model/digital_assignment_model.dart';
import 'package:vit_ap_student_app/features/digital_assignment/view/pages/assignment_detail_page.dart';

class AssignmentCourseCard extends StatelessWidget {
  final DigitalAssignment assignment;

  const AssignmentCourseCard({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final counts = SubmissionCounts.fromDetails(assignment.details);
    final statusColors = AppStatusColors.of(context);

    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.courseTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            assignment.faculty,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            assignment.courseCode,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (counts.submitted > 0)
                _StatusChip(
                  label: '${counts.submitted} Submitted',
                  color: statusColors.success,
                ),
              if (counts.pending > 0)
                _StatusChip(
                  label: '${counts.pending} Pending',
                  color: statusColors.warning,
                ),
              if (counts.missed > 0)
                _StatusChip(
                  label: '${counts.missed} Missed',
                  color: statusColors.danger,
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AssignmentDetailPage(assignment: assignment),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
