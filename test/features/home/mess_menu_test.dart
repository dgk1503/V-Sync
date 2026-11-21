import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

MessDayMenu full() => const MessDayMenu(
  breakfast: ['Idli'],
  lunch: ['Rice'],
  snacks: ['Tea'],
  dinner: ['Chapati'],
);

MessMenu menu({
  int month = 11,
  int year = 2026,
  required Map<int, MessDayMenu> days,
}) => MessMenu(monthName: 'November', month: month, year: year, days: days);

Map<int, MessDayMenu> month(int count, MessDayMenu Function(int) make) => {
  for (var d = 1; d <= count; d++) d: make(d),
};

void main() {
  group('a parsed menu is only trusted when it looks like a month', () {
    test('a full month of meals is readable', () {
      expect(menu(days: month(30, (_) => full())).isReadable, isTrue);
    });

    test('a handful of days is not a monthly menu', () {
      expect(menu(days: month(4, (_) => full())).isReadable, isFalse);
    });

    test('a grid with most meals empty is not trusted', () {
      final days = month(
        30,
        (d) => d <= 5 ? full() : const MessDayMenu(breakfast: ['Idli']),
      );
      expect(menu(days: days).isReadable, isFalse);
    });

    test('a few gaps are tolerated', () {
      final days = month(
        30,
        (d) => d <= 6 ? const MessDayMenu(breakfast: ['Idli']) : full(),
      );
      // 24 of 30 complete = 80%.
      expect(menu(days: days).isReadable, isTrue);
    });

    test('no days at all is not readable', () {
      expect(menu(days: const {}).isReadable, isFalse);
    });
  });

  group('when a menu has ended', () {
    final m = menu(month: 10, year: 2026, days: month(31, (_) => full()));

    test('not during its own month', () {
      expect(m.hasEnded(DateTime(2026, 10, 31)), isFalse);
    });

    test('the day the next month starts', () {
      expect(m.hasEnded(DateTime(2026, 11, 1)), isTrue);
    });

    test('across a year boundary', () {
      final dec = menu(month: 12, year: 2026, days: const {});
      expect(dec.hasEnded(DateTime(2026, 12, 31)), isFalse);
      expect(dec.hasEnded(DateTime(2027, 1, 1)), isTrue);
    });
  });

  group('which year a menu belongs to', () {
    test('this month is this year', () {
      expect(MessMenuService.yearFor(11, DateTime(2026, 11, 12)), 2026);
    });

    test('last month, uploaded late, is still this year and so is over', () {
      expect(MessMenuService.yearFor(10, DateTime(2026, 11, 12)), 2026);
    });

    test('January read in December is next year', () {
      expect(MessMenuService.yearFor(1, DateTime(2026, 12, 20)), 2027);
    });

    test('December read in January is last year', () {
      expect(MessMenuService.yearFor(12, DateTime(2027, 1, 3)), 2026);
    });
  });

  group('a document added in an earlier month is stale', () {
    MessSource added(DateTime at) => MessSource(
      path: 'x',
      name: 'menu.xlsx',
      importedAt: at,
      readable: false,
    );

    test('same month is fine', () {
      expect(
        added(DateTime(2026, 11, 2)).isFromEarlierMonth(DateTime(2026, 11, 30)),
        isFalse,
      );
    });

    test('an earlier month is stale', () {
      expect(
        added(DateTime(2026, 10, 28)).isFromEarlierMonth(DateTime(2026, 11, 1)),
        isTrue,
      );
    });

    test('survives a round trip through storage', () {
      final source = added(DateTime(2026, 11, 2, 9, 30));
      final back = MessSource.fromJson(source.toJson());
      expect(back.name, source.name);
      expect(back.importedAt, source.importedAt);
      expect(back.readable, isFalse);
    });
  });
}
