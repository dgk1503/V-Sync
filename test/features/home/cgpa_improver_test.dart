import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/grade_history.dart';
import 'package:vit_ap_student_app/features/home/model/cgpa_improver.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';

Course row(
  String code,
  String grade,
  double credits,
  String month, {
  String title = '',
}) => Course(
  courseCode: code,
  courseTitle: title.isEmpty ? 'Course $code' : title,
  courseType: 'ETL',
  credits: credits.toStringAsFixed(1),
  grade: grade,
  examMonth: month,
  courseDistribution: 'UC',
);

GradeHistory history(List<Course> courses, {String cgpa = '9.00'}) =>
    GradeHistory(
      creditsRegistered: '0',
      creditsEarned: '0',
      cgpa: cgpa,
      courses: ToMany<Course>(items: courses),
    );

void main() {
  group('the sessions', () {
    test(
      'are grouped by exam month, oldest first, however VTOP ordered them',
      () {
        final sessions = CgpaImprover.sessions(
          history([
            row('B1', 'A', 4, 'Jun-2026'),
            row('A1', 'S', 4, 'Jan-2026'),
            row('A2', 'A', 3, 'Jan-2026'),
          ]),
        );

        expect(sessions.map((s) => s.label), ['Jan 2026', 'Jun 2026']);
        expect(sessions.first.courses.map((c) => c.code), ['A1', 'A2']);
      },
    );

    test('a month that does not read as one keeps VTOP\'s own wording', () {
      final sessions = CgpaImprover.sessions(
        history([row('A1', 'A', 4, 'Summer'), row('A2', 'A', 4, 'Jan-2026')]),
      );

      expect(sessions.map((s) => s.label), ['Jan 2026', 'Summer']);
    });
  });

  group('one session\'s GPA', () {
    final session = CgpaImprover.sessions(
      history([
        row('A1', 'A', 4, 'Jan-2026'),
        row('A2', 'A', 4, 'Jan-2026'),
        row('A3', 'S', 3, 'Jan-2026'),
      ]),
    ).single;

    test('is the credit-weighted average, and the picks move it', () {
      final none = CgpaImprover.session(session, const {});
      // (4*9 + 4*9 + 3*10) / 11
      expect(none.now, closeTo(9.2727, 0.0001));
      expect(none.after, closeTo(none.now!, 1e-9));
      expect(none.credits, 11);

      final a1 = session.courses.first.key;
      final better = CgpaImprover.session(session, {a1: PlannerGrade.s});
      // (4*10 + 4*9 + 3*10) / 11
      expect(better.after, closeTo(9.6364, 0.0001));
      expect(better.change, closeTo(0.3636, 0.0001));

      final a3 = session.courses.last.key;
      final worse = CgpaImprover.session(session, {a3: PlannerGrade.a});
      // (4*9 + 4*9 + 3*9) / 11
      expect(worse.after, closeTo(9.0, 1e-9));
      expect(worse.change! < 0, isTrue);
    });
  });

  group('the CGPA', () {
    final h = history([
      row('A1', 'A', 4, 'Jan-2026'),
      row('A2', 'B', 4, 'Jan-2026'),
      row('B1', 'S', 4, 'Jun-2026'),
    ], cgpa: '9.00');
    final sessions = CgpaImprover.sessions(h);
    final a2 = sessions.first.courses.last.key;

    test(
      'starts at VTOP\'s own number and moves by what the pick is worth',
      () {
        // (36 + 32 + 40) / 12 = 9.00 matches VTOP; B to A is +4 points over 12.
        final out = CgpaImprover.cgpa(
          vtopCgpa: 9.0,
          sessions: sessions,
          picks: {a2: PlannerGrade.a},
        );

        expect(out.now, 9.0);
        expect(out.after, closeTo(9.3333, 0.0001));
        expect(out.change, closeTo(0.3333, 0.0001));
        expect(out.matchesVtop, isTrue);
      },
    );

    test('with nothing tried there is no change', () {
      final out = CgpaImprover.cgpa(
        vtopCgpa: 9.0,
        sessions: sessions,
        picks: const {},
      );

      expect(out.change, closeTo(0, 1e-9));
    });

    test('when VTOP counts differently the size of the change is kept', () {
      final out = CgpaImprover.cgpa(
        vtopCgpa: 8.8, // not what the list adds up to
        sessions: sessions,
        picks: {a2: PlannerGrade.a},
      );

      expect(out.matchesVtop, isFalse);
      expect(out.change, closeTo(0.3333, 0.0001));
      expect(out.after, closeTo(9.1333, 0.0001));
    });

    test('can never go past 10', () {
      final out = CgpaImprover.cgpa(
        vtopCgpa: 9.95,
        sessions: sessions,
        picks: {
          a2: PlannerGrade.s,
          sessions.first.courses.first.key: PlannerGrade.s,
        },
      );

      expect(out.after, lessThanOrEqualTo(10.0));
    });
  });

  group('courses that cannot be tried', () {
    test('pass/fail and no-grade courses carry no points and no dropdown', () {
      final sessions = CgpaImprover.sessions(
        history([
          row('A1', 'A', 4, 'Jan-2026'),
          row('NC1', 'P', 2, 'Jan-2026'),
          row('NC2', 'N', 3, 'Jan-2026'),
        ]),
      );
      final courses = sessions.single.courses;

      expect(courses.map((c) => c.canChange), [true, false, false]);
      final out = CgpaImprover.session(sessions.single, const {});
      expect(out.credits, 4, reason: 'only the graded course counts');
      expect(out.now, 9.0);
    });

    test('a course with no credits does not count', () {
      final sessions = CgpaImprover.sessions(
        history([row('A1', 'A', 4, 'Jan-2026'), row('Z0', 'S', 0, 'Jan-2026')]),
      );

      expect(sessions.single.courses.last.canChange, isFalse);
      expect(CgpaImprover.session(sessions.single, const {}).credits, 4);
    });

    test('a pick on a course that cannot change is ignored', () {
      final sessions = CgpaImprover.sessions(
        history([
          row('A1', 'A', 4, 'Jan-2026'),
          row('NC1', 'P', 2, 'Jan-2026'),
        ]),
      );
      final p = sessions.single.courses.last.key;

      final out = CgpaImprover.session(sessions.single, {p: PlannerGrade.s});
      expect(out.after, out.now);
    });

    test('an earlier attempt of a course taken again no longer counts', () {
      final sessions = CgpaImprover.sessions(
        history([
          row('M1', 'F', 4, 'Jan-2026'), // failed, taken again below
          row('A1', 'A', 4, 'Jan-2026'),
          row('M1', 'B', 4, 'Jun-2026'),
        ]),
      );
      final first = sessions.first.courses;
      final failed = first.firstWhere((c) => c.code == 'M1');

      expect(failed.superseded, isTrue);
      expect(failed.canChange, isFalse);
      expect(sessions.last.courses.single.superseded, isFalse);

      // The CGPA uses A1 (9) and the new M1 (8): (36 + 32) / 8 = 8.5. The old F
      // is left out of it.
      final out = CgpaImprover.cgpa(
        vtopCgpa: 8.5,
        sessions: sessions,
        picks: const {},
      );
      expect(out.matchesVtop, isTrue);
      // The session that held the F still shows its own GPA, F included.
      expect(
        CgpaImprover.session(sessions.first, const {}).now,
        closeTo(4.5, 1e-9),
      );
    });
  });
}
