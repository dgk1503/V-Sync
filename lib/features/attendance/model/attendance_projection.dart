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
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
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
          .where((entry) => (entry.courseCode ?? '').trim() == courseCode.trim())
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

  static String _text(CalendarChip chip) =>
      '${chip.title} ${chip.subtitle ?? ''} ${chip.detail ?? ''}'.toLowerCase();
}
