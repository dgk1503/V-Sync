import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/auth/model/semester_groups.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

SemesterInfo sem(String id, String name) => SemesterInfo(id: id, name: name);

void main() {
  test('groups semesters by academic year, newest year first', () {
    final groups = SemesterGrouping.group([
      sem('1', 'Winter Semester 2024-25'),
      sem('2', 'Fall Semester 2025-26'),
      sem('3', 'Fall Semester 2024-25'),
      sem('4', 'Winter Semester 2025-26'),
    ]);

    expect(groups.map((g) => g.label), ['2025-26', '2024-25']);
    expect(groups[0].entries.map((e) => e.info.id), ['2', '4']);
    expect(groups[1].entries.map((e) => e.info.id), ['1', '3']);
  });

  test('keeps the order VTOP gave inside a year', () {
    final groups = SemesterGrouping.group([
      sem('b', 'Winter Semester 2025-26'),
      sem('a', 'Fall Semester 2025-26'),
    ]);

    expect(groups.single.entries.map((e) => e.info.id), ['b', 'a']);
  });

  test('takes the year out of the name shown under its heading', () {
    final groups = SemesterGrouping.group([
      sem('1', 'Fall Semester 2025-26'),
      sem('2', 'Summer Semester 2025 - 26 - Freshers'),
    ]);

    expect(groups.single.entries[0].shortName, 'Fall Semester');
    expect(groups.single.entries[1].shortName, 'Summer Semester - Freshers');
  });

  test('reads the other ways a span is written', () {
    final groups = SemesterGrouping.group([
      sem('1', 'Fall 2025–2026'),
      sem('2', 'Winter 2025/26'),
    ]);

    expect(groups.single.label, '2025-26');
    expect(groups.single.entries.map((e) => e.shortName), ['Fall', 'Winter']);
  });

  test('a lone year still groups', () {
    final groups = SemesterGrouping.group([sem('1', 'Fall 2023')]);

    expect(groups.single.label, '2023');
    expect(groups.single.entries.single.shortName, 'Fall');
  });

  test('a name with no year is kept, under Other, last', () {
    final groups = SemesterGrouping.group([
      sem('1', 'Special Semester'),
      sem('2', 'Fall Semester 2025-26'),
    ]);

    expect(groups.map((g) => g.label), ['2025-26', 'Other']);
    expect(groups.last.entries.single.shortName, 'Special Semester');
  });

  test('a name that is only a year is not reduced to nothing', () {
    final groups = SemesterGrouping.group([sem('1', '2025-26')]);

    expect(groups.single.entries.single.shortName, '2025-26');
  });

  test('knows which year holds a semester', () {
    final groups = SemesterGrouping.group([
      sem('1', 'Fall Semester 2024-25'),
      sem('2', 'Fall Semester 2025-26'),
    ]);

    expect(groups[0].contains('2'), isTrue);
    expect(groups[0].contains('1'), isFalse);
    expect(groups[0].contains(null), isFalse);
  });

  test('an empty list gives no groups', () {
    expect(SemesterGrouping.group(const []), isEmpty);
  });
}
