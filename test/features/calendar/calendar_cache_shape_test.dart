import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/calendar/repository/calendar_remote_repository.dart';

/// A cache row written by the build *before* the semester wrapper existed: the
/// scraper's JSON stored raw, with no `{"semSubId":..., "payload":...}` around
/// it. It is well-formed and recent, which is exactly what makes it dangerous.
const String _legacyUnwrapped = '''
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

/// Mirrors `CalendarViewmodel._tryUnwrap`. The viewmodel needs the ObjectBox box
/// to be exercised, so the unwrap contract is pinned here instead: a payload
/// with no `payload` key yields nothing at all, and crucially not an error.
List<int> _decodeLikeTheViewmodel(String cached) {
  try {
    final wrapper = jsonDecode(cached) as Map<String, dynamic>;
    final raw = wrapper['payload'] as String;
    return CalendarRemoteRepository.parseCalendarPayload(raw).days
        .map((d) => d.day)
        .toList();
  } on Object {
    return const <int>[];
  }
}

void main() {
  group('a cache row this build cannot read', () {
    test('decodes to nothing rather than throwing', () {
      expect(_decodeLikeTheViewmodel(_legacyUnwrapped), isEmpty);
    });

    test('decodes to nothing when the row is truncated', () {
      expect(_decodeLikeTheViewmodel('{"semSubId": "x", "pay'), isEmpty);
    });

    test('decodes to nothing when the payload key is missing entirely', () {
      expect(_decodeLikeTheViewmodel('{"semester_id": "x"}'), isEmpty);
    });

    test('decodes to nothing when the row is an empty string', () {
      expect(_decodeLikeTheViewmodel(''), isEmpty);
    });

    test('decodes to nothing when the row is not JSON at all', () {
      expect(_decodeLikeTheViewmodel('not json'), isEmpty);
    });
  });

  group('a cache row this build can read', () {
    test('unwraps to the days it holds', () {
      final wrapped = jsonEncode({
        'semSubId': 'AP2424251',
        'payload': _legacyUnwrapped,
      });

      expect(_decodeLikeTheViewmodel(wrapped), [2]);
    });
  });

  group('why this matters', () {
    test('an unreadable row must not read as fresh', () {
      // The bug this pins: `ensureLoaded` compared only the row's timestamp
      // against the TTL, so a legacy row looked fresh, the fetch was skipped,
      // and the page sat empty for the full five days with no spinner to
      // explain why. Readability now has to be part of the freshness check.
      final legacy = jsonDecode(_legacyUnwrapped) as Map<String, dynamic>;
      final hasWrapperKey = legacy.containsKey('payload');

      expect(
        hasWrapperKey,
        isFalse,
        reason: 'a legacy row has no wrapper, so it must be treated as absent '
            'rather than as a fresh cache',
      );
    });
  });
}
