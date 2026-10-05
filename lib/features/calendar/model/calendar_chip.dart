import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';

/// The kinds of day the academic calendar can show.
///
/// VTOP's own calendar only knows about holidays, working days and the odd
/// exam block, so [exam], [countdown] and [event] are layered on top of it from
/// data the app already has (exam schedule, the user's countdowns). A VTOP
/// label the app does not recognise falls back to [event] rather than being
/// dropped, so a new VTOP entry is still visible instead of silently vanishing.
enum CalendarDayKind {
  /// A normal teaching day.
  instructional,

  /// Campus closed — a declared holiday, or a non-instructional day.
  holiday,

  /// No classes at all.
  noClasses,

  /// An assessment block: CAT, FAT or a lab FAT.
  exam,

  /// One of the user's own countdowns.
  countdown,

  /// Anything the app cannot classify.
  event,
}

/// One day rendered on the calendar grid: a VTOP day merged with whatever the
/// app knows about that date.
class CalendarChip {
  const CalendarChip({
    required this.date,
    required this.kind,
    required this.title,
    this.subtitle,
    this.detail,
  });

  final DateTime date;
  final CalendarDayKind kind;

  /// Short label for the chip itself, e.g. `WorkingDay` or `Deepavali`.
  final String title;

  /// Optional second line in the event list.
  final String? subtitle;

  /// Longer body text shown in the list.
  final String? detail;

  /// Rank used when a day carries several kinds. Higher wins, so an exam beats
  /// a plain working day and a user countdown never masks a real closure.
  int get precedence => switch (kind) {
    CalendarDayKind.countdown => 0,
    CalendarDayKind.instructional => 1,
    CalendarDayKind.event => 2,
    CalendarDayKind.exam => 3,
    CalendarDayKind.holiday => 4,
    CalendarDayKind.noClasses => 5,
  };
}

/// The two colours on the calendar that are not status colours.
///
/// Everything else on the grid describes something VTOP published, so it wears
/// a status colour. A countdown is the user's own marker and needs to be
/// unmistakable at a glance.
class AppCalendarColors {
  const AppCalendarColors({required this.countdown});

  /// Distinct from success (green), warning (amber), danger (red) and neutral,
  /// and from the accent the app uses elsewhere, so a circled countdown is
  /// never mistaken for a holiday.
  final Color countdown;

  static AppCalendarColors of(BuildContext context) {
    // Read `colorScheme.brightness`, not `Theme.of(context).brightness`:
    // `getThemeData` only sets the former, so `ThemeData.brightness` is always
    // light and a brightness check on it silently never takes the dark branch.
    final isDark =
        Theme.of(context).colorScheme.brightness == Brightness.dark;
    // Violet reads as "mine, not the institution's" and holds up against both
    // the amber exams and the green closures sitting next to it.
    return AppCalendarColors(
      countdown: isDark ? const Color(0xFFB39DFF) : const Color(0xFF6D3BEF),
    );
  }
}

/// Classifies the free-text labels VTOP puts on a calendar cell.
///
/// VTOP renders each entry as `<description> (<label>)`, where the label is a
/// short qualifier. The parser strips the brackets and hands us both, and the
/// wording shifts slightly between semesters, so matching is done on a
/// normalised, substring basis rather than on exact equality.
class CalendarEventClassifier {
  const CalendarEventClassifier._();

  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

  /// The kind a single VTOP entry represents.
  static CalendarDayKind classify(CalendarEvent event) {
    final text = _normalise('${event.label} ${event.description}');

    if (text.contains('no instructional') ||
        text.contains('no class') ||
        text.contains('non instructional')) {
      return CalendarDayKind.noClasses;
    }
    if (text.contains('holiday') || text.contains('deepavali') ||
        text.contains('christmas') || text.contains('independence')) {
      return CalendarDayKind.holiday;
    }
    if (text.contains('lab fat') || text.contains('fat') ||
        text.contains('exam') || text.contains('cat')) {
      return CalendarDayKind.exam;
    }
    if (text.contains('working') || text.contains('instructional')) {
      return CalendarDayKind.instructional;
    }
    return CalendarDayKind.event;
  }

  /// A short, human label for the chip.
  static String shortLabel(CalendarEvent event) {
    final label = event.label.trim();
    if (label.isNotEmpty) return label;
    final description = event.description.trim();
    // Descriptions are long ("Instructional Day - General (Semester)"), so the
    // part before the first dash reads better inside a small day chip.
    final head = description.split(RegExp(r'\s[-–]\s')).first.trim();
    return head.isEmpty ? 'Event' : head;
  }

  /// The colour a day chip is drawn in, taken from the app's status palette so
  /// it follows the active light/dark theme instead of being hardcoded.
  static Color colorFor(
    BuildContext context,
    CalendarDayKind kind,
  ) {
    final status = AppStatusColors.of(context);
    return switch (kind) {
      CalendarDayKind.instructional => status.success,
      CalendarDayKind.holiday => status.success,
      CalendarDayKind.noClasses => status.neutral,
      CalendarDayKind.exam => status.warning,
      // A countdown is the user's own marker, not a VTOP fact, so it gets a
      // distinct hue that cannot be confused with a closure or an exam.
      CalendarDayKind.countdown => AppCalendarColors.of(context).countdown,
      CalendarDayKind.event => const Color(0xFF5E35B1),
    };
  }

  /// Whether a day of this kind is worth marking on the grid.
  ///
  /// A plain instructional day is the default state of the semester - marking
  /// it says nothing, and marking it in the same colour as a holiday makes
  /// holidays invisible. So only closures, exams, no-class days and events
  /// get a marker.
  static bool isMarked(CalendarDayKind? kind) => switch (kind) {
    CalendarDayKind.instructional => false,
    CalendarDayKind.holiday ||
    CalendarDayKind.noClasses ||
    CalendarDayKind.exam ||
    CalendarDayKind.event ||
    CalendarDayKind.countdown => true,
    null => false,
  };

  /// The kind whose colour should ring a day, or null when the day is unmarked.
  ///
  /// A day routinely carries several chips: VTOP's own entry plus any countdowns
  /// the user has set. Countdowns sort last, because their precedence is the
  /// lowest so they never mask a real closure - which meant a cell that only
  /// looked at the leading chip never saw them at all.
  ///
  /// A countdown therefore wins the ring: it is the user's own marker and the
  /// point of it is being visible. A closure or exam sharing the day is still
  /// listed below with its own badge.
  static CalendarDayKind? ringKindFor(List<CalendarChip> chips) {
    for (final chip in chips) {
      if (chip.kind == CalendarDayKind.countdown) return CalendarDayKind.countdown;
    }
    // Highest precedence wins rather than first-in-list, so the result does not
    // quietly depend on the caller having sorted the chips.
    CalendarChip? best;
    for (final chip in chips) {
      if (!isMarked(chip.kind)) continue;
      if (best == null || chip.precedence > best.precedence) best = chip;
    }
    return best?.kind;
  }

  /// Builds the chips for one VTOP day.
  static List<CalendarChip> chipsFor(CalendarDay day) {
    return day.events
        .map(
          (event) => CalendarChip(
            date: DateTime.parse(day.date),
            kind: classify(event),
            title: shortLabel(event),
            detail: event.description.trim(),
          ),
        )
        .toList(growable: false);
  }
}