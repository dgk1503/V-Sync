import 'package:vit_ap_student_app/core/models/attendance.dart';

/// Minimum attendance percentage VIT requires to sit a class.
const double kAttendanceThreshold = 75.0;

/// The percentage as VTOP shows it: **rounded up** to a whole number.
///
/// 31 of 34 is 91.2% and VTOP shows 92%; 35 of 41 is 85.4% and it shows 86%. A
/// figure worked out by the app has to read the same as the one on VTOP's own
/// card, or the same subject says 91% in one place and 92% in another. Only the
/// number on screen is rounded this way: whether a subject is above 75% is still
/// decided on the exact counts.
int vtopPercent(int attended, int total) =>
    total <= 0 ? 0 : (attended * 100 + total - 1) ~/ total;

/// What a course's standing suggests the student should do next.
enum AttendanceAdviceKind {
  /// No classes have happened yet, so there is nothing to advise.
  none,

  /// At or above the threshold with room to spare: some classes can be missed.
  canSkip,

  /// Exactly at the threshold: safe right now, but not one more miss.
  atEdge,

  /// Below the threshold: these classes must be attended to climb back.
  mustAttend,
}

/// Where a course stands against [kAttendanceThreshold], and the one-line
/// guidance that follows from it.
///
/// The arithmetic is deliberately strict and integer-only, so the advice never
/// depends on floating point rounding. To keep `attended / (total + k)` at or
/// above 75% after missing `k` more classes:
///
/// ```text
/// 100 * attended >= 75 * (total + k)
/// 4 * attended >= 3 * total + 3 * k
/// k <= (4 * attended - 3 * total) / 3
/// ```
///
/// and symmetrically, attending `n` of the remaining classes to recover:
///
/// ```text
/// 4 * attended + 4n >= 3 * total + 3n  ->  n >= 3 * total - 4 * attended
/// ```
///
/// VTOP's own `attendance_percentage` is rounded for display and is therefore
/// not used here; it is kept separate so the number on screen still matches the
/// portal exactly.
class AttendanceStanding {
  const AttendanceStanding({
    required this.attended,
    required this.total,
    this.isLab = false,
  });

  /// Reads the counts VTOP reports on an attendance summary row.
  factory AttendanceStanding.of(Attendance attendance) => AttendanceStanding(
    attended: int.tryParse(attendance.attendedClasses.trim()) ?? 0,
    total: int.tryParse(attendance.totalClasses.trim()) ?? 0,
    isLab: _isLab(attendance),
  );

  final int attended;
  final int total;

  /// Whether this row is a lab. VTOP counts a lab as two periods, so the advice
  /// is given in whole labs: "Can skip 1 lab" is a decision a student can act
  /// on, "Can skip 2" is not.
  final bool isLab;

  /// Periods in one lab session.
  static const int periodsPerLab = 2;

  /// The scraper reports `ELA`/`LO` as the type code and a word such as
  /// "Embedded Lab" as the type.
  static bool _isLab(Attendance attendance) {
    bool looksLab(String value) {
      final text = value.trim().toLowerCase();
      return text == 'ela' || text == 'lo' || text.contains('lab');
    }

    return looksLab(attendance.courseTypeCode) ||
        looksLab(attendance.courseType);
  }

  double get percent => total == 0 ? 0 : attended / total * 100;

  /// Whether the course is currently at or above the threshold. A course with
  /// no classes yet is treated as safe so it does not flash a warning before
  /// the semester has started.
  bool get isSafe => total == 0 || percent >= kAttendanceThreshold;

  /// Classes that can be missed in a row while staying at or above the
  /// threshold. Zero when already below it, since those must be attended.
  int get canSkip {
    if (total == 0) return 0;
    final k = ((4 * attended - 3 * total) / 3).floor();
    return k > 0 ? k : 0;
  }

  /// Consecutive classes needed to climb back to the threshold.
  int get mustAttend {
    final n = 3 * total - 4 * attended;
    return n > 0 ? n : 0;
  }

  /// [canSkip] in the unit the student thinks in: periods for theory, whole
  /// labs for a lab. A single spare period is not enough to miss a lab, so it
  /// rounds down to none.
  int get canSkipUnits => isLab ? canSkip ~/ periodsPerLab : canSkip;

  /// [mustAttend] in the same unit. A lab part-way recovered still has to be
  /// attended, so it rounds up.
  int get mustAttendUnits =>
      isLab ? (mustAttend + periodsPerLab - 1) ~/ periodsPerLab : mustAttend;

  AttendanceAdviceKind get kind {
    if (total == 0) return AttendanceAdviceKind.none;
    if (!isSafe) return AttendanceAdviceKind.mustAttend;
    if (canSkipUnits == 0) return AttendanceAdviceKind.atEdge;
    return AttendanceAdviceKind.canSkip;
  }

  static String _count(int n, bool lab) =>
      lab ? '$n ${n == 1 ? 'lab' : 'labs'}' : '$n';

  /// One-line guidance, e.g. `Can skip 4`, `Don't skip` or `Attend 3`; for a lab, `Can skip 1 lab`
  /// or `Attend 3 labs`.
  String get advice {
    switch (kind) {
      case AttendanceAdviceKind.none:
        return 'No classes yet';
      case AttendanceAdviceKind.mustAttend:
        return 'Attend ${_count(mustAttendUnits, isLab)}';
      case AttendanceAdviceKind.atEdge:
        return "Don't skip";
      case AttendanceAdviceKind.canSkip:
        return 'Can skip ${_count(canSkipUnits, isLab)}';
    }
  }
}
