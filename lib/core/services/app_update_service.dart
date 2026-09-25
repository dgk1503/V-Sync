import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

/// Checks Google Play for a newer published version of V-Sync.
///
/// This only works for Android builds installed from Google Play. The update
/// dialog and install flow remain controlled by Google Play; the app cannot
/// silently install or bypass the Play Store.
class AppUpdateService {
  AppUpdateService._();

  static bool _isChecking = false;

  static Future<void> checkForUpdate() async {
    if (!Platform.isAndroid || _isChecking) return;
    _isChecking = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
      }
    } on PlatformException {
      // A missing Play Store, a sideloaded build, or a transient Play Core
      // error should never prevent the app from starting.
    } catch (_) {
      // Update checks are best-effort and must never block app startup.
    } finally {
      _isChecking = false;
    }
  }
}
