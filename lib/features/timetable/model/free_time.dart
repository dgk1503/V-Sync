import 'package:vit_ap_student_app/core/models/timetable.dart';

/// A stretch of free time between two classes.
class FreeGap {
  const FreeGap({required this.minutes, required this.startsAt});

  /// How long the gap is.
  final int minutes;

  /// Minutes since midnight at which the gap begins (the previous class ends).
  final int startsAt;

  /// "40 min", "1 hr", "1 hr 10 min".
  String get duration => formatFreeDuration(minutes);

  /// "Free for 1 hr 10 min".
  String get label => 'Free for $duration';
}

/// Free time inside a day's classes.
///
/// VIT leaves ten minutes between consecutive classes, so a gap that size is the
/// ordinary changeover and is not free time. Only a longer one is. Gaps are
/// measured from the *latest* end so far, so two classes that overlap, or one
/// that runs on past the next one's start, never produce a gap that is not there.
class FreeTime {
  const FreeTime._();

  /// The ordinary changeover between classes, in minutes. A gap has to be longer.
  static const int changeover = 10;

  /// The free gap before each class, by index: null for the first class and for
  /// a changeover that is not worth mentioning.
  ///
  /// [classes] must already be in start order.
  static List<FreeGap?> before(List<Day> classes) {
    final gaps = <FreeGap?>[];
    int? latestEnd;

    for (final entry in classes) {
      final start = _minutes(entry.startTime);
      final end = _minutes(entry.endTime);

      FreeGap? gap;
      if (latestEnd != null && start != null) {
        final minutes = start - latestEnd;
        if (minutes > changeover) {
          gap = FreeGap(minutes: minutes, startsAt: latestEnd);
        }
      }
      gaps.add(gap);

      // A class with no readable end still occupies its start.
      final reach = end ?? start;
      if (reach != null && (latestEnd == null || reach > latestEnd)) {
        latestEnd = reach;
      }
    }
    return gaps;
  }

  static int? _minutes(String? time) {
    if (time == null) return null;
    final parts = time.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}

/// "40 min", "1 hr", "2 hr 5 min".
String formatFreeDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}
