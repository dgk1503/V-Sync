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

    test('exactly at the threshold reports "Don\'t skip", not a skip count', () {
      // 3/4 = 75% precisely.
      const standing = AttendanceStanding(attended: 3, total: 4);
      expect(standing.percent, 75.0);
      expect(standing.isSafe, isTrue);
      expect(standing.canSkip, 0);
      expect(standing.advice, "Don't skip");
    });

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
        final afterOneMore = (standing.attended / (standing.total + k + 1)) *
            100;
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
}