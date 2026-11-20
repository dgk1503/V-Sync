import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

import '../../helpers/xlsx_builder.dart';

/// Pins down what the reader already does with the layouts the hostels really
/// send, so that widening it to other layouts can never change these.
void main() {
  group("the women's hostel weekly pattern", () {
    // Labels are weekday names, no dates; each meal cell packs its items on
    // separate lines; the same food repeats every week of the month.
    final bytes = buildXlsx({
      'Menu': [
        ['WOMENS HOSTEL MESS MENU FOR THE MONTH OF NOVEMBER'],
        ['Day', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
        [
          'Monday / Friday',
          'Idli\nChutney',
          'Rice\nSambar',
          'Tea',
          'Chapathi\nCurry',
        ],
        ['Tuesday', 'Dosa', 'Pulao\nRaita', 'Tea\nBiscuit', 'Rice\nDal'],
        [
          'Wednesday / Thursday',
          'Upma',
          'Rice\nRasam',
          'Samosa',
          'Pulka\nKurma',
        ],
        ['Saturday / Sunday', 'Poori', 'Biryani', 'Cake', 'Noodles'],
      ],
    });
    final menu = MessMenuService.parseXlsx(bytes);

    int firstDayOn(int weekday) => menu.days.keys.firstWhere(
      (d) => DateTime(menu.year, menu.month, d).weekday == weekday,
    );

    test('is read as the month named in its title', () {
      expect(menu.month, 11);
    });

    test('puts a labelled row on every one of its weekdays', () {
      List<String> breakfastOn(int weekday) =>
          menu.days[firstDayOn(weekday)]!.breakfast;

      expect(breakfastOn(DateTime.monday), ['Idli', 'Chutney']);
      expect(breakfastOn(DateTime.friday), ['Idli', 'Chutney']);
      expect(breakfastOn(DateTime.tuesday), ['Dosa']);
      expect(breakfastOn(DateTime.thursday), ['Upma']);
      expect(breakfastOn(DateTime.sunday), ['Poori']);
    });

    test('splits a packed cell into separate items', () {
      final monday = menu.days[firstDayOn(DateTime.monday)]!;
      expect(monday.lunch, ['Rice', 'Sambar']);
      expect(monday.dinner, ['Chapathi', 'Curry']);
    });

    test('covers every day of the month', () {
      final length = DateTime(menu.year, menu.month + 1, 0).day;
      expect(menu.days.length, length);
      expect(menu.isReadable, isTrue);
    });
  });

  group('the date blocks with merged day labels (the main hostels)', () {
    final menu = MessMenuService.parseXlsx(
      File('test/fixtures/mess-menu-2026-11.xlsx').readAsBytesSync(),
    );

    test('reads both menus, all thirty days', () {
      expect(menu.sheetNames, ['Veg & Non-Veg', 'Special']);
      for (final sheet in menu.sheetNames) {
        expect(menu.daysFor(sheet).length, 30);
      }
    });

    test('a few known dishes land on the right days', () {
      expect(menu.menuFor(1)!.breakfast.first, 'Shavige Bath');
      expect(
        menu.menuFor(15)!.breakfast.first,
        'Shavige Bath',
        reason: 'the 1st, 15th and 29th are all Sundays',
      );
      expect(menu.menuFor(2)!.breakfast.first, 'Ghee + Veg Pongal');
    });
  });

  group('the date blocks without merged cells', () {
    // The same shape with the merges taken away: the label sits on the first row
    // of a block and a blank row ends it.
    final menu = MessMenuService.parseXlsx(
      buildXlsx({
        'Menu': [
          ['MESS MENU FOR THE MONTH OF NOVEMBER'],
          ['Day', 'Breakfast', 'Lunch', 'Snacks', 'Dinner'],
          ['Mon\n2, 9', 'Idli', 'Rice', 'Tea', 'Roti'],
          ['', 'Chutney', 'Dal', '', 'Curry'],
          [],
          ['Tue\n3, 10', 'Dosa', 'Pulao', 'Tea', 'Rice'],
          ['', 'Sambar', 'Raita', '', 'Dal'],
        ],
      }),
    );

    test('assigns each block to the dates in its label', () {
      expect(menu.menuFor(2)!.breakfast, ['Idli', 'Chutney']);
      expect(menu.menuFor(9)!.breakfast, ['Idli', 'Chutney']);
      expect(menu.menuFor(3)!.breakfast, ['Dosa', 'Sambar']);
      expect(menu.menuFor(10)!.dinner, ['Rice', 'Dal']);
      expect(menu.menuFor(4), isNull);
    });
  });
}
