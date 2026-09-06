import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/features/home/model/general_outing_report.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/outing/general_outing_detail_bottom_sheet.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/outing/utils.dart';

/// Minimal history entry for a general outing application: place, purpose
/// and a single metadata line, with the status pill riding on the right.
class GeneralOutingCard extends StatelessWidget {
  final GeneralOutingReport outing;

  const GeneralOutingCard({super.key, required this.outing});

  bool _isToday() {
    try {
      final fromDate = DateTime.parse(outing.fromDate);
      final toDate = DateTime.parse(outing.toDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return (today.isAtSameMomentAs(
                DateTime(fromDate.year, fromDate.month, fromDate.day),
              ) ||
              today.isAfter(
                DateTime(fromDate.year, fromDate.month, fromDate.day),
              )) &&
          (today.isAtSameMomentAs(
                DateTime(toDate.year, toDate.month, toDate.day),
              ) ||
              today.isBefore(DateTime(toDate.year, toDate.month, toDate.day)));
    } catch (e) {
      return false;
    }
  }

  int _getDurationDays() {
    try {
      final fromDate = DateTime.parse(outing.fromDate);
      final toDate = DateTime.parse(outing.toDate);
      return toDate.difference(fromDate).inDays + 1;
    } catch (e) {
      return 1;
    }
  }

  String _formatDateRange() {
    try {
      final fromDate = DateTime.parse(outing.fromDate);
      final toDate = DateTime.parse(outing.toDate);
      final fromFormatter = DateFormat('MMM d');
      final toFormatter = DateFormat('MMM d, yyyy');

      if (fromDate.year == toDate.year && fromDate.month == toDate.month) {
        if (fromDate.day == toDate.day) {
          return toFormatter.format(fromDate);
        }
        return '${fromDate.day} - ${toFormatter.format(toDate)}';
      }
      return '${fromFormatter.format(fromDate)} - ${toFormatter.format(toDate)}';
    } catch (e) {
      return '${outing.fromDate} - ${outing.toDate}';
    }
  }

  String _formatTimeRange() {
    final from = outing.fromTime.trim();
    final to = outing.toTime.trim();
    if (from.isEmpty && to.isEmpty) return '';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from – $to';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = getStatusColor(outing.status, context);
    final isToday = _isToday();
    final durationDays = _getDurationDays();

    final metaParts = <String>[
      _formatDateRange(),
      if (durationDays > 1) '$durationDays days',
      if (_formatTimeRange().isNotEmpty) _formatTimeRange(),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showGeneralOutingDetailBottomSheet(outing, context),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outing.placeOfVisit.isNotEmpty)
                    Text(
                      outing.placeOfVisit,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (outing.purposeOfVisit.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      outing.purposeOfVisit,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isToday) ...[
                        _TodayPill(colorScheme: colorScheme),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          metaParts.join('  ·  '),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      getOutingStatusLabel(outing.status),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (outing.canDownload) ...[
                  const SizedBox(height: 6),
                  Icon(
                    Iconsax.document_download,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  final ColorScheme colorScheme;

  const _TodayPill({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'TODAY',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
