import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/general_outing_tab.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/weekend_outing_tab.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/outing_submission_viewmodel.dart';

class _FakeGeneral extends GeneralOutingSubmission {
  _FakeGeneral(this.calls);
  final List<String> calls;

  @override
  AsyncValue<String>? build() => null;

  @override
  Future<void> submitGeneralOuting({
    required String outPlace,
    required String purposeOfVisit,
    required String outingDate,
    required String outTime,
    required String inDate,
    required String inTime,
  }) async => calls.add(outPlace);
}

class _FakeWeekend extends WeekendOutingSubmission {
  _FakeWeekend(this.calls);
  final List<String> calls;

  @override
  AsyncValue<String>? build() => null;

  @override
  Future<void> submitWeekendOuting({
    required String outPlace,
    required String purposeOfVisit,
    required String outingDate,
    required String outTime,
    required String contactNumber,
  }) async => calls.add(outPlace);
}

Future<void> mount(
  WidgetTester tester,
  Widget tab,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: getThemeData(isDarkMode: true),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: tab),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('general outing', () {
    late List<String> calls;

    setUp(() => calls = []);

    Future<void> open(WidgetTester tester) => mount(
      tester,
      const GeneralOutingTab(),
      [generalOutingSubmissionProvider.overrideWith(() => _FakeGeneral(calls))],
    );

    testWidgets('an empty form says what is missing and applies for nothing', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('Please enter the place of visit'), findsOneWidget);
      expect(find.text('Please enter the purpose of visit'), findsOneWidget);
      expect(
        find.text('Please pick the day and time you leave'),
        findsOneWidget,
      );
      expect(
        find.text('Please pick the day and time you are back'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    });

    testWidgets('typing clears that field\'s message', (tester) async {
      await open(tester);
      await tester.tap(find.text('Apply'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Where are you going?'),
        'Vijayawada',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('Please enter the place of visit'), findsNothing);
      expect(find.text('Please enter the purpose of visit'), findsOneWidget);
    });

    testWidgets(
      'lays the form out as Where to / When with the past applications link',
      (tester) async {
        await open(tester);

        expect(find.text('Where to'), findsOneWidget);
        expect(find.text('When'), findsOneWidget);
        expect(find.text('Leaving'), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Past applications'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a date and a time are separate controls', (tester) async {
      await open(tester);

      expect(find.text('Select a date'), findsNWidgets(2));
      expect(find.text('Time'), findsNWidgets(2));
    });
  });

  group('weekend outing', () {
    late List<String> calls;

    setUp(() => calls = []);

    Future<void> open(WidgetTester tester) => mount(
      tester,
      const WeekendOutingTab(),
      [weekendOutingSubmissionProvider.overrideWith(() => _FakeWeekend(calls))],
    );

    testWidgets('lays out places and slots as choices', (tester) async {
      await open(tester);

      for (final place in [
        'Vijayawada',
        'Guntur',
        'Tenali',
        'Eluru',
        'Others',
      ]) {
        expect(find.text(place), findsOneWidget);
      }
      expect(find.text('Contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('applying without a date, purpose or number is refused', (
      tester,
    ) async {
      await open(tester);

      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('Please select a date'), findsOneWidget);
      expect(find.text('Please enter purpose'), findsOneWidget);
      expect(find.text('Please enter contact number'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('a short phone number is refused', (tester) async {
      await open(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '10 digit mobile number'),
        '12345',
      );
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(find.text('Contact number must be 10 digits'), findsOneWidget);
    });
  });
}
