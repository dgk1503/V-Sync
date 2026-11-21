import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/providers/bottom_nav_provider.dart';
import 'package:vit_ap_student_app/core/providers/liquid_glass_provider.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_shortcut.dart';
import 'package:vit_ap_student_app/features/thumb_dock/view/thumb_dock.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_active.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_settings.dart';

/// Puts the [ThumbDock] over the whole app and wires it to the Navigator.
///
/// Mounted once in `MaterialApp.builder`, above the Navigator like the OTP
/// prompt, so it is there on every page the user has pushed.
///
/// It is only shown when it can do something useful: switched on in
/// Customization, signed in, past onboarding (the main shell is up), with no
/// keyboard open and no full-screen OTP card over the app.
class ThumbDockHost extends ConsumerWidget {
  const ThumbDockHost({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  void _goTab(WidgetRef ref, int tab) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(bottomNavIndexProvider.notifier).state = tab;
  }

  void _goShortcut(WidgetRef ref, DockShortcut shortcut) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
    ref.read(bottomNavIndexProvider.notifier).state = 2;
    navigator.push(MaterialPageRoute<void>(builder: (_) => shortcut.build()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(thumbDockProvider);
    final active = ref.watch(thumbDockActiveProvider);
    final otp = ref.watch(loginOtpChallengeProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Hidden under the full OTP card, and while the keyboard is up - except
    // with an OTP waiting: then the dock is the only way back to it, so a
    // keyboard that lingers must never take it away.
    final show =
        active &&
        !(otp.isActive && !otp.isMinimized) &&
        (otp.isActive || !keyboardOpen);
    if (!show) return const SizedBox.shrink();

    return Positioned.fill(
      child: ThumbDock(
        rightSide: settings.rightSide,
        yFraction: settings.y,
        shortcuts: DockShortcuts.resolve(settings.shortcuts),
        glass: settings.glass,
        glassProgram: settings.glass
            ? ref.watch(liquidGlassProgramProvider).value
            : null,
        otpPending: otp.isActive,
        otpLabel: otp.isActive
            ? OtpChallenge.formatSeconds(otp.remainingSeconds)
            : null,
        onTab: (tab) => _goTab(ref, tab),
        onShortcut: (shortcut) => _goShortcut(ref, shortcut),
        onOtp: () => ref.read(loginOtpChallengeProvider.notifier).reopen(),
        onMoved: (rightSide, y) => ref
            .read(thumbDockProvider.notifier)
            .setPosition(rightSide: rightSide, y: y),
      ),
    );
  }
}
