import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/model/biometric.dart';
import 'package:vit_ap_student_app/features/home/view/pages/biometric_page.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/biometric_viewmodel.dart';

class _FakeBiometric extends BiometricViewModel {
  _FakeBiometric(this.answers, this.calls, {this.delay = Duration.zero});

  /// How long VTOP takes. A real request spans many frames, which is what let
  /// the provider be disposed under a page that was not listening to it.
  final Duration delay;

  /// What each requested date answers with. A missing date answers empty.
  final Map<String, List<Biometric>> answers;
  final List<String> calls;

  @override
  AsyncValue<List<Biometric>>? build() => null;

  @override
  Future<void> fetchBiometric(String date) async {
    calls.add(date);
    state = const AsyncValue.loading();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    state = AsyncValue.data(answers[date] ?? const []);
  }
}

String vtopDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

Future<void> mount(
  WidgetTester tester,
  Map<String, List<Biometric>> answers,
  List<String> calls, {
  Duration delay = Duration.zero,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biometricViewModelProvider.overrideWith(
          () => _FakeBiometric(answers, calls, delay: delay),
        ),
      ],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: const BiometricPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  testWidgets('opens on today and loads it', (tester) async {
    final calls = <String>[];
    await mount(tester, {
      vtopDate(today): [
        Biometric(time: '17:30', location: 'Hostel gate'),
        Biometric(time: '08:12', location: 'Academic block'),
      ],
    }, calls);

    expect(calls, [vtopDate(today)]);
    expect(find.text('2 entries'), findsNothing); // part of a longer line
    expect(find.textContaining('· 2 entries'), findsOneWidget);
    expect(find.text('Academic block'), findsOneWidget);
  });

  testWidgets('shows the entries in the order they happened, in 12 hour time', (
    tester,
  ) async {
    await mount(tester, {
      vtopDate(today): [
        Biometric(time: '17:30', location: 'Hostel gate'),
        Biometric(time: '08:12', location: 'Academic block'),
      ],
    }, <String>[]);

    // Matched on the digits: newer intl puts a narrow no-break space before AM/PM.
    final morning = tester.getTopLeft(find.textContaining('8:12')).dy;
    final evening = tester.getTopLeft(find.textContaining('5:30')).dy;
    expect(find.textContaining('AM'), findsWidgets);
    expect(find.textContaining('PM'), findsWidgets);
    expect(morning, lessThan(evening));
  });

  testWidgets('another day loads on tap, and going back costs no request', (
    tester,
  ) async {
    final calls = <String>[];
    await mount(tester, {
      vtopDate(today): [Biometric(time: '08:00', location: 'Block A')],
      vtopDate(yesterday): [Biometric(time: '09:00', location: 'Block B')],
    }, calls);

    await tester.tap(find.text('Yesterday'));
    await tester.pump();
    await tester.pump();
    expect(calls, [vtopDate(today), vtopDate(yesterday)]);
    expect(find.text('Block B'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(calls, hasLength(2), reason: 'today was already loaded');
    expect(find.text('Block A'), findsOneWidget);
  });

  testWidgets('a day with nothing says so', (tester) async {
    await mount(tester, const {}, <String>[]);

    expect(find.text('No entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers the last week and a way to pick an older day', (
    tester,
  ) async {
    await mount(tester, const {}, <String>[]);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    // The strip scrolls sideways, so the last chip is reached by scrolling.
    await tester.scrollUntilVisible(
      find.text('Pick date'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pick date'), findsOneWidget);
  });

  testWidgets('a slow response still arrives and replaces the spinner', (
    tester,
  ) async {
    await mount(
      tester,
      {
        vtopDate(today): [Biometric(time: '08:12', location: 'Academic block')],
      },
      <String>[],
      delay: const Duration(seconds: 2),
    );

    expect(find.text('Fetching your biometric log'), findsOneWidget);

    // Many frames pass while VTOP answers.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Fetching your biometric log'), findsNothing);
    expect(find.text('Academic block'), findsOneWidget);
  });
}
