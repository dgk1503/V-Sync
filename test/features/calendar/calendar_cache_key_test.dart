import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';

void main() {
  group('cache key', () {
    // The key used to be a single constant, so switching semesters kept
    // serving the previous semester's calendar for up to five days.
    test('is namespaced by semester', () {
      expect(CalendarViewmodel.cacheKeyFor('AP2424251'), 'calendar:AP2424251');
      expect(CalendarViewmodel.cacheKeyFor('AP2324150'), 'calendar:AP2324150');
    });

    test('two semesters cannot collide', () {
      expect(
        CalendarViewmodel.cacheKeyFor('SEM1'),
        isNot(CalendarViewmodel.cacheKeyFor('SEM2')),
      );
    });

    test('falls back to the un-keyed key when no semester is known', () {
      // So an install that cached a calendar before this was keyed still has
      // something to show.
      expect(CalendarViewmodel.cacheKeyFor(null), CalendarViewmodel.cacheKey);
      expect(CalendarViewmodel.cacheKeyFor(''), CalendarViewmodel.cacheKey);
    });

    test('the fallback is not a semester key', () {
      expect(
        CalendarViewmodel.cacheKeyFor(null).startsWith('calendar:'),
        isFalse,
        reason: 'otherwise pruning other semesters would delete the fallback',
      );
    });

    test('every semester key shares the prefix, so pruning can find them', () {
      const prefix = 'calendar:';
      expect(CalendarViewmodel.cacheKeyFor('X').startsWith(prefix), isTrue);
      expect(CalendarViewmodel.cacheKeyFor('Y').startsWith(prefix), isTrue);
    });
  });
}
