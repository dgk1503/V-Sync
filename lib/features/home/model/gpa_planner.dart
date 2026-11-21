import 'package:vit_ap_student_app/core/models/timetable.dart';

/// The grades VIT awards and what each is worth.
///
/// `F` is a fail and counts as zero points; it still carries credits, so it
/// drags the average down, which is exactly what a planner has to show.
enum PlannerGrade {
  s('S', 10),
  a('A', 9),
  b('B', 8),
  c('C', 7),
  d('D', 6),
  e('E', 5),
  f('F', 0);

  const PlannerGrade(this.letter, this.points);

  final String letter;
  final int points;

  /// The lowest grade that still reaches [required] grade points, or null when
  /// even an S falls short.
  static PlannerGrade? atLeast(double required) {
    if (required > 10) return null;
    // Best to worst, then pick the lowest letter that still clears the bar.
    PlannerGrade? best;
    for (final grade in PlannerGrade.values) {
      if (grade.points >= required) best = grade;
    }
    return best;
  }
}

/// One course the student expects to take.
class PlannedCourse {
  const PlannedCourse({
    required this.id,
    this.name = '',
    this.credits = 3,
    this.grade = PlannerGrade.a,
  });

  /// Stable identity for the row, so editing one does not disturb the others.
  final int id;
  final String name;

  /// Credits can be fractional (a half-credit lab), so this is not an int.
  final double credits;
  final PlannerGrade grade;

  PlannedCourse copyWith({
    String? name,
    double? credits,
    PlannerGrade? grade,
  }) => PlannedCourse(
    id: id,
    name: name ?? this.name,
    credits: credits ?? this.credits,
    grade: grade ?? this.grade,
  );
}

/// A course read off the student's own timetable.
class SemesterCourse {
  const SemesterCourse({
    required this.code,
    required this.name,
    required this.credits,
  });

  final String code;
  final String name;

  /// The course's credits (theory part plus lab part), or null when the
  /// timetable does not say, in which case the student has to enter them.
  final double? credits;
}

/// This semester's courses and their credits, read from the saved timetable.
///
/// The source is VTOP's course table: every registered course, and every part of
/// it (a theory part and a lab part are two rows), whether or not it has a slot
/// in the weekly grid. The grid alone would miss any course that never meets, and
/// repeats the ones that do once per class.
///
/// Each *part* is counted once and a course's parts are added up: a 3-credit
/// theory part and a 1-credit lab part make a 4-credit course. A part with 0
/// credits counts for nothing, so a course whose parts are all 0 (an audit
/// course) is left out: it cannot move a GPA.
///
/// A timetable saved before the course table was read has only the grid, so
/// the list is rebuilt from that, and [isComplete] says it may be short.
class SemesterCourses {
  const SemesterCourses._();

  /// Whether [timetable] carries the whole course table, so the list is every
  /// registered course rather than only the ones that meet.
  static bool isComplete(Timetable? timetable) =>
      timetable != null && timetable.courses.isNotEmpty;

  static List<SemesterCourse> from(Timetable? timetable) {
    if (timetable == null) return const [];
    final table = timetable.courses;
    final parts = table.isNotEmpty
        ? [
            for (final c in table)
              _Part(
                code: c.code,
                name: c.name,
                kind: c.kind.isEmpty ? c.typeCode : c.kind,
                credits: c.credits,
              ),
          ]
        : _partsFromGrid(timetable);
    return _combine(parts);
  }

  /// The parts a weekly grid shows, one per (course, kind): the first reading
  /// wins, and a known value is never replaced by an unknown one from a later
  /// class.
  static List<_Part> _partsFromGrid(Timetable timetable) {
    final slots = <Day>[
      ...timetable.monday,
      ...timetable.tuesday,
      ...timetable.wednesday,
      ...timetable.thursday,
      ...timetable.friday,
      ...timetable.saturday,
      ...timetable.sunday,
    ];
    final byKey = <String, _Part>{};
    for (final slot in slots) {
      final code = (slot.courseCode ?? '').trim();
      if (code.isEmpty) continue;
      final kind = (slot.courseType ?? '').trim();
      final key = '${code.toUpperCase()}|${kind.toUpperCase()}';
      final part = _Part(
        code: code,
        name: (slot.courseName ?? '').trim(),
        kind: kind,
        credits: (slot.credits ?? '').trim(),
      );
      final seen = byKey[key];
      if (seen == null ||
          (_creditsOf(seen.credits).isUnknown &&
              !_creditsOf(part.credits).isUnknown)) {
        byKey[key] = part;
      }
    }
    return byKey.values.toList();
  }

