import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/common/widget/segmented_tab_switcher.dart';

/// Regression test for the tab-switcher "delay": the selection pill must
/// track the TabController's animation value continuously (sliding), not
/// flip at the midpoint like the old AnimatedContainer implementation.
void main() {
  double leftOfPill(WidgetTester tester) {
    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    return positioned.left!;
  }

  testWidgets('selection pill slides continuously with the tab animation',
      (tester) async {
    await tester.pumpWidget(const _Host());

    // Starts on the first segment.
    expect(leftOfPill(tester), 0.0);

    // Segment width: test surface 800 - 32 page padding - 10 capsule padding,
    // split across 2 segments.
    const segmentWidth = (800.0 - 32 - 10) / 2;

    // A quarter of the way through the 300ms animateTo, the pill must
    // already be moving (old implementation would still be at 0).
    tester.state<_HostState>(find.byType(_Host)).controller.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final early = leftOfPill(tester);
    expect(early, greaterThan(0.0), reason: 'pill should start moving immediately');
    expect(early, lessThan(segmentWidth),
        reason: 'pill should not have arrived yet');

    // Halfway: pill must be somewhere in between (sliding, not flipping).
    await tester.pump(const Duration(milliseconds: 75));
    final midway = leftOfPill(tester);
    expect(midway, greaterThan(early));
    expect(midway, lessThan(segmentWidth));

    // Settles exactly on the second segment.
    await tester.pumpAndSettle();
    expect(leftOfPill(tester), closeTo(segmentWidth, 0.5));
  });

  testWidgets('tapping a segment selects it and the pill lands on it',
      (tester) async {
    await tester.pumpWidget(const _Host());

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    const segmentWidth = (800.0 - 32 - 10) / 2;
    expect(leftOfPill(tester), closeTo(segmentWidth, 0.5));
    expect(
      tester.state<_HostState>(find.byType(_Host)).controller.index,
      1,
    );
  });
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController controller =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SegmentedTabSwitcher(
          controller: controller,
          labels: const ['A', 'B'],
        ),
      ),
    );
  }
}
