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

void main() {
  testWidgets('static capsule bar renders a plain pill with no glass lens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final commits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: StaticCapsuleNavBar(
            destinations: _destinations,
            selectedIndex: 1,
            onSelected: commits.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every destination is reachable and labelled.
    expect(find.byIcon(LucideIcons.house), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookOpen), findsOneWidget);
    expect(find.byIcon(LucideIcons.userRound), findsOneWidget);
    expect(find.bySemanticsLabel('For You'), findsOneWidget);
    expect(find.bySemanticsLabel('Account'), findsOneWidget);

    // Crucially: no liquid lens, so nothing about this bar reads as glass.
    expect(find.byKey(const ValueKey('liquid-glass-lens')), findsNothing);
    expect(find.byType(LiquidGlassNavigationBar), findsNothing);

    // Tapping still navigates.
    await tester.tap(find.byIcon(LucideIcons.userRound));
    expect(commits, [3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('static capsule bar marks the selected tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: StaticCapsuleNavBar(
            destinations: _destinations,
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The active indicator is a filled circle in the accent colour, so the
    // circle under the selected glyph must not be transparent.
    final circle = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byIcon(LucideIcons.bookOpen),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = circle.decoration! as BoxDecoration;
    final colors = Theme.of(
      tester.element(find.byType(StaticCapsuleNavBar)),
    ).colorScheme;
    expect(decoration.color, colors.primary);
  });
}
