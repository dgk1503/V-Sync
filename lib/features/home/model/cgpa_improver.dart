import 'package:vit_ap_student_app/core/models/grade_history.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';

/// One graded course in a past session, as the student's grade history has it.
class PastCourse {
  const PastCourse({
    required this.key,
    required this.code,
    required this.title,
    required this.category,
    required this.credits,
    required this.grade,
    required this.gradeValue,
    required this.superseded,
  });

  /// Unique across the whole list, so a pick can be remembered per course.
  final String key;
  final String code;
  final String title;

  /// VTOP's course distribution ("UC", "PC", ...), when it gives one.
  final String category;
  final double credits;

  /// The grade as VTOP wrote it ("A", "P", "N", ...).
  final String grade;

  /// The grade as one VIT awards for points (S to F), or null for anything that
  /// carries no points (P, N, W, blank).
  final PlannerGrade? gradeValue;

  /// An earlier attempt of a course the student took again in a later session:
  /// the later attempt is the one that counts, so this one does not move the
  /// CGPA.
  final bool superseded;

  /// Whether a different grade can be tried on this course: it has points and
  /// credits, and it still counts.
  bool get canChange => gradeValue != null && credits > 0 && !superseded;

  /// Whether this course adds to a session's GPA at all.
  bool get hasPoints => gradeValue != null && credits > 0;
}

/// The courses graded in one exam month: what the student thinks of as a
/// semester.
class PastSession {
  const PastSession({
    required this.label,
    required this.month,
    required this.courses,
  });

  /// "Jan 2026".
  final String label;

  /// For ordering; null when the month could not be read.
  final DateTime? month;
  final List<PastCourse> courses;
}

/// A session's GPA before and after the grades tried on it.
class SessionOutcome {
  const SessionOutcome({
    required this.credits,
    required this.now,
    required this.after,
  });

  /// Credits the GPA counts; 0 when the session has none that carry points.
  final double credits;

  /// Null when [credits] is 0.
  final double? now;
  final double? after;

  double? get change => (now == null || after == null) ? null : after! - now!;
}

/// The CGPA before and after the grades tried.
class CgpaOutcome {
  const CgpaOutcome({
    required this.now,
    required this.after,
    required this.matchesVtop,
  });

  /// VTOP's own CGPA.
  final double now;

  /// [now] moved by what the tried grades change.
  final double after;

  /// Whether the CGPA worked out from the course list agrees with VTOP's own, to
  /// the second decimal. When it does not (VTOP counts something the list does
  /// not show), [after] is still right as a change, but not as an exact figure.
  final bool matchesVtop;

  double get change => after - now;
}

/// What-if grades for the sessions already completed: try a better (or worse)
/// grade on any course and see what it does to that session's GPA and to the
/// CGPA.
///
/// Pure on purpose, like the planner: it reads only what it is handed.
///
/// The CGPA is anchored to the number VTOP itself reports. The course list is
/// only used to work out how much a change moves it, so a difference in how VTOP
/// counts (a repeated course, a pass/fail grade) shifts the starting point, never
/// the size of the change.
class CgpaImprover {
  const CgpaImprover._();

  /// The grade history as sessions, oldest first.
  static List<PastSession> sessions(GradeHistory history) {
    // Parse every row once, with its month.
    final rows = <({Course course, DateTime? month, int index})>[];
    var i = 0;
    for (final c in history.courses) {
      rows.add((course: c, month: _month(c.examMonth), index: i++));
    }

    // A course taken again: only its latest attempt counts.
    final latestMonthOf = <String, DateTime>{};
    for (final r in rows) {
      final code = r.course.courseCode.trim().toUpperCase();
      final month = r.month;
      if (code.isEmpty || month == null) continue;
      final seen = latestMonthOf[code];
      if (seen == null || month.isAfter(seen)) latestMonthOf[code] = month;
    }

    final byLabel = <String, List<PastCourse>>{};
    final monthOfLabel = <String, DateTime?>{};
    for (final r in rows) {
      final c = r.course;
      final code = c.courseCode.trim().toUpperCase();
      final label = _label(c.examMonth);
      final latest = latestMonthOf[code];
      final superseded =
          latest != null && r.month != null && r.month!.isBefore(latest);
      (byLabel[label] ??= []).add(
        PastCourse(
          key: '$code|${c.examMonth.trim()}|${r.index}',
          code: code,
          title: c.courseTitle.trim(),
          category: c.courseDistribution.trim(),
          credits: _credits(c.credits),
          grade: c.grade.trim().toUpperCase(),
          gradeValue: _gradeOf(c.grade),
          superseded: superseded,
        ),
      );
      monthOfLabel[label] = r.month;
    }

    final result = [
      for (final e in byLabel.entries)
        PastSession(label: e.key, month: monthOfLabel[e.key], courses: e.value),
    ];
    result.sort((a, b) {
      final x = a.month, y = b.month;
      if (x != null && y != null) return x.compareTo(y);
      if (x != null) return -1;
      if (y != null) return 1;
      return a.label.compareTo(b.label);
    });
    return result;
  }

