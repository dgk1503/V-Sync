import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';

/// The release the card talks about. Bump it (and the points below) with the
/// next release that has something to announce: the card then shows once more.
const String kWhatsNewVersion = '1.4.0';

/// Saved when the user presses "got it", not when the card appears: a card that
/// was swept away by accident must come back, not be lost for good.
const String _acknowledgedKey = 'whats_new_acknowledged_version';

/// One line on the card.
class WhatsNewPoint {
  const WhatsNewPoint(this.title, this.body, {this.tag});
  final String title;
  final String body;

  /// A small label beside the title ("beta").
  final String? tag;
}

const List<WhatsNewPoint> kWhatsNewPoints = [
  WhatsNewPoint(
    'Thumb Dock',
    'reach any page from the edge of your screen, with one thumb. '
        'switch it on in customization.',
    tag: 'beta',
  ),
  WhatsNewPoint(
    'A faster engine',
    'the scraper under the hood is leaner. quicker syncs, fewer failures.',
  ),
  WhatsNewPoint(
    'A cleaner look',
    'calmer screens and smoother motion, all through the app.',
  ),
  WhatsNewPoint(
    'Fewer bugs',
    'the rough edges from older versions are smoothed out.',
  ),
  WhatsNewPoint(
    'New tools',
    'skip planner, GPA planner and more, built right in.',
  ),
  WhatsNewPoint(
    'A better mess menu',
    'reads the sheets your hostel actually sends.',
  ),
];

/// "What's new in VSync 1.4.0": a one-time card, shown the first time the main
/// app is reached after an update (or a fresh sign-in), and not again once the
/// user has pressed "got it".
abstract final class WhatsNew {
  /// Whether this version's card has not been acknowledged yet.
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_acknowledgedKey) != kWhatsNewVersion;
    } catch (_) {
      // If storage cannot be read, stay quiet rather than risk showing it on
      // every launch.
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_acknowledgedKey, kWhatsNewVersion);
    } catch (_) {}
  }

  /// Shows the card if it is due. Call once the user has actually landed in the
  /// app: signed in, semester chosen, OTP (if any) entered. An OTP prompt that
  /// is still up is waited out, so the card never competes with it.
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    if (!await shouldShow()) return;
    if (!context.mounted) return;

    if (ref.read(loginOtpChallengeProvider).isActive) {
      final cleared = Completer<void>();
      final sub = ref.listenManual(loginOtpChallengeProvider, (_, next) {
        if (!next.isActive && !cleared.isCompleted) cleared.complete();
      });
      await cleared.future;
      sub.close();
    }
    // Let the freshly shown app settle first.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      // Only "got it" closes it: a stray tap beside the card must not.
      barrierDismissible: false,
      builder: (_) => const WhatsNewCard(),
    );
  }
}

/// The card's own black-and-white palette.
///
/// Deliberately not taken from the theme: the app's accent colours (and any
/// tint a theme gives its surfaces) must never reach this card. It follows only
/// whether the app is in light or dark mode.
class _Mono {
  const _Mono._({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.chip,
  });

  final Color surface;
  final Color ink;
  final Color muted;
  final Color chip;

  static const _dark = _Mono._(
    surface: Color(0xFF141414),
    ink: Color(0xFFF4F4F4),
    muted: Color(0xFF9C9C9C),
    chip: Color(0xFF282828),
  );

  static const _light = _Mono._(
    surface: Color(0xFFF6F6F6),
    ink: Color(0xFF111111),
    muted: Color(0xFF6A6A6A),
    chip: Color(0xFFE4E4E4),
  );

  static _Mono of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

class WhatsNewCard extends StatelessWidget {
  const WhatsNewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mono = _Mono.of(context);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: mono.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's new in VSync $kWhatsNewVersion",
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                    height: 1.2,
                    color: mono.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'thank you to everyone who has been here from the start. you '
                  'shaped this app, and with launch around the corner, it only '
                  'gets better.',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                    height: 1.5,
                    color: mono.muted,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        for (var i = 0; i < kWhatsNewPoints.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _Point(
                            number: i + 1,
                            point: kWhatsNewPoints[i],
                            mono: mono,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      unawaited(WhatsNew.markSeen());
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: mono.ink,
                      foregroundColor: mono.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'got it',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.number, required this.point, required this.mono});

  final int number;
  final WhatsNewPoint point;
  final _Mono mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$number.',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: mono.muted,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      point.title,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: mono.ink,
                      ),
                    ),
                  ),
                  if (point.tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: mono.chip,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        point.tag!,
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                          color: mono.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                point.body,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12.5,
                  height: 1.4,
                  color: mono.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
