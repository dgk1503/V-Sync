import 'package:vit_ap_student_app/features/attendance/model/attendance_projection.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';

/// When teaching ends, read off the academic calendar.
///
/// Pure on purpose, like the skip planner: it reads only the months it is
/// handed.
class TermEnd {
  const TermEnd._();

  /// The last day of teaching: the start of the theory FAT, or the last day the
  /// calendar covers when it lists none.
  ///
  /// Lab FAT days do not count: they are teaching days with a lab exam in them,
  /// and teaching carries on through them. The terminal attendance projection
  /// counts classes up to this day, because that is the number that still has to
  /// be above 75% on the last day of class.
  static ({DateTime date, bool isFat})? of(
    List<CalendarMonth> months,
    DateTime now,
  ) {
    if (months.isEmpty) return null;

    final fatDate = AttendanceProjection.fatStart(months, now);
    if (fatDate != null) return (date: fatDate, isFat: true);

    // No FAT listed: fall back to the latest day the calendar covers, which is
    // the best available answer for "the end of term".
    final last = months.last;
    var lastDay = DateTime(last.year, last.month);
    for (final chip in last.chips) {
      if (chip.date.isAfter(lastDay)) lastDay = chip.date;
    }
    return (date: lastDay, isFat: false);
  }
}
