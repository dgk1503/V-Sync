import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/liquid_glass_navigation_bar.dart';

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

void main() {
  testWidgets('hold drag follows fractionally and commits on release', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final commits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LiquidGlassNavigationBar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: commits.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.house), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookOpen), findsOneWidget);
    expect(find.byIcon(LucideIcons.userRound), findsOneWidget);
    expect(find.bySemanticsLabel('For You'), findsOneWidget);
    expect(find.bySemanticsLabel('Timetable'), findsOneWidget);
    expect(find.bySemanticsLabel('Academics'), findsOneWidget);
    expect(find.bySemanticsLabel('Account'), findsOneWidget);

    final timetable = tester.getCenter(find.byIcon(LucideIcons.calendarDays));
    final academics = tester.getCenter(find.byIcon(LucideIcons.bookOpen));
    final halfway = Offset(
      timetable.dx + (academics.dx - timetable.dx) * 0.6,
      timetable.dy,
    );
    final gesture = await tester.startGesture(timetable);
    await tester.pump(const Duration(milliseconds: 240));
    await gesture.moveTo(halfway);
    await tester.pump(const Duration(milliseconds: 16));

    // Crossing halfway must not switch the page while the finger is down.
    expect(commits, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [2]);
  });

  testWidgets('hold pickup glides the lens instead of teleporting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final commits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LiquidGlassNavigationBar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: commits.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The lens centre lives in the stack's local coordinate space; the painter
    // exposes it, so the test can observe the glide frame by frame.
    double lensX() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('liquid-glass-lens')),
      );
      return (paint.painter! as dynamic).centerX as double;
    }

    final forYou = tester.getCenter(find.byIcon(LucideIcons.house));
    final account = tester.getCenter(find.byIcon(LucideIcons.userRound));
    // The lens rests on For You; Account is a long distance away.
    final restX = lensX();
    final localTarget = restX + (account.dx - forYou.dx);
    expect(account.dx - forYou.dx, greaterThan(100));

    final gesture = await tester.startGesture(account);
    // Let the hold engage and the pickup slide run partway.
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 40));
    final midX = lensX();

    // The lens has begun moving off the resting tab...
    expect(midX, greaterThan(restX + 1));
    // ...but has not jumped straight to the hold region.
    expect(midX, lessThan(localTarget - 1));

    // It settles exactly on the held tab.
    await tester.pumpAndSettle();
    expect(lensX(), closeTo(localTarget, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, [3]);
  });

  testWidgets('hold expansion eases the lens size instead of stepping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: LiquidGlassNavigationBar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double expansion() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('liquid-glass-lens')),
      );
      return (paint.painter! as dynamic).expansion as double;
    }

    // The resting lens sits at its smallest size.
    expect(expansion(), closeTo(0, 0.001));

    final timetable = tester.getCenter(find.byIcon(LucideIcons.calendarDays));
    final gesture = await tester.startGesture(timetable);
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 30));
    final mid = expansion();

    // The size is mid-flight: larger than resting but not yet fully grown, so
    // it is animating rather than stepping straight to the held size.
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    // It settles fully open while held.
    await tester.pumpAndSettle();
    expect(expansion(), closeTo(1, 0.02));

    // Releasing eases it back down to the resting size.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(expansion(), closeTo(0, 0.02));
  });

  testWidgets('icon-only layout adapts to width and text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: LiquidGlassNavigationBar(
              destinations: const [
                LiquidGlassNavigationDestination(
                  icon: LucideIcons.house,
                  label: 'Home',
                ),
                LiquidGlassNavigationDestination(
                  icon: LucideIcons.userRound,
                  label: 'Account',
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.house), findsOneWidget);
    expect(find.byIcon(LucideIcons.userRound), findsOneWidget);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
