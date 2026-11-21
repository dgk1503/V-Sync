import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';
import 'package:vit_ap_student_app/features/home/view/pages/improve_cgpa_page.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

/// Plans the next CGPA from a target.
///
/// The student sets the CGPA they want; the page lists this semester's courses,
/// read from their own timetable with their credits, and pencils in the grade
/// each one needs for the plan to land on the target. Any grade can be changed
/// to see what it does. The starting point is the CGPA and credit total VTOP
/// reports, so it can be checked against the portal.
///
/// A timetable saved before the scraper read credits has none, so those courses
/// ask for them. Courses that are not on the timetable can be added by hand.
class GpaPlannerPage extends ConsumerStatefulWidget {
  const GpaPlannerPage({super.key});

  @override
  ConsumerState<GpaPlannerPage> createState() => _GpaPlannerPageState();
}

class _GpaPlannerPageState extends ConsumerState<GpaPlannerPage> {
  double? _target;

  /// Grades the student has picked, by course code. A course without an entry
  /// follows the suggestion, so changing the target re-plans it.
  final Map<String, PlannerGrade> _grades = {};

  /// Credits the student set for a timetable course, by code. They win over
  /// what the timetable says (or fill in a course that came without any).
  final Map<String, double> _credits = {};

  /// Timetable courses the student took out of the plan, by code. They stay on
  /// the timetable; "Restore" brings them back.
  final Set<String> _removed = {};

  /// Courses the student added by hand.
  final List<PlannedCourse> _extra = [];
  int _nextId = 1;

  static const int _minCredits = 1;
  static const int _maxCredits = 12;

  void _add(PlannerGrade grade) =>
      setState(() => _extra.add(PlannedCourse(id: _nextId++, grade: grade)));

  void _updateExtra(PlannedCourse updated) => setState(() {
    final index = _extra.indexWhere((c) => c.id == updated.id);
    if (index != -1) _extra[index] = updated;
  });

  void _removeExtra(PlannedCourse course) =>
      setState(() => _extra.removeWhere((c) => c.id == course.id));

  void _setAll(PlannerGrade grade) => setState(() {
    for (final code in _knownCodes) {
      _grades[code] = grade;
    }
    for (var i = 0; i < _extra.length; i++) {
      _extra[i] = _extra[i].copyWith(grade: grade);
    }
  });

  List<String> _knownCodes = const [];

  static double _round1(double value) => (value * 10).round() / 10;

  Future<void> _refreshTimetable() =>
      ref.read(timetableViewModelProvider.notifier).refreshTimetable();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final history = user?.profile.target?.gradeHistory.target;
    final cgpa = double.tryParse((history?.cgpa ?? '').trim());
    final done = double.tryParse((history?.creditsEarned ?? '').trim());

    // The freshly fetched timetable when there is one, else the saved copy.
    final timetableState = ref.watch(timetableViewModelProvider);
    final timetable = timetableState?.asData?.value ?? user?.timetable.target;
    final refreshing = timetableState?.isLoading == true;

