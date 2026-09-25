import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';

String normalizeStatus(String status) {
  return status.toLowerCase().replaceAll('’', "'").trim();
}

bool isWaitingForMentorApproval(String status) {
  return normalizeStatus(status) == "waiting for mentor's approval";
}

bool isWaitingForWardenApproval(String status) {
  return normalizeStatus(status) == "waiting for warden's approval";
}

Color getStatusColor(String status, BuildContext context) {
  final statusColors = AppStatusColors.of(context);
  switch (status.toLowerCase().trim()) {
    case 'leave request accepted':
    case 'outing request accepted':
      return statusColors.success;
    case 'waiting for warden\'s approval':
    case 'waiting for mentor\'s approval':
      return statusColors.warning;
    case 'rejected':
      return statusColors.danger;
    default:
      return statusColors.neutral;
  }
}

IconData getStatusIcon(String status) {
  switch (status.toLowerCase().trim()) {
    case 'leave request accepted':
    case 'outing request accepted':
      return Iconsax.tick_circle;
    case 'waiting for warden\'s approval':
      return Iconsax.clock;
    case 'rejected':
      return Iconsax.close_circle;
    default:
      return Iconsax.info_circle;
  }
}

/// Compact display label for outing application statuses; unknown
/// statuses are shown as-is rather than mislabelled.
String getOutingStatusLabel(String status) {
  switch (normalizeStatus(status)) {
    case 'leave request accepted':
    case 'outing request accepted':
      return 'Approved';
    case "waiting for warden's approval":
    case "waiting for mentor's approval":
      return 'Pending';
    case 'rejected':
      return 'Rejected';
    default:
      return status;
  }
}

String formatOutingDate(String date) {
  try {
    final dateString = DateTime.parse(date);

    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateString);
  } catch (e) {
    // Fallback to original string if parsing fails
    return date;
  }
}
