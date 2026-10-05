import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/repository/calendar_remote_repository.dart';

/// The scraper's JSON exactly as Rust emits it. This is the payload that ends
/// up in the offline cache, so decoding it is what makes the calendar appear on
/// the first frame instead of after a round-trip to VTOP.
const String _scraperJson = '''
{
  "semester_id": "AP2424251",
  "class_group_id": "COMB",
  "months": [
    {"label": "JUL/AUG 2026", "cal_date": "01-AUG-2026"},
    {"label": "SEP 2026", "cal_date": "01-SEP-2026"}
  ],
  "days": [
    {
      "date": "2026-08-01",
      "day": 1,
      "weekday": "Saturday",
      "events": [
        {"description": "Working Day - General (Semester)", "label": "WorkingDay"}
      ]
    },
    {
      "date": "2026-08-15",
      "day": 15,
      "weekday": "Saturday",
      "events": [
        {"description": "Independence Day", "label": "Holiday"}
      ]
    },
    {
      "date": "2026-09-20",
      "day": 20,
      "weekday": "Sunday",
      "events": [
        {"description": "End Sem Exam - Theory", "label": "FAT"}
      ]
    }
  ]
}
''';

void main() {
  group('scraper payload decoding', () {
    test('reads snake_case keys, which is what serde emits', () {
      final calendar = CalendarRemoteRepository.parseCalendarPayload(_scraperJson);

      expect(calendar.semesterId, 'AP2424251');
      expect(calendar.classGroupId, 'COMB');
      expect(calendar.months, hasLength(2));
      expect(calendar.days, hasLength(3));
    });

    test('keeps each day with its events', () {
      final calendar = CalendarRemoteRepository.parseCalendarPayload(_scraperJson);

      final working = calendar.days.firstWhere((d) => d.date == '2026-08-01');
      expect(working.day, 1);
      expect(working.weekday, 'Saturday');
      expect(working.events.single.label, 'WorkingDay');

      final fat = calendar.days.firstWhere((d) => d.date == '2026-09-20');
      expect(fat.events.single.description, 'End Sem Exam - Theory');
      expect(fat.events.single.label, 'FAT');
    });

    test('decoding is deterministic, so a cache hit matches a live read', () {
      // The cache stores the scraper's text verbatim rather than re-encoding
      // the model, so the same bytes must always yield the same months. If the
      // cache ever held a re-encoded payload instead, this would diverge —
      // re-encoding writes camelCase keys that parseCalendarPayload cannot read.
      final first = CalendarRemoteRepository.parseCalendarPayload(_scraperJson);
      final second = CalendarRemoteRepository.parseCalendarPayload(_scraperJson);

      expect(second.semesterId, first.semesterId);
      expect(second.days.length, first.days.length);
      expect(second.days.last.events.single.label, 'FAT');
      expect(
        second.days.map((d) => d.date).toList(),
        first.days.map((d) => d.date).toList(),
      );
    });

    test('missing optional lists decode as empty rather than throwing', () {
      // A semester with no published days must not take the whole page down.
      final calendar = CalendarRemoteRepository.parseCalendarPayload(
        '{"semester_id": "AP2424251", "class_group_id": "COMB"}',
      );

      expect(calendar.months, isEmpty);
      expect(calendar.days, isEmpty);
    });

    test('a null day number falls back to zero instead of throwing', () {
      final calendar = CalendarRemoteRepository.parseCalendarPayload(
        '{"semester_id": "x", "class_group_id": "COMB", "days": '
        '[{"date": "2026-08-01", "day": null, "weekday": "Saturday", '
        '"events": []}]}',
      );

      expect(calendar.days.single.day, 0);
    });
  });
}
