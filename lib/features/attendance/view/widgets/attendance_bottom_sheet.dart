import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/models/attendance.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_detail.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/detailed_attendance_viewmodel.dart';

void showAttendanceBottomSheet(BuildContext context, Attendance subjectInfo) {
  showModalBottomSheet<dynamic>(
    showDragHandle: true,
    isScrollControlled: true,
    context: context,
    builder: (BuildContext context) {
      return Consumer(
        builder: (context, ref, child) {
          // Fetch day-wise attendance as soon as the sheet opens.
          final detailedState = ref.read(detailedAttendanceViewmodelProvider);
          if (detailedState == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(detailedAttendanceViewmodelProvider.notifier)
                  .fetchDetailedAttendance(
                    courseId: subjectInfo.courseId,
                    courseType: subjectInfo.courseTypeCode,
                  );
            });
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              width: MediaQuery.of(context).size.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subjectInfo.courseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${subjectInfo.courseCode}  •  '
                                '${subjectInfo.attendancePercentage}%',
                                style: TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ref
                                .read(
                                    detailedAttendanceViewmodelProvider.notifier)
                                .fetchDetailedAttendance(
                                  courseId: subjectInfo.courseId,
                                  courseType: subjectInfo.courseTypeCode,
                                );
                          },
                          icon: Icon(
                            Iconsax.refresh_copy,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          tooltip: 'Reload',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildDetailedList(context, subjectInfo, ref),
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

Widget _buildDetailedList(
  BuildContext context,
  Attendance subjectInfo,
  WidgetRef ref,
) {
  return Consumer(
    builder: (context, ref, child) {
      final detailedAttendanceState = ref.watch(
        detailedAttendanceViewmodelProvider,
      );

      if (detailedAttendanceState == null ||
          detailedAttendanceState.isLoading) {
        return const Center(child: Loader());
      }

      return detailedAttendanceState.when(
        data: (attendanceDetails) =>
            _buildAttendanceTable(context, attendanceDetails),
        loading: () => const Center(child: Loader()),
        error: (error, stackTrace) => _buildErrorState(
          context,
          error.toString(),
          () {
            ref
                .read(detailedAttendanceViewmodelProvider.notifier)
                .fetchDetailedAttendance(
                  courseId: subjectInfo.courseId,
                  courseType: subjectInfo.courseTypeCode,
                );
          },
        ),
      );
    },
  );
}

Widget _buildErrorState(
  BuildContext context,
  String error,
  VoidCallback onRetry,
) {
  final colorScheme = Theme.of(context).colorScheme;

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'Failed to load day-wise attendance',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Iconsax.refresh_copy, size: 16),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

Widget _buildAttendanceTable(
  BuildContext context,
  List<AttendanceDetail> attendanceDetails,
) {
  final colorScheme = Theme.of(context).colorScheme;

  if (attendanceDetails.isEmpty) {
    return Center(
      child: Text(
        'No day-wise records yet',
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  return Column(
    children: [
      // Column labels
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'DATE',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'DAY/TIME',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'STATUS',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: attendanceDetails.length,
          separatorBuilder: (context, index) => Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 2),
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
            final detail = attendanceDetails[index];
            final isPresent = detail.status.toLowerCase() == 'present';
            final isAbsent = detail.status.toLowerCase() == 'absent';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatDate(detail.date),
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      detail.dayTime,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      detail.status,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isPresent
                            ? Colors.green
                            : isAbsent
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

String _formatDate(String dateStr) {
  try {
    // Assuming the date format from VTOP, adjust as needed
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final day = parts[0];
      final month = parts[1];
      final year = parts[2];
      return '$day/$month/$year';
    }
    return dateStr;
  } catch (e) {
    return dateStr;
  }
}
