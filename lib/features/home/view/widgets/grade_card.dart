import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/models/grade_history.dart';

class GradeCard extends StatelessWidget {
  final Course course;

  const GradeCard({super.key, required this.course});

  /// Monochrome-friendly grade hierarchy: gold at the very top, greens
  /// after that, warm tones in the middle, red at the bottom.
  static (Color, Color) _gradeColors(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'S':
        return (const Color(0xFFFFC93C), const Color(0xFF4A3200)); // gold
      case 'A':
        return (const Color(0xFF2E7D32), Colors.white); // dark green
      case 'B':
        return (const Color(0xFF66BB6A), Colors.white); // medium green
      case 'C':
        return (const Color(0xFFAFB42B), Colors.white); // olive / lime
      case 'D':
        return (const Color(0xFFF9A825), Colors.white); // amber
      case 'E':
        return (const Color(0xFFEF6C00), Colors.white); // orange
      case 'F':
        return (const Color(0xFFC62828), Colors.white); // red
      default:
        return (const Color(0xFF212121), Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (badgeColor, badgeTextColor) = _gradeColors(course.grade);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Grade badge — S gets a shiny gold gradient.
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: course.grade.trim().toUpperCase() == 'S'
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFE082),
                            Color(0xFFFFC93C),
                            Color(0xFFE6A817),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        )
                      : null,
                  color: course.grade.trim().toUpperCase() == 'S'
                      ? null
                      : badgeColor,
                ),
                child: Text(
                  course.grade,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    color: badgeTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 15.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.courseCode,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.outlineVariant.withValues(alpha: 0),
                  colorScheme.outlineVariant.withValues(alpha: 0.6),
                  colorScheme.outlineVariant.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Meta row: credits, exam month, course type
          Row(
            children: [
              Icon(
                Iconsax.book_copy,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                '${course.credits} Credits',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Iconsax.calendar_copy,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                course.examMonth,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Iconsax.medal_star_copy,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  course.courseType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
