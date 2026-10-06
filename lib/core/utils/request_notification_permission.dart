import 'package:permission_handler/permission_handler.dart';

/// Asks for notification permission, and reports whether it was granted.
///
/// Called from the one place the reason is obvious - switching on a countdown's
/// "Remind me before" - rather than at launch. A notification prompt shown to
/// someone who has not yet seen what the app does is the easiest one to
/// dismiss permanently.
///
/// Returns false when the user declines, and also when they have denied it
/// often enough that Android stops showing the dialog: in that case
/// [Permission.notification.request] resolves to permanentlyDenied without
/// asking, and the caller should send them to Settings instead of appearing to
/// retry.
Future<bool> requestNotificationPermission() async {
  final current = await Permission.notification.status;

  // Already asked, and the answer will not change without a trip to Settings.
  // Asking again is a no-op on Android, so skip straight to the answer.
  if (current.isPermanentlyDenied) return false;

  var status = current;
  if (status.isDenied) {
    status = await Permission.notification.request();
  }

  return status.isGranted;
}
