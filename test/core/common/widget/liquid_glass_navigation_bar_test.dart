import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/liquid_glass_navigation_bar.dart';

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
            destinations: const [
              LiquidGlassNavigationDestination(
                icon: LucideIcons.house,
                label: 'For You',
              ),
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
            ],
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
