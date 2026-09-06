import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/core/models/user_preferences.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/account/view/pages/customization_page.dart';

/// Fake preferences source so the page renders without ObjectBox.
class _FakePreferences extends UserPreferencesNotifier {
  @override
  UserPreferences build() => UserPreferences();
}

final GlobalKey _renderKey = GlobalKey();

void main() {
  testWidgets('customization page renders every toggle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(412, 915));

    await tester.pumpWidget(
      RepaintBoundary(
        key: _renderKey,
        child: ProviderScope(
          overrides: [
            userPreferencesProvider.overrideWith(_FakePreferences.new),
          ],
          child: const MaterialApp(home: CustomizationPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customization'), findsOneWidget);
    expect(find.text('Academics page'), findsOneWidget);
    expect(find.text('Navbar'), findsOneWidget);
    expect(find.text('Grades'), findsOneWidget);
    expect(find.text('Digital Assignments'), findsOneWidget);
    expect(find.text('Outing'), findsOneWidget);
    expect(find.text('Faculty Info'), findsOneWidget);
    expect(find.text('Open VTOP'), findsOneWidget);
    expect(find.text('Liquid Glass'), findsOneWidget);

    // Defaults: the five card toggles ON, Liquid Glass OFF.
    Switch getSwitch(String label) => tester.widget<Switch>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(ListTile),
              )
              .first,
        ) as Switch;
    // (Switch.adaptive wraps a Switch on non-Apple platforms; locate via
    // descendant instead to stay platform-independent.)
    bool switchValue(String label) {
      final tileFinder = find.ancestor(
        of: find.text(label),
        matching: find.byType(ListTile),
      );
      final switchFinder = find.descendant(
        of: tileFinder,
        matching: find.bySubtype<Switch>(),
      );
      final widget = tester.widget(switchFinder.first);
      // Switch.adaptive exposes `value` on the AdaptiveSwitch subclass.
      // ignore: avoid_dynamic_calls
      return (widget as dynamic).value as bool;
    }

    // Defaults: every toggle ON — the five cards and Liquid Glass.
    expect(switchValue('Grades'), isTrue);
    expect(switchValue('Digital Assignments'), isTrue);
    expect(switchValue('Outing'), isTrue);
    expect(switchValue('Faculty Info'), isTrue);
    expect(switchValue('Open VTOP'), isTrue);
    expect(switchValue('Liquid Glass'), isTrue);

    // Persist a render so a human (or agent) can eyeball the layout.
    await tester.binding.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_renderKey),
      );
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List() ?? Uint8List(0);
      final file = File('.screenshots/customization_render.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    });
    expect(tester.takeException(), isNull);
  });
}
