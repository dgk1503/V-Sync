import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';

PlannedCourse course(int id, double credits, PlannerGrade grade) =>
    PlannedCourse(id: id, credits: credits, grade: grade);

void main() {
  group('projecting a semester', () {
    test(
      'worked example: 8.00 over 40 credits, then 20 credits of straight A',
      () {
        final result = GpaPlanner.project(
          cgpa: 8.0,
          creditsDone: 40,
          courses: [
            course(1, 4, PlannerGrade.a),
            course(2, 4, PlannerGrade.a),
            course(3, 4, PlannerGrade.a),
            course(4, 4, PlannerGrade.a),
            course(5, 4, PlannerGrade.a),
          ],
        );

        // (8*40 + 20*9) / 60 = 500/60
        expect(result.semesterCredits, 20);
        expect(result.semesterGpa, 9.0);
        expect(result.newCgpa, closeTo(8.3333, 0.0001));
        expect(result.change, closeTo(0.3333, 0.0001));
      },
    );

    test('credits weight the grades, so a heavy course matters more', () {
      final result = GpaPlanner.project(
        cgpa: 0,
        creditsDone: 0,
        courses: [course(1, 4, PlannerGrade.s), course(2, 1, PlannerGrade.f)],
      );

      // (4*10 + 1*0) / 5
      expect(result.semesterGpa, 8.0);
      expect(result.newCgpa, 8.0);
    });

    test('an F costs credits without earning points', () {
      final result = GpaPlanner.project(
        cgpa: 9.0,
        creditsDone: 30,
        courses: [course(1, 3, PlannerGrade.f)],
      );

      // (9*30 + 0) / 33
      expect(result.newCgpa, closeTo(8.1818, 0.0001));
      expect(result.change, lessThan(0));
    });

    test('no courses changes nothing and never divides by zero', () {
      final result = GpaPlanner.project(
        cgpa: 8.2,
        creditsDone: 40,
        courses: const [],
      );
      expect(result.semesterCredits, 0);
      expect(result.semesterGpa, 0);
      expect(result.newCgpa, closeTo(8.2, 1e-9));
      expect(result.change, closeTo(0, 1e-9));
    });

    test('a student with no history starts from the semester alone', () {
      final result = GpaPlanner.project(
        cgpa: 0,
        creditsDone: 0,
        courses: [course(1, 3, PlannerGrade.b)],
      );
      expect(result.newCgpa, 8.0);
    });
  });

  group('reaching a target', () {
    test('says what the semester must average', () {
      final goal = GpaPlanner.goal(
        cgpa: 8.0,
        creditsDone: 40,
        semesterCredits: 20,
        target: 8.5,
      )!;

      // (8.5*60 - 8*40) / 20 = 9.5
      expect(goal.required, closeTo(9.5, 1e-9));
      expect(goal.reachable, isTrue);
      expect(goal.gradeNeeded, PlannerGrade.s);
    });

    test('a target that needs more than a perfect semester is unreachable', () {
      final goal = GpaPlanner.goal(
        cgpa: 7.0,
        creditsDone: 100,
        semesterCredits: 20,
        target: 9.0,
      )!;

      expect(goal.reachable, isFalse);
      expect(goal.gradeNeeded, isNull);
      // The most it could be is (7*100 + 20*10)/120.
      expect(goal.best, closeTo(7.5, 1e-9));
    });

    test('a target already comfortably met needs nothing', () {
      final goal = GpaPlanner.goal(
        cgpa: 9.5,
        creditsDone: 100,
        semesterCredits: 20,
        target: 6.0,
      )!;

      expect(goal.alreadyThere, isTrue);
      expect(goal.gradeNeeded, isNull);
    });

    test('maps the required average to the lowest letter that reaches it', () {
      expect(PlannerGrade.atLeast(8.5), PlannerGrade.a);
      expect(PlannerGrade.atLeast(8.0), PlannerGrade.b);
      expect(PlannerGrade.atLeast(9.01), PlannerGrade.s);
      expect(PlannerGrade.atLeast(10.5), isNull);
    });

    test('with no credits there is nothing to plan', () {
      expect(
        GpaPlanner.goal(
          cgpa: 8,
          creditsDone: 40,
          semesterCredits: 0,
          target: 9,
        ),
        isNull,
      );
    });
  });

  group('semester courses from the timetable', () {
    Day slot(String code, String type, String? credits, {String? name}) => Day(
      courseCode: code,
      courseName: name ?? 'Course $code',
      courseType: type,
      credits: credits,
    );

    Timetable week({List<Day> mon = const [], List<Day> fri = const []}) =>
        Timetable(
          monday: ToMany<Day>()..addAll(mon),
          tuesday: ToMany<Day>(),
          wednesday: ToMany<Day>(),
          thursday: ToMany<Day>(),
          friday: ToMany<Day>()..addAll(fri),
          saturday: ToMany<Day>(),
          sunday: ToMany<Day>(),
        );

    test('a theory part and a lab part add up to one course', () {
      final courses = SemesterCourses.from(
        week(
          mon: [slot('CSE4007', 'ETH', '3.0'), slot('CSE4007', 'ELA', '1.0')],
        ),
      );

      expect(courses, hasLength(1));
      expect(courses.single.code, 'CSE4007');
      expect(courses.single.credits, 4.0);
    });

    test('a course that meets on several days is counted once', () {
      final courses = SemesterCourses.from(
        week(
          mon: [slot('MAT1007', 'ETH', '3.0')],
          fri: [slot('MAT1007', 'ETH', '3.0'), slot('MAT1007', 'ETH', '3.0')],
        ),
      );

      expect(courses.single.credits, 3.0);
    });

    test('an unknown part makes the whole course unknown, not understated', () {
      final courses = SemesterCourses.from(
        week(
          mon: [slot('CSE4007', 'ETH', '3.0'), slot('CSE4007', 'ELA', null)],
        ),
      );

      expect(courses.single.credits, isNull);
    });

    test('a timetable saved before credits were read gives no credits', () {
      final courses = SemesterCourses.from(
        week(mon: [slot('MAT1007', 'ETH', null)]),
      );

      expect(courses.single.credits, isNull);
      expect(courses.single.name, 'Course MAT1007');
    });

    test(
      'courses come out in code order and an empty timetable gives none',
      () {
        final courses = SemesterCourses.from(
          week(mon: [slot('SWE2001', 'ETH', '3'), slot('MAT1007', 'ETH', '4')]),
        );

        expect(courses.map((c) => c.code), ['MAT1007', 'SWE2001']);
        expect(SemesterCourses.from(null), isEmpty);
      },
    );
  });

  group('semester courses from VTOP\'s course table', () {
    // One entry per part, as the scraper sends the table.
    Map<String, Object?> row(
      String code,
      String kind,
      String credits, {
      String name = '',
      String typeCode = 'UNK',
    }) => {
      'course_code': code,
      'course_name': name.isEmpty ? 'Course $code' : name,
      'course_type': kind,
      'type_code': typeCode,
      'credits': credits,
    };

    Timetable withTable(List<Map<String, Object?>> rows, {List<Day>? mon}) =>
        Timetable(
          monday: ToMany<Day>()..addAll(mon ?? const []),
          tuesday: ToMany<Day>(),
          wednesday: ToMany<Day>(),
          thursday: ToMany<Day>(),
          friday: ToMany<Day>(),
          saturday: ToMany<Day>(),
          sunday: ToMany<Day>(),
          courseTable: jsonEncode(rows),
        );

    test('a course that never meets is still a course (a project)', () {
      final courses = SemesterCourses.from(
        withTable([
          row('CSE4007', 'Embedded Theory', '3.0'),
          row('CSE4099', 'Project', '10.0', name: 'Capstone'),
        ]),
      );

      // Nothing in the weekly grid for the capstone, yet it is listed.
      expect(courses.map((c) => c.code), ['CSE4007', 'CSE4099']);
      expect(courses.last.credits, 10.0);
      expect(courses.last.name, 'Capstone');
    });

    test('parts add up and each part counts once', () {
      final courses = SemesterCourses.from(
        withTable([
          row('CSE4007', 'Embedded Theory', '3.0'),
          row('CSE4007', 'Embedded Lab', '1.0'),
          row('CSE4007', 'Embedded Lab', '1.0'), // a repeated row
        ]),
      );

      expect(courses.single.credits, 4.0);
    });

    test('a theory part and a project part of one course are both counted', () {
      // Collapsing every non-lab part into one used to drop the second.
      final courses = SemesterCourses.from(
        withTable([
          row('CSE2001', 'Embedded Theory', '3.0'),
          row('CSE2001', 'Embedded Project', '2.0'),
        ]),
      );

      expect(courses.single.credits, 5.0);
    });

    test('fractional credits stay fractional', () {
      final courses = SemesterCourses.from(
        withTable([row('HUM1001', 'Soft Skill', '1.5')]),
      );

      expect(courses.single.credits, 1.5);
    });

    test('a course of zero credits cannot move a GPA, so it is left out', () {
      final courses = SemesterCourses.from(
        withTable([
          row('ENG1002', 'Theory Only', '0.0'),
          row('MAT1001', 'Theory Only', '4.0'),
        ]),
      );

      expect(courses.map((c) => c.code), ['MAT1001']);
    });

    test('a part with no credits makes the course unknown, never a guess', () {
      final courses = SemesterCourses.from(
        withTable([
          row('CSE4007', 'Embedded Theory', '3.0'),
          row('CSE4007', 'Embedded Lab', ''),
        ]),
      );

      expect(courses.single.credits, isNull);
    });

    test('credits are read however the page words them', () {
      final courses = SemesterCourses.from(
        withTable([
          row('A1', 'Theory Only', '2,5'),
          row('B1', 'Theory Only', '4 credits'),
        ]),
      );

      expect(courses.map((c) => c.credits), [2.5, 4.0]);
    });

    test('the table wins over the weekly grid', () {
      final courses = SemesterCourses.from(
        withTable(
          [row('CSE4007', 'Embedded Theory', '3.0')],
          mon: [
            Day(courseCode: 'CSE4007', courseType: 'ETH', credits: '9.0'),
            Day(courseCode: 'JUNK1000', courseType: 'TH', credits: '9.0'),
          ],
        ),
      );

      expect(courses.map((c) => c.code), ['CSE4007']);
      expect(courses.single.credits, 3.0);
    });

    test('a timetable with the table is complete; one without it is not', () {
      expect(
        SemesterCourses.isComplete(withTable([row('A1', 'Theory Only', '3')])),
        isTrue,
      );
      expect(SemesterCourses.isComplete(withTable(const [])), isFalse);
      expect(SemesterCourses.isComplete(null), isFalse);
    });

    test('the table survives a round trip through the scraper JSON', () {
      final json = {
        'Monday': <Object?>[],
        'Tuesday': <Object?>[],
        'Wednesday': <Object?>[],
        'Thursday': <Object?>[],
        'Friday': <Object?>[],
        'Saturday': <Object?>[],
        'Sunday': <Object?>[],
        'courses': [row('CSE4099', 'Project', '10.0')],
      };
      final timetable = Timetable.fromJson(json);

      expect(timetable.courses.single.code, 'CSE4099');
      expect(timetable.courses.single.credits, '10.0');
      expect(Timetable.fromJson(timetable.toJson()).courses, hasLength(1));
    });

    test('an old scraper reply without the table still loads', () {
      final timetable = Timetable.fromJson({
        'Monday': <Object?>[],
        'Tuesday': <Object?>[],
        'Wednesday': <Object?>[],
        'Thursday': <Object?>[],
        'Friday': <Object?>[],
        'Saturday': <Object?>[],
        'Sunday': <Object?>[],
      });

      expect(timetable.courses, isEmpty);
      expect(timetable.courseTable, isNull);
    });
  });

  group('the weekly grid (a timetable saved before the table was read)', () {
    Timetable gridOnly(List<Day> mon) => Timetable(
      monday: ToMany<Day>()..addAll(mon),
      tuesday: ToMany<Day>(),
      wednesday: ToMany<Day>(),
      thursday: ToMany<Day>(),
      friday: ToMany<Day>(),
      saturday: ToMany<Day>(),
      sunday: ToMany<Day>(),
    );

    test('a theory and a project part of one course are both counted', () {
      final courses = SemesterCourses.from(
        gridOnly([
          Day(courseCode: 'CSE2001', courseType: 'ETH', credits: '3.0'),
          Day(courseCode: 'CSE2001', courseType: 'PJT', credits: '2.0'),
        ]),
      );

      expect(courses.single.credits, 5.0);
    });

    test('a zero-credit course is left out here too', () {
      final courses = SemesterCourses.from(
        gridOnly([
          Day(courseCode: 'ENG1002', courseType: 'TH', credits: '0.0'),
        ]),
      );

      expect(courses, isEmpty);
    });
  });

  group('the suggested grade', () {
    test('is the lowest letter that still reaches the target', () {
      final goal = GpaPlanner.goal(
        cgpa: 8.0,
        creditsDone: 40,
        semesterCredits: 20,
        target: 8.3,
      )!;

      // (8.3*60 - 8*40) / 20 = 8.9 -> an A (9) is the lowest letter that gets it.
      expect(goal.required, closeTo(8.9, 1e-9));
      expect(goal.suggested, PlannerGrade.a);
    });

    test('is an S when the target cannot be reached', () {
      final goal = GpaPlanner.goal(
        cgpa: 7.0,
        creditsDone: 100,
        semesterCredits: 20,
        target: 9.0,
      )!;

      expect(goal.suggested, PlannerGrade.s);
    });

    test('is a plain A when the target is already safe', () {
      final goal = GpaPlanner.goal(
        cgpa: 9.5,
        creditsDone: 100,
        semesterCredits: 20,
        target: 6.0,
      )!;

      expect(goal.suggested, PlannerGrade.a);
    });

    test('fractional credits are handled', () {
      final result = GpaPlanner.project(
        cgpa: 8.0,
        creditsDone: 40,
        courses: [
          const PlannedCourse(id: 1, credits: 1.5, grade: PlannerGrade.s),
          const PlannedCourse(id: 2, credits: 2.5, grade: PlannerGrade.b),
        ],
      );

      expect(result.semesterCredits, 4.0);
      expect(result.semesterGpa, closeTo((15 + 20) / 4, 1e-9));
    });
  });
}
