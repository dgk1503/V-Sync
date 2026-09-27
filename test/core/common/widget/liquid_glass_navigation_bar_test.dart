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
    // Let the hold engage, then sample partway through the slow pickup glide.
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 220));
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

  testWidgets('glass lags behind the finger instead of tracking it exactly', (
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

    double lensX() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('liquid-glass-lens')),
      );
      return (paint.painter! as dynamic).centerX as double;
    }

    final forYou = tester.getCenter(find.byIcon(LucideIcons.house));
    final account = tester.getCenter(find.byIcon(LucideIcons.userRound));
    final restX = lensX();

    final gesture = await tester.startGesture(account);
    await tester.pump(const Duration(milliseconds: 240));
    // Let the long pickup glide finish and the material come fully to rest on
    // Account, so the next sample starts from a genuine standstill.
    await tester.pumpAndSettle();
    final atAccount = lensX();
    expect(atAccount, greaterThan(restX + 100));

    // Now jump the finger back to For You and look a few frames in.
    await gesture.moveTo(forYou);
    await tester.pump(const Duration(milliseconds: 50));
    final oneFrameLater = lensX();
    // The glass has started flowing toward the finger...
    expect(oneFrameLater, lessThan(atAccount));
    // ...but the material has mass, so it has NOT arrived yet.
    expect(oneFrameLater, greaterThan(restX + 1));

    await gesture.up();
    await tester.pumpAndSettle();
    // Releasing on the already-selected tab is not a change, so nothing fires.
    expect(commits, isEmpty);
    expect(lensX(), closeTo(restX, 0.5));
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

  testWidgets('a long frame stall cannot make the spring diverge', (
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

    double lensX() {
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('liquid-glass-lens')),
      );
      return (paint.painter! as dynamic).centerX as double;
    }

    final restX = lensX();

    // Hold on Account, then simulate a stalled frame (200ms) repeatedly. The
    // integrator clamps the catch-up step, and an explicit damped spring goes
    // unstable at that step size unless it is sub-stepped.
    final account = tester.getCenter(find.byIcon(LucideIcons.userRound));
    final gesture = await tester.startGesture(account);
    await tester.pump(const Duration(milliseconds: 240));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      final x = lensX();
      expect(x.isFinite, isTrue, reason: 'lens position diverged on frame $i');
    }

    await tester.pumpAndSettle();
    final settled = lensX();
    expect(settled.isFinite, isTrue);
    expect(settled, greaterThan(restX + 100));

    // Releasing on the held tab keeps the lens there, still finite.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(lensX().isFinite, isTrue);
    expect(lensX(), closeTo(settled, 0.5));
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
