import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/liquid_glass_navigation_bar.dart';
import 'package:vit_ap_student_app/core/common/widget/static_capsule_nav_bar.dart';

const _destinations = <LiquidGlassNavigationDestination>[
  LiquidGlassNavigationDestination(icon: LucideIcons.house, label: 'For You'),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.calendarDays,
    label: 'Timetable',
  ),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.bookOpen,
    label: 'Academics',
  ),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.userRound,
    label: 'Account',
  ),
];

/// Replicates the real shell from `bottom_navigation_bar.dart`: the navbar is
/// a child of the body Stack of a `Scaffold(extendBody: true)`, and the shell
/// extends the nav layer DOWN by the keyboard inset captured ABOVE the
/// Scaffold — where `MediaQuery` is still intact — to re-anchor it to the
/// physical screen bottom.
///
/// The nesting matters: injecting a modified `MediaQuery` below the Scaffold
/// is a no-op because the Scaffold never resizes in that case.
Widget _shell(Widget navbar) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        return Scaffold(
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: SizedBox.expand()),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: -keyboardInset,
                child: navbar,
              ),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  // 400x850 logical at devicePixelRatio 3.0 — the same geometry as the
  // diagnostic run recorded in docs/handover-navbar-keyboard.md.
  Future<void> setUpSurface(WidgetTester tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(400 * 3, 850 * 3);
    addTearDown(tester.view.reset);
  }

  // The keyboard is 320 PHYSICAL pixels tall; at dpr 3.0 that is 106.67
  // logical. Getting this wrong makes the keyboard far shorter than intended
  // and the test meaningless.
  void openKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
  }

  double iconBottom(WidgetTester tester) =>
      tester.getBottomRight(find.byIcon(LucideIcons.house).first).dy;

  testWidgets(
    'static capsule stays pinned to the screen bottom when the keyboard opens',
    (tester) async {
      await setUpSurface(tester);
      await tester.pumpWidget(
        _shell(
          StaticCapsuleNavBar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closedBottom = iconBottom(tester);
      expect(closedBottom, greaterThan(800), reason: 'sanity: bar is at the bottom');

      openKeyboard(tester);
      await tester.pump();
      await tester.pumpAndSettle();

      // The body was resized by the keyboard, but the capsule must not have
      // moved: it is pinned to the physical screen bottom, hidden behind the
      // IME like any screen-bottom surface.
      expect(iconBottom(tester), closeTo(closedBottom, 0.5));
    },
  );

  testWidgets(
    'liquid glass bar stays pinned to the screen bottom when the keyboard opens',
    (tester) async {
      await setUpSurface(tester);
      await tester.pumpWidget(
        _shell(
          LiquidGlassNavigationBar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closedBottom = iconBottom(tester);
      expect(closedBottom, greaterThan(800), reason: 'sanity: bar is at the bottom');

      openKeyboard(tester);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(iconBottom(tester), closeTo(closedBottom, 0.5));
    },
  );
}