    ref.listen(timetableViewModelProvider, (_, next) {
      next?.whenOrNull(
        error: (error, _) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString()))),
      );
    });

    Widget scaffold(Widget body) => Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'GPA planner',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: body,
    );

    if (cgpa == null || done == null) {
      return scaffold(
        const EmptyContentView(
          primaryText: 'No CGPA yet',
          secondaryText:
              'The planner starts from the CGPA VTOP reports. It will appear '
              'here once your grade history has loaded.',
        ),
      );
    }

    final allCourses = SemesterCourses.from(timetable);
    final semester = [
      for (final c in allCourses)
        if (!_removed.contains(c.code)) c,
    ];
    _knownCodes = [for (final c in semester) c.code];
    final anyUnknown = semester.any((c) => c.credits == null);

    // What the student set wins; then the timetable; 3 only as a last resort.
    double creditsOf(SemesterCourse c) => _credits[c.code] ?? c.credits ?? 3.0;

    final semesterCredits =
        semester.fold<double>(0, (sum, c) => sum + creditsOf(c)) +
        _extra.fold<double>(0, (sum, c) => sum + c.credits);

    final target = _target ?? (cgpa >= 9.8 ? 10.0 : _round1(cgpa + 0.2));
    final goal = GpaPlanner.goal(
      cgpa: cgpa,
      creditsDone: done,
      semesterCredits: semesterCredits,
      target: target,
    );
    final suggested = goal?.suggested ?? PlannerGrade.a;

    final planned = <PlannedCourse>[
      for (var i = 0; i < semester.length; i++)
        PlannedCourse(
          id: -(i + 1),
          name: semester[i].name,
          credits: creditsOf(semester[i]),
          grade: _grades[semester[i].code] ?? suggested,
        ),
      ..._extra,
    ];
    final projection = GpaPlanner.project(
      cgpa: cgpa,
      creditsDone: done,
      courses: planned,
    );

    return scaffold(
      SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the CGPA you want. Your courses are listed with the grade '
                'each one needs to get you there.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              const _ImproveEntry(),
              const SizedBox(height: 12),
              _NowCard(cgpa: cgpa, credits: done),
              const SizedBox(height: 12),
              _TargetCard(
                target: target,
                goal: goal,
                onChanged: (value) => setState(() {
                  _target = value.clamp(0.0, 10.0);
                }),
              ),
              const SizedBox(height: 20),

              if (allCourses.isEmpty && _extra.isEmpty) ...[
                _NoCourses(
                  hasTimetable: timetable != null,
                  refreshing: refreshing,
                  onRefresh: _refreshTimetable,
                  onAdd: () => _add(suggested),
                ),
              ] else ...[
                Text(
                  'This semester',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allCourses.isEmpty
                      ? 'Courses you add'
                      : 'From your timetable',
                  style: _caption(context),
                ),
                const SizedBox(height: 12),

                if (anyUnknown || !SemesterCourses.isComplete(timetable)) ...[
                  _CreditsNotice(
                    message: anyUnknown
                        ? 'Some credits are missing from your saved timetable. '
                              'Enter them below, or refresh it to load them '
                              '(this may ask for an OTP).'
                        : 'Your saved timetable lists only the courses that '
                              'meet each week. Refresh it to load every course '
                              'with its credits (this may ask for an OTP).',
                    refreshing: refreshing,
                    onRefresh: _refreshTimetable,
                  ),
                  const SizedBox(height: 10),
                ],

                for (final course in semester) ...[
                  _SemesterCourseCard(
                    key: ValueKey('course-${course.code}'),
                    course: course,
                    credits: creditsOf(course),
                    grade: _grades[course.code] ?? suggested,
                    minCredits: _minCredits,
                    maxCredits: _maxCredits,
                    onCredits: (value) =>
                        setState(() => _credits[course.code] = value),
                    onGrade: (grade) =>
                        setState(() => _grades[course.code] = grade),
                    onRemove: () => setState(() => _removed.add(course.code)),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_removed.isNotEmpty) ...[
                  _RemovedNote(
                    count: _removed.length,
                    onRestore: () => setState(_removed.clear),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final course in _extra) ...[
                  _CourseCard(
                    key: ValueKey(course.id),
                    course: course,
                    minCredits: _minCredits,
                    maxCredits: _maxCredits,
                    onChanged: _updateExtra,
                    onRemove: () => _removeExtra(course),
                  ),
                  const SizedBox(height: 10),
                ],
                _Actions(
                  onAdd: () => _add(suggested),
                  onSetAll: _setAll,
                  onReset: _grades.isEmpty
                      ? null
                      : () => setState(_grades.clear),
                ),
                const SizedBox(height: 14),
                if (planned.isNotEmpty)
                  _ResultCard(projection: projection, target: target),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _caption(BuildContext context, {Color? color}) => TextStyle(
  fontFamily: 'Instrument Sans',
  fontSize: 12,
  height: 1.3,
  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Where the student stands now, as VTOP reports it.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.cgpa, required this.credits});

  final double cgpa;
  final double credits;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _caption(context)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          stat('CGPA now', cgpa.toStringAsFixed(2)),
          stat(
            'Credits earned',
            credits == credits.roundToDouble()
                ? credits.toStringAsFixed(0)
                : credits.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }
}

/// One planned course: an optional name, its credits and the grade expected.
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    super.key,
    required this.course,
    required this.minCredits,
    required this.maxCredits,
    required this.onChanged,
    required this.onRemove,
  });

  final PlannedCourse course;
  final int minCredits;
  final int maxCredits;
  final ValueChanged<PlannedCourse> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: course.name,
                  onChanged: (value) => onChanged(course.copyWith(name: value)),
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Course name (optional)',
                    hintStyle: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove course',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _Stepper(
                  value: course.credits,
                  min: minCredits,
                  max: maxCredits,
                  onChanged: (value) =>
                      onChanged(course.copyWith(credits: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GradeStrip(
              selected: course.grade,
              onPick: (grade) => onChanged(course.copyWith(grade: grade)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grade, as the same pill the planners use for a choice.
class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final PlannerGrade grade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Grade ${grade.letter}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            grade.letter,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selected ? colors.onPrimary : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Every grade, S to F, in ONE row of equal boxes. (Fixed-width boxes in a Wrap
/// left the last grade alone on a second row.)
class _GradeStrip extends StatelessWidget {
  const _GradeStrip({required this.selected, required this.onPick});

  final PlannerGrade? selected;
  final ValueChanged<PlannerGrade> onPick;

  @override
  Widget build(BuildContext context) {
    const grades = PlannerGrade.values;
    return Row(
      children: [
        for (var i = 0; i < grades.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _GradePill(
              grade: grades[i],
              selected: selected == grades[i],
              onTap: () => onPick(grades[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// A minus, a count and a plus.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final int min;
  final int max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget button(IconData icon, String label, bool enabled, double next) =>
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: InkWell(
            onTap: enabled ? () => onChanged(next) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? colors.onSurface
                    : colors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, 'Fewer credits', value > min, value - 1),
        SizedBox(
          width: 92,
          child: Text(
            '${_credits(value)} ${value == 1 ? 'credit' : 'credits'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ),
        button(Icons.add_rounded, 'More credits', value < max, value + 1),
      ],
    );
  }
}

/// Add another course, set every grade at once to see a scenario, or go back to
/// the suggested grades.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.onAdd,
    required this.onSetAll,
    required this.onReset,
  });

  final VoidCallback onAdd;
  final ValueChanged<PlannerGrade> onSetAll;

  /// Null while there is nothing picked to undo.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add a course',
                style: TextStyle(fontFamily: 'Instrument Sans', fontSize: 13.5),
              ),
            ),
            if (onReset != null)
              TextButton(
                onPressed: onReset,
                child: const Text(
                  'Back to suggested',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Set every grade to', style: _caption(context)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < PlannerGrade.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => onSetAll(PlannerGrade.values[i]),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 0.75,
                      ),
                    ),
                    child: Text(
                      PlannerGrade.values[i].letter,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The semester GPA, the CGPA it leads to, and how far that moves it.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.projection, required this.target});

  final GpaProjection projection;
  final double target;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);

    final change = projection.change;
    // Two decimals is what is shown, so a change that rounds to zero is
    // neither up nor down.
    final shown = (change * 100).round() / 100;
    final tint = shown > 0
        ? status.success
        : shown < 0
        ? status.danger
        : colors.onSurfaceVariant;
    final sign = shown > 0 ? '+' : '';

    Widget stat(String label, String value, {Color? color, double size = 22}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _caption(context)),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: size,
                  fontWeight: FontWeight.w500,
                  color: color ?? colors.onSurface,
                ),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'After this semester',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(
                'New CGPA',
                projection.newCgpa.toStringAsFixed(2),
                color: tint,
                size: 30,
              ),
              stat('Change', '$sign${shown.toStringAsFixed(2)}', color: tint),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('Semester GPA', projection.semesterGpa.toStringAsFixed(2)),
              stat('Credits', _credits(projection.semesterCredits)),
            ],
          ),
          const SizedBox(height: 12),
          // Compared on the two decimals shown, so a plan that displays 9.50
          // against a 9.5 target does not read as "short".
          Builder(
            builder: (context) {
              final gap =
                  (target * 100).round() - (projection.newCgpa * 100).round();
              final meets = gap <= 0;
              return Text(
                meets
                    ? 'This plan reaches your target of ${target.toStringAsFixed(1)}.'
                    : 'This plan is ${(gap / 100).toStringAsFixed(2)} short of '
                          'your target of ${target.toStringAsFixed(1)}.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13.5,
                  height: 1.4,
                  color: meets ? status.success : status.danger,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "I want to reach X": what the semester has to average to get there.
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    required this.goal,
    required this.onChanged,
  });

  final double target;
  final GpaGoal? goal;
  final ValueChanged<double> onChanged;

  String _sentence() {
    final g = goal;
    if (g == null) return 'Add a course to see what a target would take.';
    if (g.alreadyThere) {
      return 'You are already above ${target.toStringAsFixed(1)}, even a weak '
          'semester keeps you there.';
    }
    if (!g.reachable) {
      return 'Not reachable in one semester of this size. Straight S grades '
          'would take you to ${g.best.toStringAsFixed(2)}.';
    }
    final grade = g.gradeNeeded;
    // "an S", "an A", "an E", "an F" but "a B", "a C", "a D".
    final article = grade != null && 'SAEF'.contains(grade.letter) ? 'an' : 'a';
    final letter = grade == null
        ? ''
        : ', roughly $article ${grade.letter} average';
    return 'Average ${g.required.toStringAsFixed(2)} grade points this '
        'semester$letter.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final g = goal;
    final tint = g == null
        ? colors.onSurface
        : !g.reachable
        ? status.danger
        : g.alreadyThere
        ? status.success
        : colors.onSurface;

    Widget button(IconData icon, String label, bool enabled, double next) =>
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: InkWell(
            onTap: enabled ? () => onChanged(next) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? colors.onSurface
                    : colors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If you want to reach',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              button(
                Icons.remove_rounded,
                'Lower target',
                target > 0,
                (target * 10).round() / 10 - 0.1,
              ),
              SizedBox(
                width: 96,
                child: Text(
                  target.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
              ),
              button(
                Icons.add_rounded,
                'Higher target',
                target < 10,
                (target * 10).round() / 10 + 0.1,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sentence(),
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13.5,
              height: 1.4,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Credits as a person writes them: "4", or "1.5" when it is not whole.
String _credits(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// One of this semester's courses, from the timetable: its credits (which the
/// student can change) and the grade planned for it. The cross takes the course
/// out of the plan.
class _SemesterCourseCard extends StatelessWidget {
  const _SemesterCourseCard({
    super.key,
    required this.course,
    required this.credits,
    required this.grade,
    required this.minCredits,
    required this.maxCredits,
    required this.onCredits,
    required this.onGrade,
    required this.onRemove,
  });

  final SemesterCourse course;
  final double credits;
  final PlannerGrade grade;
  final int minCredits;
  final int maxCredits;
  final ValueChanged<double> onCredits;
  final ValueChanged<PlannerGrade> onGrade;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(course.code, style: _caption(context)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove course',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _Stepper(
                  value: credits,
                  min: minCredits,
                  max: maxCredits,
                  onChanged: onCredits,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GradeStrip(selected: grade, onPick: onGrade),
          ),
        ],
      ),
    );
  }
}

/// Says how many timetable courses were taken out of the plan, and brings them
/// back.
class _RemovedNote extends StatelessWidget {
  const _RemovedNote({required this.count, required this.onRestore});

  final int count;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            count == 1 ? '1 course removed' : '$count courses removed',
            style: _caption(context),
          ),
        ),
        TextButton(
          onPressed: onRestore,
          child: const Text(
            'Restore',
            style: TextStyle(fontFamily: 'Instrument Sans', fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

/// Said when some courses came without credits: they can be filled in by hand,
/// or fetched by refreshing the timetable.
class _CreditsNotice extends StatelessWidget {
  const _CreditsNotice({
    required this.message,
    required this.refreshing,
    required this.onRefresh,
  });

  final String message;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 12.5,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            )
          else
            TextButton(
              onPressed: onRefresh,
              child: const Text(
                'Refresh',
                style: TextStyle(fontFamily: 'Instrument Sans', fontSize: 13.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when there are no courses to plan with yet.
class _NoCourses extends StatelessWidget {
  const _NoCourses({
    required this.hasTimetable,
    required this.refreshing,
    required this.onRefresh,
    required this.onAdd,
  });

  final bool hasTimetable;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    ButtonStyle style() => FilledButton.styleFrom(
      elevation: 0,
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    const label = TextStyle(
      fontFamily: 'Instrument Sans',
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 30, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            hasTimetable
                ? 'No courses on your timetable'
                : 'Your timetable is not loaded',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Load it to see this semester\'s courses, or add the ones you plan '
            'to take.',
            textAlign: TextAlign.center,
            style: _caption(context).copyWith(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: refreshing ? null : onRefresh,
                style: style(),
                child: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : const Text('Load timetable', style: label),
              ),
              TextButton(
                onPressed: onAdd,
                child: const Text(
                  'Add a course',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Entry to the page that tries other grades on the semesters already completed.
///
/// A [ListTile] in the tile colour and corner radius of the cards, the same way
/// the planner's own entry reads on the grades page.
class _ImproveEntry extends StatelessWidget {
  const _ImproveEntry();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ImproveCgpaPage())),
      tileColor: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(Icons.trending_up_rounded, color: colors.onSurfaceVariant),
      title: Text(
        'Improve CGPA',
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        'Try other grades on your past semesters',
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 12.5,
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_rounded,
        size: 20,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
