import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_layout.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_shortcut.dart';
import 'package:vit_ap_student_app/features/thumb_dock/view/thumb_dock.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_settings.dart';

const _screen = Size(412, 915);

DockLayout _layout({
  bool rightSide = true,
  double handleY = 500,
  int mainCount = 4,
  int subCount = 3,
}) => DockLayout(
  size: _screen,
  padding: const EdgeInsets.only(top: 30, bottom: 20),
  rightSide: rightSide,
  handleY: handleY,
  mainCount: mainCount,
  academicsIndex: 2,
  subCount: subCount,
);

void main() {
  group('the dock layout', () {
    test('keeps its column on the screen however the handle is placed', () {
      for (final y in [0.0, 40.0, 500.0, 900.0, 915.0]) {
        for (final right in [true, false]) {
          final l = _layout(handleY: y, rightSide: right);
          expect(l.columnTop, greaterThanOrEqualTo(30 + 56));
          expect(l.columnTop + l.columnHeight, lessThanOrEqualTo(915 - 20));
        }
      }
    });

    test('puts the column against the edge the dock is on', () {
      expect(_layout(rightSide: true).columnX, greaterThan(_screen.width / 2));
      expect(_layout(rightSide: false).columnX, lessThan(_screen.width / 2));
    });

    test('a finger over an item hits it, on either side', () {
      for (final right in [true, false]) {
        final l = _layout(rightSide: right);
        for (var i = 0; i < 4; i++) {
          expect(l.hit(l.mainCenter(i), subsOpen: false), DockHit.main(i));
        }
      }
    });

    test('a finger well away from the column hits nothing', () {
      final l = _layout();
      expect(l.hit(const Offset(40, 500), subsOpen: false), isNull);
      expect(l.hit(Offset(l.columnX, 20), subsOpen: false), isNull);
    });

    test('shortcuts grow inward from Academics and only count once open', () {
      for (final right in [true, false]) {
        final l = _layout(rightSide: right);
        for (var j = 0; j < 3; j++) {
          final c = l.subCenter(j);
          expect(c.dy, l.mainCenter(2).dy);
          expect(
            right ? c.dx < l.columnX : c.dx > l.columnX,
            isTrue,
            reason: 'row grows toward the middle of the screen',
          );
          expect(l.hit(c, subsOpen: true), DockHit.sub(j));
        }
        // Closed, the same spot is empty space.
        expect(l.hit(l.subCenter(1), subsOpen: false), isNull);
      }
    });

    test('the longest row still fits a 360 dp phone', () {
      const narrow = Size(360, 780);
      for (final right in [true, false]) {
        final l = DockLayout(
          size: narrow,
          padding: EdgeInsets.zero,
          rightSide: right,
          handleY: 400,
          mainCount: 4,
          academicsIndex: 2,
          subCount: DockLayout.maxSubs,
        );
        final last = l.subCenter(DockLayout.maxSubs - 1);
        expect(last.dx - DockLayout.subSize / 2, greaterThanOrEqualTo(0));
        expect(last.dx + DockLayout.subSize / 2, lessThanOrEqualTo(360));
      }
    });

    test('sliding along the column picks the nearest item', () {
      final l = _layout();
      final between =
          (l.mainCenter(0).dy + l.mainCenter(1).dy) / 2 - 4; // nearer item 0
      expect(
        l.hit(Offset(l.columnX - 20, between), subsOpen: false),
        DockHit.main(0),
      );
    });
  });

  group('the dock', () {
    final taps = <int>[];
    final shortcuts = <String>[];
    var otpTaps = 0;
    ({bool right, double y})? moved;

    Future<void> pump(
      WidgetTester tester, {
      bool right = true,
      double y = 0.55,
      bool otp = false,
      String? otpLabel,
      bool glass = false,
      List<String> ids = const ['attendance', 'marks', 'exams'],
    }) async {
      taps.clear();
      shortcuts.clear();
      otpTaps = 0;
      moved = null;
      await tester.binding.setSurfaceSize(_screen);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ThumbDock(
                    rightSide: right,
                    yFraction: y,
                    shortcuts: DockShortcuts.resolve(ids),
                    otpPending: otp,
                    otpLabel: otpLabel,
                    glass: glass,
                    onTab: taps.add,
                    onShortcut: (s) => shortcuts.add(s.id),
                    onOtp: () => otpTaps++,
                    onMoved: (r, v) => moved = (right: r, y: v),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // The handle sits at the screen edge, at the saved height.
    Offset handle({bool right = true, double y = 0.55}) {
      // 915 high, top inset 0: top = 24, usable = 915 - 48.
      final handleY = 24 + y * (915 - 48);
      return Offset(right ? 412 - 9 : 9, handleY);
    }

    DockLayout open({bool right = true, double y = 0.55, bool otp = false}) =>
        DockLayout(
          size: _screen,
          padding: EdgeInsets.zero,
          rightSide: right,
          handleY: 24 + y * (915 - 48),
          mainCount: otp ? 5 : 4,
          academicsIndex: otp ? 3 : 2,
          subCount: 3,
        );

    testWidgets('shows only its small marked handle until it is used', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
      expect(find.byIcon(LucideIcons.house), findsNothing);
      expect(find.byIcon(LucideIcons.bookOpen), findsNothing);
    });

    testWidgets('the last item matches the navbar: Account, same glyph', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(handle());
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.userRound), findsOneWidget);
      expect(find.byIcon(LucideIcons.settings), findsNothing);
    });

    testWidgets('hold, slide onto a page and let go: opens it', (tester) async {
      await pump(tester);
      final l = open();

      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.byIcon(LucideIcons.house), findsOneWidget);

      await g.moveTo(l.mainCenter(1));
      await tester.pump();
      expect(find.text('Timetable'), findsOneWidget, reason: 'its name shows');
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, [1]);
      expect(find.byIcon(LucideIcons.house), findsNothing, reason: 'it closed');
    });

    testWidgets('hold, slide onto Academics and across to a shortcut', (
      tester,
    ) async {
      await pump(tester);
      final l = open();

      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(l.mainCenter(2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byIcon(LucideIcons.listChecks),
        findsOneWidget,
        reason: 'the shortcuts unfold',
      );

      await g.moveTo(l.subCenter(1));
      await tester.pump();
      expect(find.text('Marks'), findsOneWidget);
      await g.up();
      await tester.pumpAndSettle();

      expect(shortcuts, ['marks']);
      expect(taps, isEmpty, reason: 'a shortcut is not also a tab change');
    });

    testWidgets('releasing on Academics itself goes to the tab', (
      tester,
    ) async {
      await pump(tester);
      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(open().mainCenter(2));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, [2]);
      expect(find.byIcon(LucideIcons.listChecks), findsNothing);
    });

    testWidgets('letting go on empty space after sliding closes it', (
      tester,
    ) async {
      await pump(tester);
      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(const Offset(60, 200));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
      expect(shortcuts, isEmpty);
      expect(find.byIcon(LucideIcons.house), findsNothing);
    });

    testWidgets('a tap opens it and each choice is a plain tap', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(handle());
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.house), findsOneWidget);

      await tester.tapAt(open().mainCenter(3));
      await tester.pumpAndSettle();
      expect(taps, [3]);
      expect(find.byIcon(LucideIcons.house), findsNothing);
    });

    testWidgets('tapping Academics goes there and keeps its shortcuts up', (
      tester,
    ) async {
      await pump(tester);
      await tester.tapAt(handle());
      await tester.pumpAndSettle();

      await tester.tapAt(open().mainCenter(2));
      await tester.pumpAndSettle();
      expect(taps, [2]);
      expect(find.byIcon(LucideIcons.clipboardCheck), findsOneWidget);

      await tester.tapAt(open().subCenter(0));
      await tester.pumpAndSettle();
      expect(shortcuts, ['attendance']);
      expect(find.byIcon(LucideIcons.house), findsNothing);
    });

    testWidgets('tapping outside the menu closes it', (tester) async {
      await pump(tester);
      await tester.tapAt(handle());
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(80, 120));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.house), findsNothing);
      expect(taps, isEmpty);
    });

    testWidgets('dragging the handle moves it, to the nearer side', (
      tester,
    ) async {
      await pump(tester);
      final g = await tester.startGesture(handle());
      await g.moveTo(const Offset(300, 450));
      await tester.pump();
      await g.moveTo(const Offset(60, 200));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(moved, isNotNull);
      expect(moved!.right, isFalse);
      expect(moved!.y, closeTo((200 - 24) / (915 - 48), 0.01));
      expect(
        find.byIcon(LucideIcons.house),
        findsNothing,
        reason: 'moving it does not open it',
      );
    });

    testWidgets('works from the left edge too', (tester) async {
      await pump(tester, right: false);
      final l = open(right: false);
      final g = await tester.startGesture(handle(right: false));
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(l.mainCenter(0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, [0]);
    });

    testWidgets('a waiting OTP: tapping the handle goes straight to it', (
      tester,
    ) async {
      await pump(tester, otp: true, otpLabel: '02:41');
      expect(
        find.text('02:41'),
        findsOneWidget,
        reason: 'countdown on the tab',
      );
      expect(find.byIcon(LucideIcons.keyRound), findsOneWidget);

      await tester.tapAt(handle());
      await tester.pumpAndSettle();
      expect(otpTaps, 1);
      expect(find.byIcon(LucideIcons.house), findsNothing, reason: 'no menu');
    });

    testWidgets('a waiting OTP: the menu still has the key', (tester) async {
      await pump(tester, otp: true, otpLabel: '02:41');
      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(open(otp: true).mainCenter(0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(otpTaps, 1);
      expect(taps, isEmpty);
    });

    testWidgets('glass on, without its shader, still works', (tester) async {
      await pump(tester, glass: true);
      expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);

      final l = open();
      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(l.mainCenter(1));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, [1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with the key present, Academics is still Academics', (
      tester,
    ) async {
      await pump(tester, otp: true);
      final g = await tester.startGesture(handle());
      await tester.pump(const Duration(milliseconds: 320));
      await g.moveTo(open(otp: true).mainCenter(3));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(taps, [2]);
    });

    testWidgets('no shortcuts chosen means no row, just the tab', (
      tester,
    ) async {
      await pump(tester, ids: const []);
      await tester.tapAt(handle());
      await tester.pumpAndSettle();
      await tester.tapAt(open().mainCenter(2));
      await tester.pumpAndSettle();

      expect(taps, [2]);
      expect(find.byIcon(LucideIcons.house), findsNothing, reason: 'it closed');
    });
  });

  group('the dock settings', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('start switched off, on the right, with the three usual pages', () {
      SharedPreferences.setMockInitialValues({});
      final s = container().read(thumbDockProvider);
      expect(s.enabled, isFalse);
      expect(s.rightSide, isTrue);
      expect(s.shortcuts, ['attendance', 'marks', 'exams']);
    });

    test('remember what was chosen', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      final n = c.read(thumbDockProvider.notifier);
      n.setEnabled(true);
      n.setPosition(rightSide: false, y: 0.3);
      n.toggleShortcut('grades');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(thumbDockProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = again.read(thumbDockProvider);
      expect(s.enabled, isTrue);
      expect(s.rightSide, isFalse);
      expect(s.y, closeTo(0.3, 1e-9));
      expect(s.shortcuts, ['attendance', 'marks', 'exams', 'grades']);
    });

    test('toggling a shortcut adds it, then removes it', () {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      final n = c.read(thumbDockProvider.notifier);
      n.toggleShortcut('outing');
      expect(c.read(thumbDockProvider).shortcuts.last, 'outing');
      n.toggleShortcut('outing');
      expect(c.read(thumbDockProvider).shortcuts, isNot(contains('outing')));
    });

    test('a full row refuses another shortcut', () {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      final n = c.read(thumbDockProvider.notifier);
      n.toggleShortcut('calendar');
      n.toggleShortcut('grades');
      expect(c.read(thumbDockProvider).shortcuts.length, 5);
      n.toggleShortcut('outing');
      expect(c.read(thumbDockProvider).shortcuts.length, 5);
      expect(c.read(thumbDockProvider).shortcuts, isNot(contains('outing')));
    });

    test('Attendance and Marks cannot be removed', () {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      final n = c.read(thumbDockProvider.notifier);
      n.toggleShortcut('attendance');
      n.toggleShortcut('marks');
      expect(c.read(thumbDockProvider).shortcuts.take(2), [
        'attendance',
        'marks',
      ]);
    });

    test('the other three can all be changed', () {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      final n = c.read(thumbDockProvider.notifier);
      n.toggleShortcut('exams'); // take the default one out
      expect(c.read(thumbDockProvider).shortcuts, ['attendance', 'marks']);
      n.toggleShortcut('grades');
      n.toggleShortcut('outing');
      n.toggleShortcut('faculty');
      expect(c.read(thumbDockProvider).shortcuts, [
        'attendance',
        'marks',
        'grades',
        'outing',
        'faculty',
      ]);
      n.toggleShortcut('calendar');
      expect(
        c.read(thumbDockProvider).shortcuts.length,
        5,
        reason: 'at most 5',
      );
    });

    test('whatever was saved, the row is valid', () {
      expect(
        ThumbDockSettings.normalise(['grades', 'attendance']),
        ['attendance', 'marks', 'grades'],
        reason: 'the locked pair is put back, first',
      );
      expect(
        ThumbDockSettings.normalise([
          'marks',
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
          'a',
        ]).length,
        5,
      );
      expect(ThumbDockSettings.normalise([]), ['attendance', 'marks']);
    });

    test('the height is kept inside the screen', () {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      c.read(thumbDockProvider.notifier).setPosition(rightSide: true, y: 4);
      expect(c.read(thumbDockProvider).y, 1.0);
    });

    test('an id that no longer exists is skipped', () {
      expect(
        DockShortcuts.resolve(['marks', 'gone', 'exams']).map((s) => s.id),
        ['marks', 'exams'],
      );
    });

    test('every shortcut has a unique id', () {
      final ids = DockShortcuts.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
