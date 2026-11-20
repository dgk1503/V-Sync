import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_standing.dart';

void main() {
  group('AttendanceStanding', () {
    test('reproduces the guidance shown on the reference cards', () {
      // 25/29 = 86.2% -> displayed as 86% in the mock, "Can skip 4".
      expect(
        const AttendanceStanding(attended: 25, total: 29).advice,
        'Can skip 4',
      );
      // 23/30 = 76.7% -> displayed as 77%, right on the threshold.
      expect(
        const AttendanceStanding(attended: 23, total: 30).advice,
        "Don't skip",
      );
      // 12/17 = 70.6% -> displayed as 71%, three classes short.
      expect(
        const AttendanceStanding(attended: 12, total: 17).advice,
        'Attend 3',
      );
    });

    test('classifies each advice kind', () {
      expect(
        const AttendanceStanding(attended: 0, total: 0).kind,
        AttendanceAdviceKind.none,
      );
      expect(
        const AttendanceStanding(attended: 25, total: 29).kind,
        AttendanceAdviceKind.canSkip,
      );
      expect(
        const AttendanceStanding(attended: 23, total: 30).kind,
        AttendanceAdviceKind.atEdge,
      );
      expect(
        const AttendanceStanding(attended: 12, total: 17).kind,
        AttendanceAdviceKind.mustAttend,
      );
    });

    test('treats a course with no classes as safe with no advice', () {
      const standing = AttendanceStanding(attended: 0, total: 0);
      expect(standing.isSafe, isTrue);
      expect(standing.canSkip, 0);
      expect(standing.mustAttend, 0);
      expect(standing.advice, 'No classes yet');
    });

    test(
      'exactly at the threshold reports "Don\'t skip", not a skip count',
      () {
        // 3/4 = 75% precisely.
        const standing = AttendanceStanding(attended: 3, total: 4);
        expect(standing.percent, 75.0);
        expect(standing.isSafe, isTrue);
        expect(standing.canSkip, 0);
        expect(standing.advice, "Don't skip");
      },
    );

    test('just below the threshold must be attended', () {
      // 74/99 = 74.7% -> one class short of recovery.
      const standing = AttendanceStanding(attended: 74, total: 99);
      expect(standing.isSafe, isFalse);
      expect(standing.mustAttend, 1);
      expect(standing.canSkip, 0);
      expect(standing.advice, 'Attend 1');
    });

    test('canSkip never goes negative below the threshold', () {
      const standing = AttendanceStanding(attended: 1, total: 10);
      expect(standing.canSkip, 0);
      expect(standing.mustAttend, 26);
    });

    test('the advertised skip count really keeps the course legal', () {
      // For a spread of healthy courses, missing exactly canSkip classes must
      // leave the percentage at or above 75%, and one more must break it.
      const cases = [
        AttendanceStanding(attended: 25, total: 29),
        AttendanceStanding(attended: 40, total: 45),
        AttendanceStanding(attended: 60, total: 70),
        AttendanceStanding(attended: 86, total: 100),
        AttendanceStanding(attended: 30, total: 33),
      ];
      for (final standing in cases) {
        final k = standing.canSkip;
        expect(k, greaterThan(0));
        final after = (standing.attended / (standing.total + k)) * 100;
        expect(after, greaterThanOrEqualTo(kAttendanceThreshold));
        final afterOneMore =
            (standing.attended / (standing.total + k + 1)) * 100;
        expect(afterOneMore, lessThan(kAttendanceThreshold));
      }
    });

    test('the mustAttend count really recovers the course', () {
      const cases = [
        AttendanceStanding(attended: 12, total: 17),
        AttendanceStanding(attended: 74, total: 99),
        AttendanceStanding(attended: 5, total: 9),
        AttendanceStanding(attended: 1, total: 10),
      ];
      for (final standing in cases) {
        final n = standing.mustAttend;
        expect(n, greaterThan(0));
        final after = (standing.attended + n) / (standing.total + n) * 100;
        expect(after, greaterThanOrEqualTo(kAttendanceThreshold));
      }
    });
  });

  group('labs are advised in whole labs, two periods each', () {
    test('rounds spare periods down to whole labs', () {
      // 4a - 3t = 4*30 - 3*36 = 12 -> 4 spare periods -> 2 labs.
      expect(
        const AttendanceStanding(attended: 30, total: 36, isLab: true).advice,
        'Can skip 2 labs',
      );
      // 4*26 - 3*32 = 8 -> 2 spare periods -> 1 lab, singular.
      expect(
        const AttendanceStanding(attended: 26, total: 32, isLab: true).advice,
        'Can skip 1 lab',
      );
    });

    test('one spare period is not enough to miss a lab', () {
      // 4*19 - 3*24 = 4 -> 1 spare period -> 0 labs -> do not skip.
      const standing = AttendanceStanding(attended: 19, total: 24, isLab: true);
      expect(standing.canSkip, 1);
      expect(standing.advice, "Don't skip");
    });

    test('rounds the periods needed up to whole labs', () {
      // 3*20 - 4*14 = 4 periods -> 2 labs. 3*17 - 4*12 = 3 -> 2 labs.
      expect(
        const AttendanceStanding(attended: 14, total: 20, isLab: true).advice,
        'Attend 2 labs',
      );
      expect(
        const AttendanceStanding(attended: 12, total: 17, isLab: true).advice,
        'Attend 2 labs',
      );
      // 3*7 - 4*5 = 1 period -> 1 lab, singular.
      expect(
        const AttendanceStanding(attended: 5, total: 7, isLab: true).advice,
        'Attend 1 lab',
      );
    });

    test('theory is unchanged', () {
      expect(
        const AttendanceStanding(attended: 25, total: 29).advice,
        'Can skip 4',
      );
    });
  });

  group('the percentage reads the way VTOP shows it', () {
    test('rounds up: the examples VTOP itself gives', () {
      expect(vtopPercent(31, 34), 92); // 91.2%
      expect(vtopPercent(35, 41), 86); // 85.4%
    });

    test('exact values stay exact', () {
      expect(vtopPercent(3, 4), 75);
      expect(vtopPercent(30, 30), 100);
      expect(vtopPercent(0, 10), 0);
    });

    test('no classes is zero, not a crash', () {
      expect(vtopPercent(0, 0), 0);
    });

    test(
      'a figure just under 75 reads 75 but is still below the threshold',
      () {
        // 74.5% shows as 75, yet the standing is decided on the exact counts.
        expect(vtopPercent(149, 200), 75);
        expect(
          const AttendanceStanding(attended: 149, total: 200).isSafe,
          isFalse,
        );
      },
    );
  });
}
