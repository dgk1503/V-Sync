import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

/// Reads a real VIT-AP monthly workbook: two sheets, "Veg & Non-Veg" and
/// "Special", with the weekday blocks the hostels publish. It also carries two
/// slips from the people who typed it, "Tue 10, 25" and "Wed 11, 26", which the
/// calendar contradicts (25 and 26 November 2026 are a Wednesday and a Thursday).
void main() {
  final bytes = File('test/fixtures/mess-menu-2026-11.xlsx').readAsBytesSync();
  final menu = MessMenuService.parseXlsx(bytes);

  group('the workbook', () {
    test('is November 2026', () {
      expect(menu.month, 11);
      expect(menu.year, 2026);
    });

    test('keeps every menu sheet, the first as the main one', () {
      expect(menu.sheetNames, ['Veg & Non-Veg', 'Special']);
      expect(menu.sheetName, 'Veg & Non-Veg');
      expect(menu.extraSheets.single.name, 'Special');
    });

    test('reads all thirty days of both menus', () {
      for (final sheet in menu.sheetNames) {
        final days = menu.daysFor(sheet);
        expect(
          [
            for (var d = 1; d <= 30; d++)
              if (days[d] == null) d,
          ],
          isEmpty,
          reason: '$sheet has no menu for those days',
        );
      }
    });

    test('is readable as a month', () {
      expect(menu.isReadable, isTrue);
    });
  });

  group('the special menu is its own menu', () {
    test('has items the regular one does not', () {
      // Sunday 1 Nov: the special menu lists Cornflakes at breakfast.
      expect(
        menu.menuFor(1, sheet: 'Special')!.breakfast,
        contains('Cornflakes'),
      );
      expect(menu.menuFor(1)!.breakfast, isNot(contains('Cornflakes')));
    });

    test('an unknown sheet name falls back to the first', () {
      expect(menu.daysFor('Gone'), same(menu.days));
      expect(menu.daysFor(null), same(menu.days));
    });
  });

  group('typing slips in the sheet', () {
    test('the 24th, a Tuesday, gets Tuesday\'s menu', () {
      expect(menu.menuFor(24), isNotNull);
      expect(
        menu.menuFor(24)!.breakfast,
        menu.menuFor(10)!.breakfast,
        reason: '10 and 24 are both Tuesdays',
      );
      // The sheet alternates some dishes by week: 10 and 24 are weeks 2 and 4.
      expect(menu.menuFor(24)!.dinner, menu.menuFor(10)!.dinner);
    });

    test('the 25th, a Wednesday, is not given Tuesday\'s menu', () {
      expect(menu.menuFor(25)!.breakfast, isNot(menu.menuFor(10)!.breakfast));
      expect(
        menu.menuFor(25)!.breakfast,
        menu.menuFor(11)!.breakfast,
        reason: '11 and 25 are both Wednesdays',
      );
    });

    test('the 26th stays Thursday\'s', () {
      expect(menu.menuFor(26)!.breakfast, menu.menuFor(12)!.breakfast);
    });
  });

  group('repairing a block\'s dates', () {
    List<int> repair(int weekday, List<int> numbers) =>
        MessMenuService.repairDates(
          weekday: weekday,
          numbers: numbers,
          year: 2026,
          month: 11,
        );

    test('leaves dates that are right alone', () {
      expect(repair(DateTime.tuesday, [3, 17]), [3, 17]);
    });

    test('moves a date to the nearest day of that weekday', () {
      expect(repair(DateTime.tuesday, [10, 25]), [10, 24]);
      expect(repair(DateTime.wednesday, [11, 26]), [11, 25]);
    });

    test('does not move it onto a day the block already lists', () {
      // 24 is taken by the valid entry, so the stray 25 has nowhere to go but 17,
      // which is more than three days away: it is dropped, not guessed.
      expect(repair(DateTime.tuesday, [24, 25]), [24]);
    });

    test('drops dates outside the month, and keeps order', () {
      expect(repair(DateTime.sunday, [29, 1, 15, 40]), [1, 15, 29]);
    });

    test('with no weekday to check against, it only keeps real dates', () {
      expect(
        MessMenuService.repairDates(
          weekday: null,
          numbers: [3, 31, 45],
          year: 2026,
          month: 11,
        ),
        [3],
      );
    });
  });

  group('which year a sheet was written for', () {
    test('is the one whose calendar matches the weekday labels', () {
      // "Tue 3, 17" only fits November 2026 (not 2025 or 2027).
      final blocks = [
        (weekday: DateTime.tuesday, numbers: [3, 17]),
        (weekday: DateTime.sunday, numbers: [1, 15, 29]),
      ];
      expect(MessMenuService.bestYear(11, blocks, 2025), 2026);
      expect(MessMenuService.bestYear(11, blocks, 2027), 2026);
    });

    test('keeps the preferred year when nothing says otherwise', () {
      expect(MessMenuService.bestYear(11, const [], 2026), 2026);
    });
  });

  group('storage', () {
    test('survives a round trip with its sheets', () {
      final back = MessMenu.fromJson(menu.toJson());

      expect(back.sheetNames, menu.sheetNames);
      expect(
        back.menuFor(1, sheet: 'Special')!.breakfast,
        contains('Cornflakes'),
      );
      expect(back.menuFor(24)!.breakfast, menu.menuFor(24)!.breakfast);
    });

    test('a menu saved before sheets were kept still loads', () {
      final old = menu.toJson()
        ..remove('sheetName')
        ..remove('extraSheets');

      final back = MessMenu.fromJson(old);

      expect(back.extraSheets, isEmpty);
      expect(back.sheetNames, ['Menu']);
      expect(back.menuFor(1), isNotNull);
    });
  });

  test('weekday labels are read from the first word', () {
    expect(MessMenuService.weekdayOfLabel('Tue\n10, 24'), DateTime.tuesday);
    expect(
      MessMenuService.weekdayOfLabel('Wed      4, 18'),
      DateTime.wednesday,
    );
    expect(MessMenuService.weekdayOfLabel('10, 24'), isNull);
  });
}
