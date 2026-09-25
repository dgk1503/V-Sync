import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/models/mark.dart';

void showMarksDetailBottomSheet(Mark course, BuildContext context) {
  double totalWeightage = 0;
  double lostWeightage = 0;

  for (var detail in course.details) {
    totalWeightage += double.tryParse(detail.weightageMark) ?? 0;

    final maxMark = double.parse(detail.maxMark);
    final scoredMark = double.parse(detail.scoredMark);
    final weightage = double.parse(detail.weightage);

    final lostMark = maxMark - scoredMark;
    lostWeightage += (lostMark * weightage / maxMark);
  }

  showModalBottomSheet<void>(
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final isDark = colorScheme.brightness == Brightness.dark;

      // Soft tinted card colors that work on both monochrome themes.
      final gainedCardColor =
          isDark ? const Color(0xFF12291B) : const Color(0xFFE7F2EA);
      final gainedTextColor = isDark
          ? const Color(0xFF7FC79B)
          : const Color(0xFF2E7D4F);
      final lostCardColor =
          isDark ? const Color(0xFF33161C) : const Color(0xFFF9E7EA);
      final lostTextColor = isDark
          ? const Color(0xFFE08A99)
          : const Color(0xFFB3243B);

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    course.courseTitle,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 27,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Faculty
                  Text(
                    'FACULTY',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    course.faculty,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Course code
                  Text(
                    'COURSE CODE',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    course.courseCode,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Gained / Lost weightage cards
                  Row(
                    children: [
                      Expanded(
                        child: _WeightageCard(
                          label: 'GAINED\nWEIGHTAGE',
                          value: totalWeightage.toStringAsFixed(1),
                          cardColor: gainedCardColor,
                          valueColor: gainedTextColor,
                          labelColor: gainedTextColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WeightageCard(
                          label: 'LOST\nWEIGHTAGE',
                          value: lostWeightage.toStringAsFixed(1),
                          cardColor: lostCardColor,
                          valueColor: lostTextColor,
                          labelColor: lostTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Details
                  Text(
                    'Details',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: course.details.length,
                    separatorBuilder: (context, index) => Container(
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
                    itemBuilder: (context, index) {
                      final detail = course.details[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                detail.markTitle,
                                style: TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: detail.scoredMark,
                                style: TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' / ${detail.maxMark}',
                                    style: TextStyle(
                                      fontFamily: 'Instrument Sans',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _WeightageCard extends StatelessWidget {
  final String label;
  final String value;
  final Color cardColor;
  final Color valueColor;
  final Color labelColor;

  const _WeightageCard({
    required this.label,
    required this.value,
    required this.cardColor,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              height: 1.4,
              color: labelColor.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
