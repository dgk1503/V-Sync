import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/auth/repository/auth_local_repository.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

void main() {
  const semesters = [
    SemesterInfo(id: 'a', name: 'Fall Semester 2026-27'),
    SemesterInfo(id: 'b', name: 'Winter Semester 2025-26'),
  ];

  test('refreshing the list keeps the semester the student chose', () {
    final rows = AuthLocalRepository.rowsFor(
      semesters,
      selectedId: 'b',
      updatedAt: 1,
    );

    expect(rows.where((r) => r.isSelected).map((r) => r.semesterId), ['b']);
  });

  test('exactly one row is selected, and none when nothing was chosen', () {
    final chosen = AuthLocalRepository.rowsFor(
      semesters,
      selectedId: 'a',
      updatedAt: 1,
    );
    expect(chosen.where((r) => r.isSelected), hasLength(1));

    final none = AuthLocalRepository.rowsFor(
      semesters,
      selectedId: null,
      updatedAt: 1,
    );
    expect(none.where((r) => r.isSelected), isEmpty);
  });

  test('a semester VTOP no longer lists is not carried over', () {
    final rows = AuthLocalRepository.rowsFor(
      semesters,
      selectedId: 'gone',
      updatedAt: 1,
    );

    expect(rows.where((r) => r.isSelected), isEmpty);
  });

  test('names and ids are kept as given', () {
    final rows = AuthLocalRepository.rowsFor(
      semesters,
      selectedId: 'a',
      updatedAt: 7,
    );

    expect(rows.map((r) => r.semesterName), semesters.map((s) => s.name));
    expect(rows.every((r) => r.updatedAt == 7), isTrue);
  });
}
