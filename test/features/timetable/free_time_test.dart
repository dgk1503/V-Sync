import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/features/timetable/model/free_time.dart';

Day cls(String start, String end) =>
    Day(courseName: 'x', startTime: start, endTime: end);

void main() {
  test('the ten minute changeover is not free time', () {
    final gaps = FreeTime.before([
      cls('08:00', '08:50'),
      cls('09:00', '09:50'),
    ]);

    expect(gaps, [null, null]);
  });

  test('a longer gap is, with its length and where it begins', () {
    final gaps = FreeTime.before([
      cls('14:00', '14:50'),
      cls('16:00', '16:50'),
    ]);

    expect(gaps[0], isNull);
    expect(gaps[1]!.minutes, 70);
    expect(gaps[1]!.startsAt, 14 * 60 + 50);
    expect(gaps[1]!.label, 'Free for 1 hr 10 min');
  });

  test('eleven minutes is the first length that counts', () {
    expect(
      FreeTime.before([
        cls('08:00', '08:50'),
        cls('09:01', '09:50'),
      ])[1]?.minutes,
      11,
    );
    expect(
      FreeTime.before([cls('08:00', '08:50'), cls('09:00', '09:50')])[1],
      isNull,
    );
  });

  test('a stretch of classes with one gap in it', () {
    final gaps = FreeTime.before([
      cls('14:00', '14:50'),
      cls('15:00', '15:50'),
      cls('17:00', '17:50'),
      cls('18:00', '18:50'),
    ]);

    expect(gaps.map((g) => g?.minutes), [null, null, 70, null]);
  });

  test('a long class that runs past the next start leaves no gap', () {
    // The first runs to 11:30, so the one starting 10:00 does not make a gap
    // before the one at 11:40, which is only the ordinary changeover.
    final gaps = FreeTime.before([
      cls('08:00', '11:30'),
      cls('10:00', '10:50'),
      cls('11:40', '12:30'),
    ]);

    expect(gaps, [null, null, null]);
  });

  test('back to back classes and an unreadable time never invent a gap', () {
    expect(
      FreeTime.before([
        cls('08:00', '08:50'),
        Day(courseName: 'x'),
        cls('09:00', '09:50'),
      ]),
      [null, null, null],
    );
    expect(FreeTime.before(const []), isEmpty);
  });

  test('durations read the way a person says them', () {
    expect(formatFreeDuration(40), '40 min');
    expect(formatFreeDuration(60), '1 hr');
    expect(formatFreeDuration(65), '1 hr 5 min');
    expect(formatFreeDuration(120), '2 hr');
    expect(formatFreeDuration(190), '3 hr 10 min');
  });
}
