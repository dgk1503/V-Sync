import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_detail.dart';

/// Why there is nothing to draw in the month grid.
enum EmptyReason { loading, failed, notPosted }

/// A month of day-wise attendance for one course.
///
/// Attended classes get a green ring, missed ones a red ring, and days with no
/// class stay plain. Only months that actually contain a marked class are
/// rendered, so a course with sparse history does not show empty grids.
class AttendanceMonthCard extends StatefulWidget {
  final List<AttendanceDetail> details;

  /// Why the list is empty, when it is. "Loading", "could not reach VTOP" and
  /// "VTOP has not posted this yet" are three different situations and the user
  /// cannot act on any of them if they all read "no attendance posted".
  final EmptyReason emptyReason;

  const AttendanceMonthCard({
    super.key,
    required this.details,
    this.emptyReason = EmptyReason.notPosted,
  });

  @override
  State<AttendanceMonthCard> createState() => _AttendanceMonthCardState();
}

class _AttendanceMonthCardState extends State<AttendanceMonthCard> {
  final _controller = PageController();

  /// Null until the first month is chosen, so the grid can open on the current
  /// month rather than whichever one the records happen to start in. Once the
  /// user navigates, their choice sticks.
  int? _index;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // day -> status. A day can hold several classes; attended wins so a
    // partially attended day is not shown as a miss.
    final byDay = <DateTime, bool>{};
    for (final detail in widget.details) {
      final date = _parseDate(detail.date);
      if (date == null) continue;
      final attended = detail.status.toLowerCase() == 'present';
      byDay[date] = (byDay[date] ?? false) || attended;
    }
    if (byDay.isEmpty) {
      final message = switch (widget.emptyReason) {
        EmptyReason.loading => 'Loading your attendance history...',
        EmptyReason.failed => "Couldn't reach VTOP for this course.",
        EmptyReason.notPosted => 'No day-wise attendance posted yet.',
      };
      final status = AppStatusColors.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (widget.emptyReason == EmptyReason.loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (widget.emptyReason == EmptyReason.failed) ...[
              Icon(
                Icons.cloud_off_rounded,
                size: 15,
                color: status.danger,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Group the marked days by month, keeping them in order.
    final months = <(int, int), List<DateTime>>{};
    for (final date in byDay.keys) {
      months.putIfAbsent((date.year, date.month), () => []).add(date);
    }
    // Sorted by hand: the key is a `(year, month)` record, and Dart records do
    // not implement Comparable, so a bare `..sort()` throws the moment there is
    // more than one month. With a single month it never compares anything,
    // which is why this only ever broke on real semesters.
    final keys = months.keys.toList()
      ..sort((a, b) {
        final byYear = a.$1.compareTo(b.$1);
        return byYear != 0 ? byYear : a.$2.compareTo(b.$2);
      });

    // A real semester spans several months, so listing every grid pushed the
    // summary off the page. One month at a time, opened on the current month.
    final index = _resolveIndex(keys);
    final key = keys[index];
    final monthDays = months[key]!;
    final attendedCount = monthDays.where((d) => byDay[d] ?? false).length;

    return Column(
      children: [
        Row(
          children: [
            _NavButton(
              icon: Icons.chevron_left,
              onTap: index > 0
                  ? () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                      setState(() => _index = index - 1);
                    }
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _monthLabel(key.$1, key.$2),
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right,
              onTap: index < keys.length - 1
                  ? () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                      setState(() => _index = index + 1);
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '$attendedCount of ${monthDays.length} classes attended',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Monday-first weekday header, matching the timetable.
        Row(
          children: [
            for (final letter in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // A PageView inside a scrolling Column is given an unbounded height and
        // lays out to nothing, so the shown month's height is computed and
        // animated. Without this the grid silently disappears.
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          height: _MonthGrid.heightFor(key.$1, key.$2),
          child: PageView.builder(
            controller: _controller,
            itemCount: keys.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => _MonthGrid(
              year: keys[index].$1,
              month: keys[index].$2,
              days: months[keys[index]]!,
              attended: byDay,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: AppStatusColors.of(context).success, label: 'Attended'),
            const SizedBox(width: 16),
            _Legend(color: colors.error, label: 'Missed'),
            if (keys.length > 1) ...[
              const SizedBox(width: 16),
              Text(
                '${index + 1}/${keys.length}',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The month to open on: this month if the course has records for it, and
  /// otherwise the most recent one, since attendance only ever accumulates.
  int _resolveIndex(List<(int, int)> keys) {
    final chosen = _index;
    if (chosen != null && chosen >= 0 && chosen < keys.length) return chosen;

    final now = DateTime.now();
    final thisMonth = keys.indexWhere(
      (k) => k.$1 == now.year && k.$2 == now.month,
    );
    final resolved = thisMonth >= 0 ? thisMonth : keys.length - 1;
    _index = resolved;
    return resolved;
  }

  static String _monthLabel(int year, int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[month - 1]} $year';
  }

  /// Reads a date out of whatever VTOP put in the cell.
  ///
  /// The scraper hands over the raw cell text, so the separator is not ours to
  /// choose: it has appeared as `02/10/2026`, `02-10-2026` and `02 Oct 2026`.
  /// Requiring one separator meant every record was discarded and the card
  /// reported "no attendance posted" for a course that had plenty.
  ///
  /// `dd-mm-yyyy` is VTOP's convention, so an ambiguous date like `02-03-2026`
  /// is read as 2 March. When the first number cannot be a day (>12) the field
  /// is obviously month-first, and that is handled rather than guessed.
  static const List<String> _months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static DateTime? _parseDate(String raw) {
    final numbers = RegExp(r'\d+')
        .allMatches(raw)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .toList();

    // A spelled-out month leaves only a day and a year in the digits, so the
    // month has to come from the words: "02 Oct 2026".
    final namedMonth = _months.indexWhere(
      (name) => raw.toLowerCase().contains(name.substring(0, 3)),
    );

    int year;
    int month;
    int day;

    if (namedMonth >= 0) {
      month = namedMonth + 1;
      day = numbers.isNotEmpty ? numbers[0] : 0;
      year = numbers.length > 1 ? numbers[1] : 0;
      if (year < 100) year += 2000;
      if (day < 1 || day > 31 || year < 1900) return null;
      final parsed = DateTime(year, month, day);
      if (parsed.day != day) return null;
      return parsed;
    }

    if (numbers.length < 3) return null;

    if (numbers[0] > 31) {
      // yyyy-mm-dd
      year = numbers[0];
      month = numbers[1];
      day = numbers[2];
    } else if (numbers[0] > 12) {
      // Unambiguously day-first.
      day = numbers[0];
      month = numbers[1];
      year = numbers[2];
    } else if (numbers[1] > 12) {
      // Unambiguously month-first.
      month = numbers[0];
      day = numbers[1];
      year = numbers[2];
    } else {
      // Both plausible: VTOP writes day-first.
      day = numbers[0];
      month = numbers[1];
      year = numbers[2];
    }

    if (year < 100) year += 2000;
    // Reject impossible dates rather than letting DateTime roll them over:
    // 31 February must not silently become 3 March.
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.month != month || parsed.day != day) return null;
    return parsed;
  }
}

/// The month arrows, matching the academic calendar's header so the two
/// calendars feel like the same control.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: onTap == null ? colors.outline : colors.onSurface,
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final int year;
  /// How many week-rows a month needs, Monday-first.
  static int weeksIn(int year, int month) {
    final leading = DateTime(year, month).weekday - 1;
    final days = DateTime(year, month + 1, 0).day;
    return ((leading + days) / 7).ceil();
  }

  /// Height the grid needs for a month: its rows plus the container's padding.
  static double heightFor(int year, int month) =>
      34 + weeksIn(year, month) * 40;


  final int month;
  final List<DateTime> days;
  final Map<DateTime, bool> attended;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.days,
    required this.attended,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final first = DateTime(year, month);
    final leading = first.weekday - 1;
    final dayCount = DateTime(year, month + 1, 0).day;
    final cells = ((leading + dayCount + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant, width: 0.75),
      ),
      child: Column(
        children: [
          for (var row = 0; row < cells ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = row * 7 + column - leading + 1;
                          if (day < 1 || day > dayCount) {
                            return const SizedBox(height: 34);
                          }
                          final date = DateTime(year, month, day);
                          final marked = attended.containsKey(date);
                          final wasAttended = attended[date] ?? false;
                          return Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !marked
                                      ? Colors.transparent
                                      : wasAttended
                                      ? status.success
                                      : colors.error,
                                  width: 1.3,
                                ),
                              ),
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 12.5,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The "N left until FAT" caption that sits under the attendance ring.
///
/// The count itself is deliberately black — it is a neutral fact about the
/// course, not a warning — matching the reference design.
class ClassesLeftCaption extends StatelessWidget {
  final int? classesLeft;
  final String targetLabel;

  const ClassesLeftCaption({
    super.key,
    required this.classesLeft,
    this.targetLabel = 'FAT',
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = classesLeft;

    if (count == null || count <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'left until $targetLabel',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}