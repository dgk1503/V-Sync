import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

import '../../helpers/xlsx_builder.dart';

/// The reader has to cope with workbooks nobody has sent yet. These are the
/// shapes a hand-made sheet is likely to take.
void main() {
  group("the workbook the hostel sent for November ('Final Mess Menu')", () {
    final menu = MessMenuService.parseXlsx(
      File('test/fixtures/mess-menu-final-2026-11.xlsx').readAsBytesSync(),
    );

    test('has both menus, every day', () {
      expect(menu.sheetNames, ['Veg & Non-Veg', 'Special']);
      for (final sheet in menu.sheetNames) {
        expect(menu.daysFor(sheet).length, 30, reason: sheet);
      }
      expect(menu.month, 11);
      expect(menu.isReadable, isTrue);
    });

    test(
      'has the sheet typos put right (24th is a Tuesday, 25th a Wednesday)',
      () {
        expect(menu.menuFor(24)!.breakfast, menu.menuFor(10)!.breakfast);
        expect(menu.menuFor(25)!.breakfast, menu.menuFor(11)!.breakfast);
        expect(menu.menuFor(26)!.breakfast, menu.menuFor(12)!.breakfast);
      },
    );

    test('keeps the special menu\'s own dishes', () {
      expect(
        menu.menuFor(1, sheet: 'Special')!.breakfast,
        contains('Cornflakes'),
      );
    });
  });

  group('headings worded differently', () {
    // The same dated blocks, but the headings are not the plain words.
    final menu = MessMenuService.parseXlsx(
      buildXlsx(
        {
          'Menu': [
            ['MESS MENU FOR THE MONTH OF NOVEMBER'],
            [
              'DAY',
              'BREAKFAST (7:30 AM - 9:00 AM)',
              'LUNCH ',
              'Evening Snacks',
              'Dinner / Supper',
            ],
            ['Mon\n2, 9', 'Idli', 'Rice', 'Tea', 'Roti'],
            ['', 'Chutney', 'Dal', '', 'Curry'],
            ['Tue\n3, 10', 'Dosa', 'Pulao', 'Tea', 'Rice'],
            ['', 'Sambar', 'Raita', '', 'Dal'],
          ],
        },
        merges: {
          'Menu': ['A3:A4', 'A5:A6'],
        },
      ),
    );

    test('are recognised', () {
      expect(menu.menuFor(2)!.breakfast, ['Idli', 'Chutney']);
      expect(menu.menuFor(9)!.lunch, ['Rice', 'Dal']);
      expect(menu.menuFor(3)!.snacks, ['Tea']);
      expect(menu.menuFor(10)!.dinner, ['Rice', 'Dal']);
    });
  });

  group('one row per day', () {
    List<List<String>> month(
      List<String> labels, {
      String title = 'MESS MENU FOR THE MONTH OF NOVEMBER',
    }) => [
      [title],
      ['Date', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
      for (var i = 0; i < labels.length; i++)
        [
          labels[i],
          'Idli\nChutney ${i + 1}',
          'Rice\nDal',
          'Tea',
          'Roti\nCurry',
        ],
    ];

    test('with plain day numbers', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': month([for (var d = 1; d <= 30; d++) '$d']),
        }),
      );

      expect(menu.days.length, 30);
      expect(menu.menuFor(7)!.breakfast, ['Idli', 'Chutney 7']);
      expect(menu.menuFor(30)!.dinner, ['Roti', 'Curry']);
      expect(menu.isReadable, isTrue);
    });

    test('with full dates, in the order day-month-year', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': month([
            for (var d = 1; d <= 30; d++)
              '${d.toString().padLeft(2, '0')}-11-2026',
          ], title: 'MESS MENU'),
        }),
      );

      expect(menu.month, 11);
      expect(menu.year, 2026);
      expect(menu.menuFor(12)!.breakfast.last, 'Chutney 12');
    });

    test('with a month name', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': month([
            for (var d = 1; d <= 30; d++) '$d Nov',
          ], title: 'MENU'),
        }),
      );

      expect(menu.month, 11);
      expect(menu.days.length, 30);
    });

    test('with Excel date cells, which arrive as serial numbers', () {
      // 46327 is 1 November 2026.
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': month([
            for (var d = 0; d < 30; d++) '${46327 + d}',
          ], title: 'MENU'),
        }),
      );

      expect(menu.month, 11);
      expect(menu.year, 2026);
      expect(menu.menuFor(1)!.breakfast, ['Idli', 'Chutney 1']);
      expect(menu.menuFor(30)!.breakfast, ['Idli', 'Chutney 30']);
    });

    test('with the weekday beside the day', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': month([
            for (var d = 1; d <= 30; d++)
              '${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][DateTime(2026, 11, d).weekday % 7]} $d',
          ]),
        }),
      );

      expect(menu.year, 2026);
      expect(menu.days.length, 30);
    });

    test('a sheet with blocks is not mistaken for one row per day', () {
      // Only the first row of each block carries its label.
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': [
            ['MESS MENU FOR THE MONTH OF NOVEMBER'],
            ['Day', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
            for (final (label, rows) in [
              ('Mon\n2, 9, 16, 23, 30', 4),
              ('Tue\n3, 10, 17, 24', 4),
              ('Wed\n4, 11, 18, 25', 4),
            ]) ...[
              [label, 'Idli $label', 'Rice', 'Tea', 'Roti'],
              for (var i = 1; i < rows; i++)
                ['', 'Item $i', 'Dal', '', 'Curry'],
              <String>[],
            ],
          ],
        }),
      );

      expect(menu.menuFor(2)!.breakfast.length, 4);
      expect(menu.menuFor(3)!.breakfast.length, 4);
    });
  });

  group('days across the top, meals down the side', () {
    test('with day numbers', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': [
            ['MESS MENU FOR THE MONTH OF NOVEMBER'],
            ['Meal', for (var d = 1; d <= 30; d++) '$d'],
            ['Breakfast', for (var d = 1; d <= 30; d++) 'Idli\nChutney $d'],
            ['Lunch', for (var d = 1; d <= 30; d++) 'Rice\nDal'],
            ['Snacks', for (var d = 1; d <= 30; d++) 'Tea'],
            ['Dinner', for (var d = 1; d <= 30; d++) 'Roti\nCurry'],
          ],
        }),
      );

      expect(menu.days.length, 30);
      expect(menu.menuFor(9)!.breakfast, ['Idli', 'Chutney 9']);
      expect(menu.menuFor(9)!.dinner, ['Roti', 'Curry']);
    });

    test('with weekday names, a pattern that repeats', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': [
            ['WEEKLY MENU FOR THE MONTH OF NOVEMBER'],
            [
              '',
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ],
            [
              'Breakfast',
              'Idli',
              'Dosa',
              'Upma',
              'Poori',
              'Vada',
              'Pongal',
              'Bath',
            ],
            [
              'Lunch',
              'Rice',
              'Rice',
              'Rice',
              'Rice',
              'Rice',
              'Biryani',
              'Biryani',
            ],
            [
              'Dinner',
              'Roti',
              'Roti',
              'Roti',
              'Roti',
              'Roti',
              'Noodles',
              'Roti',
            ],
          ],
        }),
      );

      int firstOn(int weekday) => menu.days.keys.firstWhere(
        (d) => DateTime(menu.year, menu.month, d).weekday == weekday,
      );
      expect(menu.days[firstOn(DateTime.monday)]!.breakfast, ['Idli']);
      expect(menu.days[firstOn(DateTime.saturday)]!.lunch, ['Biryani']);
      expect(menu.days.length, DateTime(menu.year, menu.month + 1, 0).day);
    });

    test('with a meal that spans several rows', () {
      final menu = MessMenuService.parseXlsx(
        buildXlsx({
          'Menu': [
            ['MENU FOR THE MONTH OF NOVEMBER'],
            ['Meal', for (var d = 1; d <= 7; d++) '$d'],
            ['Breakfast', for (var d = 1; d <= 7; d++) 'Idli'],
            ['', for (var d = 1; d <= 7; d++) 'Chutney'],
            ['Lunch', for (var d = 1; d <= 7; d++) 'Rice'],
            ['', for (var d = 1; d <= 7; d++) 'Dal'],
            ['Dinner', for (var d = 1; d <= 7; d++) 'Roti'],
          ],
        }),
      );

      expect(menu.menuFor(3)!.breakfast, ['Idli', 'Chutney']);
      expect(menu.menuFor(3)!.lunch, ['Rice', 'Dal']);
    });
  });

  group('what it refuses', () {
    test('a spreadsheet that is not a mess menu is not read as one', () {
      expect(
        () => MessMenuService.parseXlsx(
          buildXlsx({
            'Sheet1': [
              ['Name', 'Marks'],
              ['A', '90'],
              ['B', '80'],
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test('a heading that only mentions a meal is not a heading', () {
      expect(MessMenuService.mealOf('Breakfast'), 'breakfast');
      expect(MessMenuService.mealOf('Evening Snacks'), 'snacks');
      expect(MessMenuService.mealOf('Dinner / Supper'), 'dinner');
      expect(
        MessMenuService.mealOf(
          'Breakfast, lunch and dinner are served at the times below',
        ),
        isNull,
      );
      expect(MessMenuService.mealOf('Day'), isNull);
    });
  });

  group('reading a day label', () {
    test('plain, ordinal and with a weekday', () {
      expect(MessMenuService.dayOf('7')!.day, 7);
      expect(MessMenuService.dayOf('3rd')!.day, 3);
      expect(MessMenuService.dayOf('Mon 3')!.day, 3);
      expect(MessMenuService.dayOf('Mon 3')!.weekday, DateTime.monday);
    });

    test('dates with a month', () {
      final a = MessMenuService.dayOf('01-11-2026')!;
      expect((a.day, a.month, a.year), (1, 11, 2026));
      final b = MessMenuService.dayOf('15 Nov')!;
      expect((b.day, b.month), (15, 11));
      final c = MessMenuService.dayOf('Nov 4')!;
      expect((c.day, c.month), (4, 11));
    });

    test('an Excel serial date', () {
      final d = MessMenuService.dayOf('46327')!;
      expect((d.day, d.month, d.year), (1, 11, 2026));
    });

    test('things that are not a day', () {
      expect(MessMenuService.dayOf(''), isNull);
      expect(MessMenuService.dayOf('Monday / Friday'), isNull);
      expect(MessMenuService.dayOf('Day'), isNull);
      expect(MessMenuService.dayOf('45'), isNull);
      expect(
        MessMenuService.dayOf('Mon\n2, 9'),
        isNull,
        reason: 'a block label lists several days',
      );
    });
  });
}
