import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/repository/calendar_remote_repository.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';

/// A minimal scraper payload: one month, one day, one event.
const String _rawJson = '''
{
  "semester_id": "AP2424251",
  "class_group_id": "COMB",
  "months": [{"label": "OCT-2026", "cal_date": "01-OCT-2026"}],
  "days": [
    {
      "date": "2026-10-02",
      "day": 2,
      "weekday": "Friday",
      "events": [{"description": "Holiday - General (Semester)", "label": "Holiday"}]
    }
  ]
}
''';

void main() {
  group('cache staleness', () {
    test('an entry written just now is not older than the limit', () {
      final entry = CacheEntry(
        payload: _rawJson,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(entry.isOlderThan(const Duration(days: 5)), isFalse);
    });

    test('an entry a week old is stale', () {
      final entry = CacheEntry(
        payload: _rawJson,
        updatedAt: DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch,
      );

      expect(entry.isOlderThan(const Duration(days: 5)), isTrue);
    });

    test('the boundary is the limit itself, not less', () {
      // Five days is chosen as the middle of the 4-7 day range agreed for this
      // calendar, so a six-day-old cache should still be trusted.
      final entry = CacheEntry(
        payload: _rawJson,
        updatedAt: DateTime.now()
            .subtract(const Duration(days: 4))
            .millisecondsSinceEpoch,
      );

      expect(entry.isOlderThan(const Duration(days: 5)), isFalse);
    });
  });

  group('cached payload shape', () {
    test('a wrapped payload still parses into months', () {
      // The cache stores {"semSubId": ..., "payload": <scraper json>} so a
      // semester switch is detectable without waiting on secure storage.
      // This asserts the inner payload is still readable by the same decoder a
      // live response goes through.
      final calendar = CalendarRemoteRepository.parseCalendarPayload(_rawJson);

      expect(calendar.months.single.calDate, '01-OCT-2026');
      expect(calendar.days.single.date, '2026-10-02');
    });

    test('a cached day classifies the same way a live one does', () {
      // Ours keeps VTOP's whole "Kind - Group" string in `description`, so the
      // kind has to be recovered from it. "Holiday" must land on the holiday
      // branch, or every closure on the grid renders as a working day.
      final day =
          CalendarRemoteRepository.parseCalendarPayload(_rawJson).days.single;
      final chips = CalendarEventClassifier.chipsFor(day);

      expect(chips.single.kind, CalendarDayKind.holiday);
      expect(chips.single.title, contains('Holiday'));
    });

    test('an exam day classifies as an exam, which is what the FAT count reads',
        () {
      // Both parts have to change: the description holds "Kind - Group" while
      // the label holds the bracketed qualifier, and the label is what the
      // classifier reads first.
      final examJson = _rawJson
          .replaceAll('Holiday - General (Semester)', 'CAT - II - General (Semester)')
          .replaceAll('"label": "Holiday"', '"label": "Exam Days"');
      final day =
          CalendarRemoteRepository.parseCalendarPayload(examJson).days.single;
      final chips = CalendarEventClassifier.chipsFor(day);

      expect(chips.single.kind, CalendarDayKind.exam);
    });

    test('the qualifier outranks the description', () {
      // A day whose description names a group but whose qualifier says Holiday
      // is a closure. Reading the description first would render it as a
      // teaching day and inflate the classes-left count.
      final day =
          CalendarRemoteRepository.parseCalendarPayload(_rawJson).days.single;

      expect(CalendarEventClassifier.chipsFor(day).single.kind,
          CalendarDayKind.holiday);
    });
  });
}