  static List<SemesterCourse> _combine(List<_Part> parts) {
    final names = <String, String>{};
    final credits = <String, double?>{};
    final order = <String>[];
    final seenParts = <String>{};

    for (final part in parts) {
      final code = part.code.trim().toUpperCase();
      if (code.isEmpty) continue;
      // The same part twice (a repeated row) is still one part.
      if (!seenParts.add('$code|${part.kind.toUpperCase()}')) continue;

      if (!credits.containsKey(code)) order.add(code);
      if ((names[code] ?? '').isEmpty && part.name.isNotEmpty) {
        names[code] = part.name;
      }

      final value = _creditsOf(part.credits);
      final soFar = credits[code];
      if (credits.containsKey(code) && soFar == null)
        continue; // already unknown
      if (value.isUnknown) {
        credits[code] = null; // one unreadable part makes the course unknown
      } else {
        credits[code] = (soFar ?? 0) + value.value;
      }
    }

    final courses = <SemesterCourse>[
      for (final code in order)
        // 0 credits (an audit course): nothing to plan. Unknown (null) stays.
        if (credits[code] == null || credits[code]! > 0)
          SemesterCourse(
            code: code,
            name: (names[code] ?? '').isEmpty ? code : names[code]!,
            credits: credits[code],
          ),
    ]..sort((a, b) => a.code.compareTo(b.code));
    return courses;
  }

  /// The first number in [raw] ("3.0", "1.5 credits", "2,5"). Unknown when there
  /// is none; 0 is a real value.
  static _Credits _creditsOf(String? raw) {
    final text = (raw ?? '').trim().replaceAll(',', '.');
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    if (match == null) return const _Credits.unknown();
    final value = double.tryParse(match.group(0)!);
    return value == null ? const _Credits.unknown() : _Credits(value);
  }
}

/// One part of a course as read off the timetable.
class _Part {
  const _Part({
    required this.code,
    required this.name,
    required this.kind,
    required this.credits,
  });

  final String code;
  final String name;
  final String kind;
  final String credits;
}

class _Credits {
  const _Credits(this.value) : isUnknown = false;
  const _Credits.unknown() : value = 0, isUnknown = true;

  final double value;
  final bool isUnknown;
}

/// What a planned semester does to the CGPA.
class GpaProjection {
  const GpaProjection({
    required this.semesterCredits,
    required this.semesterGpa,
    required this.newCgpa,
    required this.change,
  });

  /// Credits taken in the planned semester.
  final double semesterCredits;

  /// The semester's own grade point average.
  final double semesterGpa;

  /// The CGPA once the semester is counted.
  final double newCgpa;

  /// [newCgpa] minus the CGPA the student started from.
  final double change;
}

/// What it would take to reach a target CGPA in one semester.
class GpaGoal {
  const GpaGoal({
    required this.required,
    required this.reachable,
    required this.alreadyThere,
    required this.best,
  });

  /// The semester GPA that lands exactly on the target.
  final double required;

  /// Whether a semester GPA of at most 10 gets there.
  final bool reachable;

  /// Whether the target is already met, so even a poor semester keeps it.
  final bool alreadyThere;

  /// The best CGPA this semester could possibly produce (all S).
  final double best;

  /// The lowest letter that, as an average, reaches the target; null when it
  /// cannot be reached.
  PlannerGrade? get gradeNeeded =>
      reachable && !alreadyThere ? PlannerGrade.atLeast(required) : null;

  /// The grade to pencil in for every course, so the plan lands on the target
  /// without the student having to work it out.
  ///
  /// The lowest letter that still reaches the target; an S when it cannot be
  /// reached (the closest the plan can get); an A when the target is already
  /// safe, which is a plain expectation rather than a requirement.
  PlannerGrade get suggested {
    if (!reachable) return PlannerGrade.s;
    if (alreadyThere) return PlannerGrade.a;
    return PlannerGrade.atLeast(required) ?? PlannerGrade.s;
  }
}

/// The arithmetic behind the GPA planner.
///
/// Pure on purpose, like the skip planner: it reads only what it is handed.
/// The starting point is the CGPA and credit total VTOP itself reports, so the
/// student can check it against the portal; nothing is rebuilt from the course
/// list, where a repeated course would be counted twice.
class GpaPlanner {
  const GpaPlanner._();

  /// The CGPA after taking [courses], from [cgpa] over [creditsDone] credits.
  ///
  /// ```text
  /// new CGPA = (CGPA x credits done + sum(credit x points)) / (credits done + new credits)
  /// ```
  static GpaProjection project({
    required double cgpa,
    required double creditsDone,
    required List<PlannedCourse> courses,
  }) {
    final credits = courses.fold<double>(0, (sum, c) => sum + c.credits);
    final points = courses.fold<double>(
      0,
      (sum, c) => sum + c.credits * c.grade.points,
    );

    final semesterGpa = credits == 0 ? 0.0 : points / credits;
    final total = creditsDone + credits;
    final newCgpa = total == 0 ? 0.0 : (cgpa * creditsDone + points) / total;

    return GpaProjection(
      semesterCredits: credits,
      semesterGpa: semesterGpa,
      newCgpa: newCgpa,
      change: newCgpa - cgpa,
    );
  }

  /// What a [semesterCredits]-credit semester must average to end on [target].
  ///
  /// Null when there are no credits to plan with.
  static GpaGoal? goal({
    required double cgpa,
    required double creditsDone,
    required double semesterCredits,
    required double target,
  }) {
    if (semesterCredits <= 0) return null;

    final total = creditsDone + semesterCredits;
    final required = (target * total - cgpa * creditsDone) / semesterCredits;
    final best = (cgpa * creditsDone + semesterCredits * 10) / total;

    return GpaGoal(
      required: required,
      reachable: required <= 10,
      alreadyThere: required <= 0,
      best: best,
    );
  }
}
