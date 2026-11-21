import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/mess/mess_menu_section.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/mess_menu_viewmodel.dart';

class _FakeMenu extends MessMenuNotifier {
  _FakeMenu(this._menu);
  final MessMenu _menu;

  @override
  MessMenu? build() => _menu;
}

/// The real workbook, moved into the current month so "today" is inside it.
MessMenu thisMonth({bool special = true}) {
  final bytes = File('test/fixtures/mess-menu-2026-11.xlsx').readAsBytesSync();
  final json = MessMenuService.parseXlsx(bytes).toJson();
  final now = DateTime.now();
  json['month'] = now.month;
  json['year'] = now.year;
  json['monthName'] = 'Now';
  if (!special) json.remove('extraSheets');
  return MessMenu.fromJson(json);
}

Future<ProviderContainer> mount(WidgetTester tester, MessMenu menu) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [messMenuProvider.overrideWith(() => _FakeMenu(menu))],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const Scaffold(
          body: SingleChildScrollView(child: MessMenuSection()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(MessMenuSection)),
  );
}

/// Opens the sheet behind the month name above the menu.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('Now'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the menu page itself carries no menu pills', (tester) async {
    await mount(tester, thisMonth());

    expect(find.text('Veg & Non-Veg'), findsNothing);
    expect(find.text('Special'), findsNothing);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a workbook with two menus offers both in the sheet', (
    tester,
  ) async {
    await mount(tester, thisMonth());
    await openSheet(tester);

    expect(find.text('Show menu'), findsOneWidget);
    expect(find.text('Veg & Non-Veg'), findsOneWidget);
    expect(find.text('Special'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing Special is remembered, and named at the top', (
    tester,
  ) async {
    final container = await mount(tester, thisMonth());
    expect(container.read(messSheetProvider), isNull);

    await openSheet(tester);
    await tester.tap(find.text('Special'));
    await tester.pumpAndSettle();

    expect(container.read(messSheetProvider), 'Special');
    expect(find.text('Now · Special'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single menu offers no choice', (tester) async {
    await mount(tester, thisMonth(special: false));
    await openSheet(tester);

    expect(find.text('Show menu'), findsNothing);
    expect(find.text('Special'), findsNothing);
    expect(find.text('Delete menu'), findsOneWidget);
  });

  testWidgets('every action stays on a short screen, Delete included', (
    tester,
  ) async {
    await mount(tester, thisMonth());
    tester.view.physicalSize = const Size(720, 1280); // 360 x 640 logical
    await openSheet(tester);

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (final label in ['Insert Excel file', 'Delete menu']) {
      final box = tester.getRect(find.text(label));
      expect(box.bottom, lessThanOrEqualTo(screen), reason: label);
    }
    expect(tester.takeException(), isNull);
  });
}
