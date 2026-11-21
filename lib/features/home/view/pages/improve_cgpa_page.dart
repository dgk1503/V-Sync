import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/home/model/cgpa_improver.dart';
import 'package:vit_ap_student_app/features/home/model/gpa_planner.dart';

/// What if a grade had been different?
///
/// Every course from the semesters already completed, grouped the way VTOP
/// groups them (by exam month). Each course has a grade menu; choose a different
/// grade and the page shows what the semester's GPA would have been, and what
/// the CGPA would be. For anyone weighing a grade improvement, or just curious.
///
/// Nothing here is saved or sent anywhere: it only works on the grade history
/// already on the phone.
class ImproveCgpaPage extends ConsumerStatefulWidget {
  const ImproveCgpaPage({super.key});

  @override
  ConsumerState<ImproveCgpaPage> createState() => _ImproveCgpaPageState();
}

class _ImproveCgpaPageState extends ConsumerState<ImproveCgpaPage> {
  /// The grade tried on each course, by course key. A course without an entry
  /// keeps the grade it has.
  final Map<String, PlannerGrade> _picks = {};

  void _pick(PastCourse course, PlannerGrade grade) {
    setState(() {
      // Back to the grade it already has is no pick at all.
      if (grade == course.gradeValue) {
        _picks.remove(course.key);
      } else {
        _picks[course.key] = grade;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final history = ref
        .watch(currentUserProvider)
        ?.profile
        .target
        ?.gradeHistory
        .target;
    final vtopCgpa = double.tryParse((history?.cgpa ?? '').trim());

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Improve CGPA',
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

    if (history == null || history.courses.isEmpty || vtopCgpa == null) {
      return scaffold(
        const EmptyContentView(
          primaryText: 'No grades yet',
          secondaryText:
              'Your past grades will appear here once your grade history has '
              'loaded.',
        ),
      );
    }

    final sessions = CgpaImprover.sessions(history);
    final outcome = CgpaImprover.cgpa(
      vtopCgpa: vtopCgpa,
      sessions: sessions,
      picks: _picks,
    );

    return scaffold(
      SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                'Pick a different grade for any course to see what it would '
                'have done to that semester and to your CGPA.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _CgpaCard(
                outcome: outcome,
                tried: _picks.length,
                onReset: _picks.isEmpty ? null : () => setState(_picks.clear),
              ),
              for (final session in sessions) ...[
                const SizedBox(height: 22),
                _SessionHeader(
                  session: session,
                  outcome: CgpaImprover.session(session, _picks),
                ),
                const SizedBox(height: 10),
                for (final course in session.courses) ...[
                  _CourseCard(
                    key: ValueKey(course.key),
                    course: course,
                    picked: _picks[course.key],
                    onPick: (grade) => _pick(course, grade),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 6),
              Text(
                outcome.matchesVtop
                    ? 'Worked out from your grade history on this phone. '
                          'Nothing is saved or sent.'
                    : 'VTOP counts your CGPA slightly differently from this '
                          'list, so the change is exact but the new CGPA is a '
                          'close estimate. Nothing is saved or sent.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 11.5,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Now" and "after" side by side, with the change between them.
class _CgpaCard extends StatelessWidget {
  const _CgpaCard({
    required this.outcome,
    required this.tried,
    required this.onReset,
  });

  final CgpaOutcome outcome;
  final int tried;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final changed = outcome.change.abs() >= 0.005;

    Widget figure(String label, double value, {bool strong = false}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _caption(context)),
              const SizedBox(height: 4),
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                  color: strong ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              figure('CGPA now', outcome.now),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 12),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
              figure('CGPA after', outcome.after, strong: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  changed
                      ? '${_signed(outcome.change)} from '
                            '$tried ${tried == 1 ? 'change' : 'changes'}'
                      : 'No changes yet',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: changed
                        ? _changeColor(context, outcome.change)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: onReset,
                child: const Text(
                  'Reset',
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

/// A semester's name, with its GPA now and after the changes tried on it.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.outcome});

  final PastSession session;
  final SessionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final changed = (outcome.change ?? 0).abs() >= 0.005;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.label,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                outcome.now == null
                    ? 'No graded credits'
                    : '${_credits(outcome.credits)} '
                          '${outcome.credits == 1 ? 'credit' : 'credits'}',
                style: _caption(context),
              ),
            ],
          ),
        ),
        if (outcome.now != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('SGPA', style: _caption(context)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: outcome.now!.toStringAsFixed(2),
                      style: TextStyle(
                        color: changed
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                    if (changed) ...[
                      TextSpan(
                        text: '  →  ',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      TextSpan(
                        text: outcome.after!.toStringAsFixed(2),
                        style: TextStyle(
                          color: _changeColor(context, outcome.change!),
                        ),
                      ),
                    ],
                  ],
                ),
                style: const TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// One course: what it is, and a menu to try another grade on it.
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    super.key,
    required this.course,
    required this.picked,
    required this.onPick,
  });

  final PastCourse course;
  final PlannerGrade? picked;
  final ValueChanged<PlannerGrade> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detail = [
      course.code,
      if (course.category.isNotEmpty) course.category,
      '${_credits(course.credits)} ${course.credits == 1 ? 'credit' : 'credits'}',
    ].join(' · ');

    final note = !course.hasPoints
        ? 'Counts for no points'
        : course.superseded
        ? 'Taken again later, so the later grade counts'
        : picked != null
        ? 'Was ${course.grade}'
        : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title.isEmpty ? course.code : course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: course.canChange
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: _caption(context)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12,
                      color: picked != null
                          ? _changeColor(
                              context,
                              picked!.points - course.gradeValue!.points,
                            )
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (course.canChange)
            _GradeMenu(
              current: picked ?? course.gradeValue!,
              original: course.gradeValue!,
              changed: picked != null,
              onPick: onPick,
            )
          else
            _FixedGrade(grade: course.grade),
        ],
      ),
    );
  }
}

/// The grade of a course, as a button that opens every grade to choose from.
class _GradeMenu extends StatelessWidget {
  const _GradeMenu({
    required this.current,
    required this.original,
    required this.changed,
    required this.onPick,
  });

  final PlannerGrade current;
  final PlannerGrade original;
  final bool changed;
  final ValueChanged<PlannerGrade> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopupMenuButton<PlannerGrade>(
      tooltip: 'Change grade',
      position: PopupMenuPosition.under,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final grade in PlannerGrade.values)
          PopupMenuItem<PlannerGrade>(
            value: grade,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    grade.letter,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    grade == original
                        ? '${grade.points} pts · current'
                        : '${grade.points} pts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'Grade ${current.letter}. Tap to change',
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            // The accent marks a choice that has been made.
            color: changed ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current.letter,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: changed ? colors.onPrimary : colors.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: changed ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grade of a course that cannot be tried another one.
class _FixedGrade extends StatelessWidget {
  const _FixedGrade({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Text(
        grade.isEmpty ? '-' : grade,
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

TextStyle _caption(BuildContext context) => TextStyle(
  fontFamily: 'Instrument Sans',
  fontSize: 12,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Green for a gain, red for a loss: status colour on text, never on a card.
Color _changeColor(BuildContext context, num change) {
  final status = AppStatusColors.of(context);
  return change > 0 ? status.success : status.danger;
}

String _signed(double value) =>
    '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(2)}';

/// "4", or "1.5" when it is not whole.
String _credits(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
