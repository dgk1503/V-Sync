import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_detail.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_calendar_card.dart';

AttendanceDetail _record(String date, String status) => AttendanceDetail(
  serial: '1',
  date: date,
  slot: 'A1',
  dayTime: '08:00 - 08:50',
  status: status,
  remark: '',
);

Future<void> host(WidgetTester tester, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: getThemeData(isDarkMode: false),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// The month currently drawn by the slider.
String _visibleTitle(WidgetTester tester) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  for (final name in names) {
    final year = [2026, 2027, 2028];
    for (final y in year) {
      if (find.text('$name $y').evaluate().isNotEmpty) return '$name $y';
    }
  }
  return '';
}

int _visibleRings(WidgetTester tester) {
  var count = 0;
  for (final container in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = container.decoration;
    if (decoration is! BoxDecoration) continue;
    if (decoration.shape != BoxShape.circle) continue;
    final border = decoration.border;
    if (border is! Border) continue;
    if (border.top.color == Colors.transparent) continue;
    count++;
  }
  return count;
}

void main() {
  group('the date formats VTOP actually sends', () {
    // The scraper hands over the raw cell text, so the separator is not ours.
    // Requiring `/` alone meant every record was thrown away and the card
    // claimed a fully-attended course had no history at all.
    const formats = <String, String>{
      '02/10/2026': 'slash separated',
      '02-10-2026': 'dash separated',
      '02.10.2026': 'dot separated',
      '02 Oct 2026': 'month name',
      '  02/10/2026  ': 'padded with whitespace',
      '02/10/2026 08:00 AM': 'with a trailing time',
      '02-10-2026 (Mon)': 'with a trailing weekday',
    };

    formats.forEach((raw, description) {
      testWidgets('a $description date is understood', (tester) async {
        await host(
          tester,
          AttendanceMonthCard(details: [_record(raw, 'Present')]),
        );
        await tester.pump();

        expect(
          find.text('October 2026'),
          findsOneWidget,
          reason: '"$raw" should resolve to October 2026',
        );
        expect(_visibleRings(tester), 1);
      });
    });

    testWidgets('an unambiguous month-first date is still read correctly', (
      tester,
    ) async {
      // 25 cannot be a month, so this has to be day-first.
      await host(
        tester,
        AttendanceMonthCard(details: [_record('25/10/2026', 'Present')]),
      );
      await tester.pump();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('an ambiguous date is read day-first, as VTOP writes it', (
      tester,
    ) async {
      // 02-03 could be 2 March or 3 February. VTOP is day-first.
      await host(
        tester,
        AttendanceMonthCard(details: [_record('02-03-2026', 'Present')]),
      );
      await tester.pump();

      expect(find.text('March 2026'), findsOneWidget);
    });

    testWidgets('an impossible date is rejected rather than rolled over', (
      tester,
    ) async {
      // 31 February must not silently become 3 March, which would invent an
      // attendance record on a day that never happened.
      await host(
        tester,
        AttendanceMonthCard(details: [_record('31/02/2026', 'Present')]),
      );
      await tester.pump();

      expect(find.textContaining('No day-wise attendance'), findsOneWidget);
    });

    testWidgets('text with no date in it is skipped without crashing', (
      tester,
    ) async {
      await host(
        tester,
        AttendanceMonthCard(
          details: [_record('Not published', 'Present'), _record('05/10/2026', 'Present')],
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_visibleRings(tester), 1);
    });
  });

  group('a full semester of records', () {
    // The card renders one grid per month. Single-month tests never exercised
    // that path, and the device showed a bare ErrorWidget where the grid should
    // be.
    testWidgets('shows one month at a time with a working slider', (
      tester,
    ) async {
      // Listing every grid pushed the summary off the page; the card now
      // slides between months.
      final records = <AttendanceDetail>[];
      for (var month = 7; month <= 10; month++) {
        for (var day = 2; day <= 28; day += 5) {
          records.add(
            _record(
              '${day.toString().padLeft(2, '0')}/$month/2026',
              day.isEven ? 'Present' : 'Absent',
            ),
          );
        }
      }

      await host(tester, AttendanceMonthCard(details: records));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Only the month being shown has a title.
      final titles = <String>[
        'July 2026',
        'August 2026',
        'September 2026',
        'October 2026',
      ].where((title) => find.text(title).evaluate().isNotEmpty).length;
      expect(titles, 1, reason: 'exactly one month is on screen');
      // And the position is reported.
      expect(find.textContaining('/4'), findsOneWidget);
    });

    testWidgets('the arrows move between months', (tester) async {
      final records = <AttendanceDetail>[];
      for (var month = 7; month <= 10; month++) {
        for (var day = 2; day <= 28; day += 5) {
          records.add(
            _record(
              '${day.toString().padLeft(2, '0')}/$month/2026',
              day.isEven ? 'Present' : 'Absent',
            ),
          );
        }
      }

      await host(tester, AttendanceMonthCard(details: records));
      await tester.pump();

      // It opens on the current month, which here is the last of the four, so
      // forward is disabled and back is available.
      final opening = _visibleTitle(tester);
      expect(opening, isNotEmpty);

      // Step back through every month; each step must show a different one.
      final seen = <String>{opening};
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.byIcon(Icons.chevron_left).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final title = _visibleTitle(tester);
        expect(title, isNot(seen.last), reason: 'step $step should change month');
        seen.add(title);
      }
      expect(seen, hasLength(4), reason: 'all four months reachable');
      expect(tester.takeException(), isNull);

      // And forward again returns to where it started.
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.byIcon(Icons.chevron_right).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(_visibleTitle(tester), opening);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles a month that starts on the first of the month', (
      tester,
    ) async {
      // A month whose 1st is a Sunday has no leading padding, which is the
      // boundary of the grid arithmetic.
      await host(
        tester,
        AttendanceMonthCard(details: [_record('01/11/2026', 'Present')]),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('handles a month that needs six rows', (tester) async {
      await host(
        tester,
        AttendanceMonthCard(details: [_record('01/08/2026', 'Present')]),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('August 2026'), findsOneWidget);
    });

    testWidgets('handles February in a leap year', (tester) async {
      await host(
        tester,
        AttendanceMonthCard(details: [_record('29/02/2028', 'Present')]),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('February 2028'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
    });

    testWidgets('a day with three records still draws one ring', (tester) async {
      // Lectures plus a lab can post several rows for one date.
      await host(
        tester,
        AttendanceMonthCard(
          details: [
            _record('05/10/2026', 'Present'),
            _record('05/10/2026', 'Absent'),
            _record('05/10/2026', 'Present'),
          ],
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_visibleRings(tester), 1);
    });
  });

  group('opening month', () {
    testWidgets('the grid opens on the month the header names', (tester) async {
      // Aug–Oct 2026, so the header resolves to October (the current month,
      // or the latest one once the semester is over). The slider must be ON
      // that month: it used to park on page 0 — the earliest month — while
      // the header, the "N of M attended" line and the grid height all
      // described October, so the calendar opened showing another month's
      // marks under October's title and only a swipe synced the two.
      final records = <AttendanceDetail>[
        _record('05/08/2026', 'Present'),
        _record('07/08/2026', 'Present'),
        _record('10/08/2026', 'Present'),
        _record('03/09/2026', 'Absent'),
        _record('05/10/2026', 'Present'),
      ];

      await host(tester, AttendanceMonthCard(details: records));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);

      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(controller.hasClients, isTrue);
      expect(
        controller.page,
        2,
        reason: 'the slider must be on October, not the earliest month',
      );

      // The rings on screen must be October's single record, not August's
      // three — this is the data the user actually reads.
      expect(_visibleRings(tester), 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('empty states are distinguishable', () {
    testWidgets('not posted', (tester) async {
      await host(
        tester,
        const AttendanceMonthCard(
          details: [],
          emptyReason: EmptyReason.notPosted,
        ),
      );
      await tester.pump();

      expect(find.text('No day-wise attendance posted yet.'), findsOneWidget);
    });

    testWidgets('failed reads differently from not posted', (tester) async {
      // These were the same string, so a broken fetch was indistinguishable
      // from an empty course - and neither told the user what to do.
      await host(
        tester,
        const AttendanceMonthCard(
          details: [],
          emptyReason: EmptyReason.failed,
        ),
      );
      await tester.pump();

      expect(find.textContaining("Couldn't reach VTOP"), findsOneWidget);
      expect(find.text('No day-wise attendance posted yet.'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('loading shows progress', (tester) async {
      await host(
        tester,
        const AttendanceMonthCard(
          details: [],
          emptyReason: EmptyReason.loading,
        ),
      );
      await tester.pump();

      expect(find.textContaining('Loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('status values from VTOP', () {
    for (final status in ['Present', 'present', 'PRESENT']) {
      testWidgets('"$status" counts as attended', (tester) async {
        await host(
          tester,
          AttendanceMonthCard(details: [_record('05/10/2026', status)]),
        );
        await tester.pump();

        expect(find.textContaining('Attended'), findsOneWidget);
      });
    }

    for (final status in ['Absent', 'absent']) {
      testWidgets('"$status" counts as missed', (tester) async {
        await host(
          tester,
          AttendanceMonthCard(details: [_record('05/10/2026', status)]),
        );
        await tester.pump();

        expect(find.textContaining('Missed'), findsOneWidget);
      });
    }
  });
}