  /// [session]'s GPA now, and with the grades in [picks] (course key to grade)
  /// tried on it.
  static SessionOutcome session(
    PastSession session,
    Map<String, PlannerGrade> picks,
  ) {
    var credits = 0.0, nowPoints = 0.0, afterPoints = 0.0;
    for (final c in session.courses) {
      if (!c.hasPoints) continue;
      credits += c.credits;
      nowPoints += c.credits * c.gradeValue!.points;
      afterPoints += c.credits * _tried(c, picks).points;
    }
    if (credits == 0) {
      return const SessionOutcome(credits: 0, now: null, after: null);
    }
    return SessionOutcome(
      credits: credits,
      now: nowPoints / credits,
      after: afterPoints / credits,
    );
  }

  /// The CGPA with [picks] tried, from VTOP's own [vtopCgpa].
  static CgpaOutcome cgpa({
    required double vtopCgpa,
    required List<PastSession> sessions,
    required Map<String, PlannerGrade> picks,
  }) {
    var credits = 0.0, nowPoints = 0.0, afterPoints = 0.0;
    for (final s in sessions) {
      for (final c in s.courses) {
        if (!c.hasPoints || c.superseded) continue;
        credits += c.credits;
        nowPoints += c.credits * c.gradeValue!.points;
        afterPoints += c.credits * _tried(c, picks).points;
      }
    }
    if (credits == 0) {
      return CgpaOutcome(now: vtopCgpa, after: vtopCgpa, matchesVtop: false);
    }
    final rebuiltNow = nowPoints / credits;
    final rebuiltAfter = afterPoints / credits;
    final after = (vtopCgpa + (rebuiltAfter - rebuiltNow)).clamp(0.0, 10.0);
    return CgpaOutcome(
      now: vtopCgpa,
      after: after,
      matchesVtop: (rebuiltNow - vtopCgpa).abs() <= 0.015,
    );
  }

  static PlannerGrade _tried(PastCourse c, Map<String, PlannerGrade> picks) =>
      c.canChange ? (picks[c.key] ?? c.gradeValue!) : c.gradeValue!;

  /// S to F only. Anything else (P, N, W, blank) carries no points.
  static PlannerGrade? _gradeOf(String raw) {
    final g = raw.trim().toUpperCase();
    for (final grade in PlannerGrade.values) {
      if (grade.letter == g) return grade;
    }
    return null;
  }

  static double _credits(String raw) {
    final m = RegExp(
      r'\d+(?:\.\d+)?',
    ).firstMatch(raw.trim().replaceAll(',', '.'));
    return m == null ? 0 : (double.tryParse(m.group(0)!) ?? 0);
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, //
  };

  /// "Jan-2026" to January 2026; null when it does not read that way.
  static DateTime? _month(String raw) {
    final m = RegExp(
      r'^\s*([A-Za-z]{3})[A-Za-z]*[\s\-/]+(\d{4})\s*$',
    ).firstMatch(raw);
    if (m == null) return null;
    final month = _months[m.group(1)!.toLowerCase()];
    final year = int.tryParse(m.group(2)!);
    return (month == null || year == null) ? null : DateTime(year, month);
  }

  /// "Jan-2026" as "Jan 2026"; whatever VTOP wrote when it does not parse.
  static String _label(String raw) {
    final month = _month(raw);
    if (month == null) return raw.trim().isEmpty ? 'Other' : raw.trim();
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${names[month.month - 1]} ${month.year}';
  }
}
