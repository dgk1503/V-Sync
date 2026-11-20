import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/providers/bottom_nav_provider.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_settings.dart';

/// Whether the Thumb Dock is switched on AND able to be on screen: signed in,
/// with the main app showing.
///
/// The OTP prompt reads this too: when the dock is active it carries the
/// collapsed OTP itself (a countdown on its handle) and the OTP's own floating
/// capsule stays away, so the two can never sit on top of each other. When it is
/// not active the capsule works exactly as before, so a waiting OTP always has
/// somewhere to live.
final thumbDockActiveProvider = Provider<bool>((ref) {
  // Cheapest checks first: nothing below is read while the dock is off.
  if (!ref.watch(thumbDockProvider.select((s) => s.enabled))) return false;
  if (!ref.watch(mainShellVisibleProvider)) return false;
  return ref.watch(currentUserProvider) != null;
});
