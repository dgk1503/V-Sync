import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';

/// The semester's academic calendar: a month grid whose day chips are coloured
/// by what the day is, with the month's events listed underneath.
///
/// Countdowns are the user's own, so merging them is a preference. The toggle
/// lives above the calendar (and mirrors the same setting in Settings >
/// Customization) rather than being buried in the app bar.
class AcademicCalendarPage extends ConsumerStatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  ConsumerState<AcademicCalendarPage> createState() =>
      _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends ConsumerState<AcademicCalendarPage> {
  /// Null until the month list arrives, so the first month shown is the one
  /// containing today rather than whichever month VTOP happened to list first.
  /// Once chosen it sticks, so an automatic re-render cannot move the user off
  /// the month they navigated to.
  int? _monthIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    ref
        .read(calendarViewmodelProvider.notifier)
        .ensureLoaded();
  }

  /// The month to show, preferring the one containing today.
  int _resolveMonthIndex(List<CalendarMonth> months) {
    if (months.isEmpty) return 0;
    final chosen = _monthIndex;
    if (chosen != null) return chosen.clamp(0, months.length - 1);

    final now = DateTime.now();
    final today = months.indexWhere(
      (m) => m.year == now.year && m.month == now.month,
    );
    final resolved = today >= 0 ? today : 0;
    _monthIndex = resolved;
    return resolved;
  }

  /// Turns a repository failure into something worth reading.
  ///
  /// The raw messages are VTOP's own wording ("Failed to fetch academic
  /// calendar: ..."), which tells the user nothing they can act on. The two
  /// cases that actually happen get a plain sentence; anything else is passed
  /// through rather than hidden.
  static String _friendlyError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('internet') || lower.contains('network') || lower.contains('socket')) {
      return "You're offline. Check your connection and try again.";
    }
    if (lower.contains('user not found')) {
      return 'Your session expired. Log out and log in again.';
    }
    if (lower.contains('otp')) {
      return 'Verify your email to finish loading the calendar.';
    }
    return text;
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final monthsAsync = ref.watch(calendarViewmodelProvider);
    final cacheKey = ref.watch(calendarViewmodelProvider.notifier).resolvedCacheKey;
    final updatedAt = cacheKey == null
        ? null
        : ref.watch(dataCacheServiceProvider).readEntry(cacheKey)?.updatedAt;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Academic Calendar',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 26,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: monthsAsync.when(
        // `skipLoadingOnReload` matters more than it looks: without it a
        // background refresh flips the whole page back to a spinner even
        // though a full calendar is sitting right there. `when` shows the
        // loading branch on ANY transition into AsyncLoading, so the guard
        // below is what keeps the screen steady while VTOP is asked again.
        skipLoadingOnReload: monthsAsync.hasValue,
        skipError: monthsAsync.hasValue && monthsAsync.hasError == false,
        loading: () => const _CalendarSkeleton(),
        error: (error, _) => _ErrorState(
          message: _friendlyError(error),
          onRetry: _load,
          isError: true,
        ),
        data: (months) {
          if (months.isEmpty) {
            return _ErrorState(
              message: 'No academic calendar published yet.',
              onRetry: _load,
            );
          }
          final index = _resolveMonthIndex(months);
          final month = months[index];
          return _Body(
            month: month,
            months: months,
            monthIndex: index,
            updatedAt: updatedAt,
            onMonthChanged: (value) => setState(() => _monthIndex = value),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CalendarMonth month;
  final List<CalendarMonth> months;
  final int monthIndex;
  final int? updatedAt;
  final ValueChanged<int> onMonthChanged;

  const _Body({
    required this.month,
    required this.months,
    required this.monthIndex,
    required this.updatedAt,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Plain teaching days are noise, and so are VTOP's filler Sundays: it
    // marks every Sunday as a holiday with the note "Holiday", which put eight
    // identical rows in every month. Both are dropped; named holidays and real
    // closures stay.
    final events = month.chips
        .where(
          (chip) =>
              chip.kind != CalendarDayKind.instructional &&
              !CalendarEventClassifier.isOrdinarySunday(chip),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month grid ──
          _MonthCard(
            month: month,
            canGoBack: monthIndex > 0,
            canGoForward: monthIndex < months.length - 1,
            onBack: () => onMonthChanged(monthIndex - 1),
            onForward: () => onMonthChanged(monthIndex + 1),
          ),
          const SizedBox(height: 24),

          // ── Events ──
          Text(
            month.label,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${events.length} ${events.length == 1 ? 'event' : 'events'}',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nothing scheduled this month.',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final event in events) ...[
              _EventRow(event: event),
              const SizedBox(height: 10),
            ],

          // How old the copy on screen is. With a five day cache a calendar can
          // legitimately be days behind, and the user should be able to tell
          // that apart from a fresh one.
          _UpdatedFooter(updatedAt: updatedAt),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final CalendarMonth month;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _MonthCard({
    required this.month,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant, width: 0.75),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _NavButton(icon: Icons.chevron_left, onTap: canGoBack ? onBack : null),
              Expanded(
                child: Center(
                  child: Text(
                    month.label,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
              _NavButton(icon: Icons.chevron_right, onTap: canGoForward ? onForward : null),
            ],
          ),
          const SizedBox(height: 16),
          // Sunday-first, matching VTOP's own calendar grid.
          Row(
            children: [
              for (final letter in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
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
          _MonthGrid(month: month),
        ],
      ),
    );
  }
}

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
      icon: Icon(icon, size: 20, color: onTap == null ? colors.outline : colors.onSurface),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final CalendarMonth month;

  const _MonthGrid({required this.month});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = month.firstDay;
    // Monday-first index: DateTime.monday == 1.
    // Sunday-first: DateTime.sunday == 7, so the first column is 0 for a
    // Sunday and 6 for a Saturday. Monday-first was `weekday - 1`.
    final leadingBlanks = first.weekday % 7;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((leadingBlanks + dayCount + 6) ~/ 7) * 7;
    final today = DateTime.now();

    return Column(
      children: [
        for (var row = 0; row < totalCells ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cell = row * 7 + column;
                        final day = cell - leadingBlanks + 1;
                        if (day < 1 || day > dayCount) {
                          return const SizedBox(height: 38);
                        }
                        final date = DateTime(month.year, month.month, day);
                        return _DayCell(
                          date: date,
                          chips: month.chipsOn(date),
                          isToday: date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day,
                          muted: colors.onSurfaceVariant,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;

  /// Every chip on this date, not just the leading one, so a countdown sharing
  /// a day with a VTOP entry is not lost.
  final List<CalendarChip> chips;
  final bool isToday;
  final Color muted;

  const _DayCell({
    required this.date,
    required this.chips,
    required this.isToday,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Every chip on the day is considered, not just the leading one, so a
    // countdown sharing a date with a VTOP entry is not lost.
    final kind = CalendarEventClassifier.ringKindFor(chips);
    final tint = kind == null
        ? null
        : CalendarEventClassifier.colorFor(context, kind);

    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint?.withValues(alpha: 0.14),
          border: Border.all(
            color: tint ?? Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
            color: tint == null
                ? muted
                : isToday
                    ? tint
                    : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarChip event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = CalendarEventClassifier.colorFor(context, event.kind);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant, width: 0.75),
      ),
      child: Row(
        children: [
          // Weekday column, matching the list in the reference design.
          SizedBox(
            width: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayShort(event.date.weekday).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.date.day}',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                if (event.detail != null && event.detail!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tint.withValues(alpha: 0.6), width: 1),
            ),
            child: Text(
              _kindLabel(event.kind),
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayShort(int weekday) => const [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
      ][weekday - 1];

  static String _kindLabel(CalendarDayKind kind) => switch (kind) {
    CalendarDayKind.instructional => 'Class',
    CalendarDayKind.holiday => 'Holiday',
    CalendarDayKind.noClasses => 'No classes',
    CalendarDayKind.exam => 'Exam',
    CalendarDayKind.countdown => 'Countdown',
    CalendarDayKind.event => 'Event',
  };
}

/// Shown when there is nothing to display: no calendar published, or the fetch
/// failed. Always offers the one action that can fix it, because a dead end
/// with no button is the same as a crash from the user's side.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isError;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final accent = isError ? status.danger : colors.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isError ? Icons.cloud_off_rounded : Icons.event_busy_outlined,
                size: 26,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isError ? "Couldn't load the calendar" : 'No calendar yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isError ? 'Try again' : 'Check again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stand-in that mirrors the real page's shape - toggle row, month header,
/// a grid block and event rows - so the layout does not jump when the data
/// lands. A bare spinner reads as "broken"; a skeleton reads as "loading".
class _CalendarSkeleton extends StatefulWidget {
  const _CalendarSkeleton();

  @override
  State<_CalendarSkeleton> createState() => _CalendarSkeletonState();
}

class _CalendarSkeletonState extends State<_CalendarSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(controller: _controller, width: 150, height: 14, colors: colors),
            const SizedBox(height: 16),
            _Bar(controller: _controller, height: 300, radius: 16, colors: colors),
            const SizedBox(height: 18),
            for (var i = 0; i < 4; i++) ...[
              _Bar(
                controller: _controller,
                height: 54,
                radius: 14,
                colors: colors,
                delay: i * 0.12,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final AnimationController controller;
  final double width;
  final double height;
  final double radius;
  final ColorScheme colors;
  final double delay;

  const _Bar({
    required this.controller,
    required this.height,
    required this.colors,
    this.width = double.infinity,
    this.radius = 6,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Each bar breathes slightly out of step, so the block does not pulse
        // as one slab.
        final t = ((controller.value + delay) % 1.0).clamp(0.0, 1.0);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(
              colors.surfaceContainerHighest,
              colors.surfaceContainerHigh,
              t,
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }
}

/// "Updated 5 min ago" - how old the copy on screen is, so a stale calendar is
/// never mistaken for a current one.
class _UpdatedFooter extends StatelessWidget {
  final int? updatedAt;

  const _UpdatedFooter({required this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final millis = updatedAt;
    if (millis == null || millis <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Text(
          _describe(DateTime.now().millisecondsSinceEpoch - millis),
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static String _describe(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    if (seconds < 60) return 'Updated just now';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return 'Updated $minutes min ago';
    final hours = (minutes / 60).round();
    if (hours < 24) return 'Updated ${hours}h ago';
    final days = (hours / 24).round();
    if (days < 7) return 'Updated ${days}d ago';
    return 'Updated ${(days / 7).floor()}w ago';
  }
}