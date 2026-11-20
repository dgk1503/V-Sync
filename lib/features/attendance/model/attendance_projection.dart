import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';

/// How many of a course's classes are still to come before [until].
///
/// The count is deliberately **not** `(until - now) x classesPerWeek`: a
/// holiday or a "no instructional day" in between removes classes, and the
/// academic calendar is the only thing that knows. So this walks each day from
/// today to the target and, for days the calendar marks as instructional,
/// adds how many of this course's slots fall on that weekday.
///
/// Best effort — it cannot know about holidays announced later, cancelled or
/// extra classes, or attendance VTOP has not posted yet. When the calendar has
/// no entry for a day, that day is treated as instructional rather than skipped,
/// which keeps the count from collapsing to zero on a partially published
/// calendar.
class AttendanceProjection {
  const AttendanceProjection._();

  /// Weekday keys in the order [Timetable] stores them.
  static const List<String> _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static List<Day> _day(Timetable t, int index) => switch (index) {
    0 => t.monday.toList(),
    1 => t.tuesday.toList(),
    2 => t.wednesday.toList(),
    3 => t.thursday.toList(),
    4 => t.friday.toList(),
    5 => t.saturday.toList(),
    _ => t.sunday.toList(),
  };

  static int classesLeftUntil({
    required String courseCode,
    required Timetable timetable,
    required List<CalendarMonth> months,
    required DateTime now,
    DateTime? until,
  }) {
    if (until == null) return 0;

    // How many times this course meets on each weekday. DateTime.weekday is
    // 1-7 Monday-Sunday, which matches the model's field order.
    final perWeekday = <int, int>{};
    for (var i = 0; i < _weekdays.length; i++) {
      final classes = _day(timetable, i);
      final count = classes
          .where(
            (entry) => (entry.courseCode ?? '').trim() == courseCode.trim(),
          )
          .length;
      if (count > 0) perWeekday[i + 1] = count;
    }
    if (perWeekday.isEmpty) return 0;

    final today = DateTime(now.year, now.month, now.day);
    var total = 0;
    var day = today;
    // The target day itself is not counted: classes on FAT day are the exam.
    while (day.isBefore(until)) {
      final count = perWeekday[day.weekday];
      if (count != null && _holdsClasses(months, day)) total += count;
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return total;
  }

  /// Whether the academic calendar says [day] is a teaching day.
  ///
  /// A day the calendar does not mention is assumed to hold classes, so an
  /// unpopulated calendar degrades to a plain weekday count rather than to
  /// nothing.
  static bool _holdsClasses(List<CalendarMonth> months, DateTime day) {
    CalendarChip? best;
    for (final month in months) {
      if (month.year != day.year || month.month != day.month) continue;
      for (final chip in month.chips) {
        if (chip.date.day != day.day) continue;
        // Prefer the most consequential entry on the day.
        if (best == null || chip.precedence > best.precedence) best = chip;
      }
    }
    if (best == null) return true;
    return switch (best.kind) {
      CalendarDayKind.noClasses => false,
      CalendarDayKind.holiday => false,
      _ => true,
    };
  }

  /// Every day the academic calendar says has no classes, with the calendar's
  /// own wording as the reason.
  ///
  /// Only closures that actually remove a class count. VTOP marks every Sunday
  /// as a holiday with the generic note "Holiday"; those are filler and are
  /// left out, so only named holidays and no-instructional days remain. When a
  /// day carries several entries the most consequential one supplies the reason.
  static Map<DateTime, String> closedDays(List<CalendarMonth> months) {
    final strongest = <DateTime, CalendarChip>{};
    for (final month in months) {
      for (final chip in month.chips) {
        if (chip.kind != CalendarDayKind.holiday &&
            chip.kind != CalendarDayKind.noClasses) {
          continue;
        }
        if (CalendarEventClassifier.isOrdinarySunday(chip)) continue;
        final date = DateTime(chip.date.year, chip.date.month, chip.date.day);
        final existing = strongest[date];
        if (existing == null || chip.precedence > existing.precedence) {
          strongest[date] = chip;
        }
      }
    }
    return {
      for (final entry in strongest.entries)
        entry.key: _closureReason(entry.value),
    };
  }

  /// The most descriptive text on a closure chip: the longer free-text note when
  /// it says something the short label does not ("Deepavali" over "Holiday").
  static String _closureReason(CalendarChip chip) {
    final title = chip.title.trim();
    final detail = (chip.detail ?? '').trim();
    if (detail.isNotEmpty && detail.toLowerCase() != title.toLowerCase()) {
      return detail;
    }
    return title.isEmpty ? 'No classes' : title;
  }

  /// The earliest day at or after [from] carrying a chip that [matches], or
  /// null when the calendar has none. Used to locate the next CAT / FAT.
  ///
  /// [matches] is handed every piece of text on the chip, not just its short
  /// title: VTOP splits an entry into a qualifier ("WorkingDay") and a
  /// description ("End Sem Exam"), so "FAT" often only appears in the latter.
  static DateTime? firstDayWhere(
    List<CalendarMonth> months,
    DateTime from,
    bool Function(CalendarDayKind kind, String text) matches,
  ) {
    DateTime? best;
    for (final month in months) {
      for (final chip in month.chips) {
        if (chip.date.isBefore(from)) continue;
        if (!matches(chip.kind, _text(chip))) continue;
        if (best == null || chip.date.isBefore(best)) best = chip.date;
      }
    }
    return best;
  }

  /// The first day, on or after [from], that the theory FAT starts.
  ///
  /// VTOP also lists **Lab FAT** days, which are ordinary teaching days with a
  /// lab exam in the lab slot, so they must not be mistaken for the start of the
  /// FAT: teaching carries on through them. A chip is a lab FAT when its own
  /// short label says "lab"; matching "fat" anywhere in the text used to pick the
  /// first Lab FAT day and report the term as ending days early.
  static DateTime? fatStart(List<CalendarMonth> months, DateTime from) {
    final start = DateTime(from.year, from.month, from.day);
    DateTime? best;
    for (final month in months) {
      for (final chip in month.chips) {
        if (chip.kind != CalendarDayKind.exam) continue;
        if (chip.date.isBefore(start)) continue;
        if (_isLabExam(chip)) continue;
        if (!RegExp(r'\bfat\b').hasMatch(_text(chip))) continue;
        if (best == null || chip.date.isBefore(best)) best = chip.date;
      }
    }
    return best;
  }

  /// The first exam day of any kind, on or after [from], that is not a lab exam.
  /// What to fall back on when the calendar words the FAT differently.
  static DateTime? examStart(List<CalendarMonth> months, DateTime from) {
    final start = DateTime(from.year, from.month, from.day);
    DateTime? best;
    for (final month in months) {
      for (final chip in month.chips) {
        if (chip.kind != CalendarDayKind.exam) continue;
        if (chip.date.isBefore(start)) continue;
        if (_isLabExam(chip)) continue;
        if (best == null || chip.date.isBefore(best)) best = chip.date;
      }
    }
    return best;
  }

  static bool _isLabExam(CalendarChip chip) =>
      RegExp(r'\blab\b').hasMatch(chip.title.toLowerCase());

  static String _text(CalendarChip chip) =>
      '${chip.title} ${chip.subtitle ?? ''} ${chip.detail ?? ''}'.toLowerCase();
}
