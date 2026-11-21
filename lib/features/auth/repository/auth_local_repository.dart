import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/core/models/semester_cache.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';
import 'package:vit_ap_student_app/objectbox.g.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

part 'auth_local_repository.g.dart';

@riverpod
AuthLocalRepository authLocalRepository(Ref ref) {
  final store = serviceLocator<Store>();
  return AuthLocalRepository(store);
}

class AuthLocalRepository {
  final Store store;
  late final Box<SemesterCache> _semesterBox;

  AuthLocalRepository(this.store) {
    _semesterBox = store.box<SemesterCache>();
  }

  /// Builds the rows to store for a fresh list of semesters.
  ///
  /// The semester the student picked is recorded on its row, so replacing the
  /// rows must carry that choice over. It used to be dropped: the cache was
  /// emptied and refilled with every row unselected, so refreshing the list from
  /// VTOP (which opening the semester picker does) quietly forgot which semester
  /// was in use. Settings then read "Select semester", and anything keyed to the
  /// selected semester, the calendar included, lost it too.
  ///
  /// A selected semester that VTOP no longer lists is not carried over.
  static List<SemesterCache> rowsFor(
    List<SemesterInfo> semesters, {
    required String? selectedId,
    required int updatedAt,
  }) => [
    for (final semester in semesters)
      SemesterCache(
        semesterId: semester.id,
        semesterName: semester.name,
        isSelected: semester.id == selectedId,
        updatedAt: updatedAt,
      ),
  ];

  /// Save or update list of semesters
  Future<Either<Failure, void>> saveSemesters(
    List<SemesterInfo> semesters,
  ) async {
    try {
      final query = _semesterBox
          .query(SemesterCache_.isSelected.equals(true))
          .build();
      final selectedId = query.findFirst()?.semesterId;
      query.close();

      final semesterCaches = rowsFor(
        semesters,
        selectedId: selectedId,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Clear existing semesters and insert new ones
      _semesterBox.removeAll();
      _semesterBox.putMany(semesterCaches);

      return const Right(null);
    } catch (e) {
      return Left(Failure('Failed to save semesters: ${e.toString()}'));
    }
  }

  /// Picks [semesterId] as the selected semester when none is selected.
  ///
  /// For a selection that an earlier build erased: the login still carries the
  /// semester the app has been using, so that is the right answer, and asking the
  /// student to choose again would be asking them something the app knows. Does
  /// nothing when a semester is already selected, or when [semesterId] is not in
  /// the cache. Returns the selected semester afterwards, if any.
  SemesterInfo? healSelection(String? semesterId) {
    final selectedQuery = _semesterBox
        .query(SemesterCache_.isSelected.equals(true))
        .build();
    final selected = selectedQuery.findFirst();
    selectedQuery.close();
    if (selected != null) {
      return SemesterInfo(id: selected.semesterId, name: selected.semesterName);
    }
    if (semesterId == null || semesterId.isEmpty) return null;

    final matchQuery = _semesterBox
        .query(SemesterCache_.semesterId.equals(semesterId))
        .build();
    final match = matchQuery.findFirst();
    matchQuery.close();
    if (match == null) return null;

    _semesterBox.put(match.copyWith(isSelected: true));
    return SemesterInfo(id: match.semesterId, name: match.semesterName);
  }

  /// Get all cached semesters
  Future<Either<Failure, List<SemesterInfo>>> getSemesters() async {
    try {
      final semesterCaches = _semesterBox.getAll();

      if (semesterCaches.isEmpty) {
        return Left(Failure('No cached semesters found'));
      }

      final semesters = semesterCaches
          .map(
            (cache) =>
                SemesterInfo(id: cache.semesterId, name: cache.semesterName),
          )
          .toList();

      return Right(semesters);
    } catch (e) {
      return Left(Failure('Failed to retrieve semesters: ${e.toString()}'));
    }
  }

  /// Update selected semester
  Future<Either<Failure, void>> setSelectedSemester(String semesterId) async {
    try {
      // First, unmark all semesters
      final allSemesters = _semesterBox.getAll();
      for (var semester in allSemesters) {
        if (semester.isSelected) {
          final updated = semester.copyWith(isSelected: false);
          _semesterBox.put(updated);
        }
      }

      // Then mark the selected one
      final query = _semesterBox
          .query(SemesterCache_.semesterId.equals(semesterId))
          .build();
      final selectedSemester = query.findFirst();
      query.close();

      if (selectedSemester != null) {
        final updated = selectedSemester.copyWith(isSelected: true);
        _semesterBox.put(updated);
      }

      return const Right(null);
    } catch (e) {
      return Left(
        Failure('Failed to update selected semester: ${e.toString()}'),
      );
    }
  }

  /// Get the currently selected semester
  Future<Either<Failure, SemesterInfo?>> getSelectedSemester() async {
    try {
      final query = _semesterBox
          .query(SemesterCache_.isSelected.equals(true))
          .build();
      final selected = query.findFirst();
      query.close();

      if (selected == null) {
        return const Right(null);
      }

      return Right(
        SemesterInfo(id: selected.semesterId, name: selected.semesterName),
      );
    } catch (e) {
      return Left(
        Failure('Failed to retrieve selected semester: ${e.toString()}'),
      );
    }
  }

  /// Clear all cached semesters
  Future<Either<Failure, void>> clearSemesters() async {
    try {
      _semesterBox.removeAll();
      return const Right(null);
    } catch (e) {
      return Left(Failure('Failed to clear semesters: ${e.toString()}'));
    }
  }

  /// Check if semesters are cached
  bool hasCachedSemesters() {
    return _semesterBox.count() > 0;
  }

  /// Get cache timestamp (when semesters were last updated)
  Future<Either<Failure, DateTime?>> getCacheTimestamp() async {
    try {
      final semesters = _semesterBox.getAll();
      if (semesters.isEmpty) {
        return const Right(null);
      }

      final timestamp = semesters.first.updatedAt;
      return Right(DateTime.fromMillisecondsSinceEpoch(timestamp));
    } catch (e) {
      return Left(Failure('Failed to get cache timestamp: ${e.toString()}'));
    }
  }
}
