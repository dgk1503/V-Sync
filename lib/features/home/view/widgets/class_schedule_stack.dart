import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/providers/bottom_nav_provider.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/utils/get_classes.dart';

class ClassScheduleEntry {
  const ClassScheduleEntry({
    required this.classInfo,
    required this.start,
    required this.end,
    required this.isOngoing,
    required this.scheduleIndex,
  });

  final Day classInfo;
  final DateTime start;
  final DateTime end;
  final bool isOngoing;
  final int scheduleIndex;
}

List<ClassScheduleEntry> buildClassScheduleEntries(
  List<Day> classes, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final entries = <ClassScheduleEntry>[];

  for (final classInfo in classes) {
    final start = _dateFromTime(anchor, classInfo.startTime);
    if (start == null) continue;
    var end = _dateFromTime(anchor, classInfo.endTime);
    if (end == null || !end.isAfter(start)) {
      end = start.add(const Duration(minutes: 50));
    }
    entries.add(
      ClassScheduleEntry(
        classInfo: classInfo,
        start: start,
        end: end,
        isOngoing: !anchor.isBefore(start) && anchor.isBefore(end),
        scheduleIndex: 0,
      ),
    );
  }

  entries.sort((a, b) {
    if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
    return a.start.compareTo(b.start);
  });
  final remaining = entries
      .where((entry) => entry.isOngoing || entry.start.isAfter(anchor))
      .toList(growable: false);
  return [
    for (var index = 0; index < remaining.length; index++)
      ClassScheduleEntry(
        classInfo: remaining[index].classInfo,
        start: remaining[index].start,
        end: remaining[index].end,
        isOngoing: remaining[index].isOngoing,
        scheduleIndex: index,
      ),
  ];
}

String _formatTimeUntil(int minutes) {
  final safeMinutes = minutes < 0 ? 0 : minutes;
  if (safeMinutes < 60) return '$safeMinutes MIN';
  final hours = safeMinutes ~/ 60;
  final remainingMinutes = safeMinutes % 60;
  final hourLabel = hours == 1 ? 'HR' : 'HRS';
  if (remainingMinutes == 0) return '$hours $hourLabel';
  return '$hours $hourLabel $remainingMinutes MIN';
}

/// "23 min left", "1 hr 5 min left". Rounded up, so a class never reads "0 min
/// left" while it is still on.
String _formatTimeLeft(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil().clamp(0, 24 * 60);
  if (minutes < 60) return '$minutes min left';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr left' : '$hours hr $rest min left';
}

/// "9:50 – 10:40 AM", or "11:30 AM – 12:20 PM" when the two sit either side of
/// noon, where dropping the first suffix would be ambiguous.
String _formatRange(DateTime start, DateTime end) {
  final first = DateFormat('h:mm').format(start);
  final last = DateFormat('h:mm a').format(end);
  final samePeriod = (start.hour < 12) == (end.hour < 12);
  return samePeriod
      ? '$first – $last'
      : '${DateFormat('h:mm a').format(start)} – $last';
}

DateTime? _dateFromTime(DateTime date, String? value) {
  if (value == null) return null;
  final parts = value.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

bool _sameClassList(List<Day> first, List<Day> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    final a = first[index];
    final b = second[index];
    if (a.id != b.id ||
        a.courseName != b.courseName ||
        a.venue != b.venue ||
        a.startTime != b.startTime ||
        a.endTime != b.endTime) {
      return false;
    }
  }
  return true;
}

class ClassScheduleSection extends ConsumerStatefulWidget {
  const ClassScheduleSection({super.key});

  @override
  ConsumerState<ClassScheduleSection> createState() =>
      _ClassScheduleSectionState();
}

class _ClassScheduleSectionState extends ConsumerState<ClassScheduleSection> {
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final _stackKey = GlobalKey<ClassScheduleStackState>();

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(userPreferencesProvider);
    final user = ref.watch(currentUserProvider);
    final timetable = user?.timetable.target;
    final now = DateTime.now();
    final classes = timetable == null
        ? const <Day>[]
        : getClassesForDay(timetable, _dayNames[now.weekday % 7]);

    ref.listen<int>(bottomNavIndexProvider, (previous, next) {
      if (previous == 0 && next != 0) {
        _stackKey.currentState?.resetInstantly();
      } else if (next == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _stackKey.currentState?.resetInstantly();
        });
      }
    });

    if (!preferences.classStackEnabled) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: AccentGradientText(
            'Classes',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ClassScheduleStack(key: _stackKey, classes: classes),
      ],
    );
  }
}

class ClassScheduleStack extends StatefulWidget {
  const ClassScheduleStack({super.key, required this.classes, this.now});

  final List<Day> classes;
  final DateTime? now;

  @override
  State<ClassScheduleStack> createState() => ClassScheduleStackState();
}

class ClassScheduleStackState extends State<ClassScheduleStack>
    with WidgetsBindingObserver {
  static const _cardHeight = 176.0;
  static const _dotsHeight = 18.0;

  late final PageController _pageController;
  late DateTime _now;
  late List<ClassScheduleEntry> _ordered;
  int _currentPage = 0;
  Timer? _minuteTicker;

  ClassScheduleEntry get currentEntry => _ordered[_currentPage];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = widget.now ?? DateTime.now();
    _ordered = List<ClassScheduleEntry>.of(
      buildClassScheduleEntries(widget.classes, now: _now),
    );
    _pageController = PageController();
    if (widget.now == null) {
      _minuteTicker = Timer.periodic(const Duration(seconds: 15), (_) {
        _refresh(resetOrder: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ClassScheduleStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameClassList(oldWidget.classes, widget.classes) ||
        oldWidget.now != widget.now) {
      _now = widget.now ?? DateTime.now();
      _ordered = List<ClassScheduleEntry>.of(
        buildClassScheduleEntries(widget.classes, now: _now),
      );
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resetInstantly();
  }

  void _refresh({required bool resetOrder}) {
    if (!mounted) return;
    final now = DateTime.now();
    final next = buildClassScheduleEntries(widget.classes, now: now);
    setState(() {
      _now = now;
      if (resetOrder) {
        _ordered = List<ClassScheduleEntry>.of(next);
        _currentPage = 0;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      }
    });
  }

  void resetInstantly() {
    if (!mounted) return;
    final now = widget.now ?? DateTime.now();
    _ordered = List<ClassScheduleEntry>.of(
      buildClassScheduleEntries(widget.classes, now: now),
    );
    _currentPage = 0;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    setState(() {});
  }

  void _handlePageChanged(int page) {
    if (!mounted) return;
    setState(() => _currentPage = page);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTicker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ordered.isEmpty) {
      return const SizedBox(
        height: _cardHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _FreeDayCard(),
        ),
      );
    }

    final hasMultipleCards = _ordered.length > 1;
    final sliderHeight = _cardHeight + (hasMultipleCards ? _dotsHeight : 0);

    return SizedBox(
      height: sliderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              height: _cardHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _ordered.length,
                onPageChanged: _handlePageChanged,
                itemBuilder: (context, index) => SizedBox(
                  height: _cardHeight,
                  child: _ClassScheduleCard(
                    entry: _ordered[index],
                    now: _now,
                    animateProgress: widget.now == null,
                  ),
                ),
              ),
            ),
            if (hasMultipleCards) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: _dotsHeight - 10,
                child: Center(
                  child: _StackDots(
                    count: _ordered.length,
                    activeIndex: _currentPage,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StackDots extends StatelessWidget {
  const _StackDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          Container(
            width: index == activeIndex ? 5 : 4,
            height: 4,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? colorScheme.tertiary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _FreeDayCard extends StatelessWidget {
  const _FreeDayCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_twilight_rounded,
              size: 26,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Free for the rest of the day',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No more scheduled classes today',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedClassProgressBar extends StatefulWidget {
  const _AnimatedClassProgressBar({
    required this.progress,
    required this.animate,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final bool animate;
  final Color color;
  final Color backgroundColor;

  @override
  State<_AnimatedClassProgressBar> createState() =>
      _AnimatedClassProgressBarState();
}

class _AnimatedClassProgressBarState extends State<_AnimatedClassProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.progress;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _animation = AlwaysStoppedAnimation<double>(_value);
  }

  @override
  void didUpdateWidget(covariant _AnimatedClassProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == widget.progress) return;

    _animation = Tween<double>(
      begin: _value,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller
      ..duration = widget.animate ? const Duration(seconds: 15) : Duration.zero
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _value = _animation.value;
        return LinearProgressIndicator(
          value: _value,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
          color: widget.color,
          backgroundColor: widget.backgroundColor,
        );
      },
    );
  }
}

class _ClassScheduleCard extends StatelessWidget {
  const _ClassScheduleCard({
    required this.entry,
    required this.now,
    required this.animateProgress,
  });

  final ClassScheduleEntry entry;
  final DateTime now;
  final bool animateProgress;

  bool get _isLab {
    final type = (entry.classInfo.courseType ?? '').trim().toLowerCase();
    return type == 'ela' || type == 'lo' || type.contains('lab');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final venue = entry.classInfo.venue?.trim();
    final locationLabel = venue == null || venue.isEmpty ? 'N/A' : venue;
    final code = entry.classInfo.courseCode?.trim() ?? '';
    final totalSeconds = entry.end.difference(entry.start).inSeconds;
    final elapsedSeconds = now.difference(entry.start).inSeconds;
    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();
    final minutesUntil = entry.start.difference(now).inMinutes;
    final statusLabel = entry.isOngoing
        ? 'ONGOING'
        : 'NEXT · IN ${_formatTimeUntil(minutesUntil)}';

    TextStyle caption([Color? color]) => TextStyle(
      fontFamily: 'Instrument Sans',
      fontSize: 13,
      color: color ?? colorScheme.onSurfaceVariant,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The class on now is the selected state, so it wears the same
              // filled pill as every other selected control; the next one is
              // the quiet version.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: entry.isOngoing
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.isOngoing) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                        color: entry.isOngoing
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(_formatRange(entry.start, entry.end), style: caption()),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.classInfo.courseName?.trim().isNotEmpty == true
                ? entry.classInfo.courseName!.trim()
                : 'Class',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  code.isEmpty ? locationLabel : '$locationLabel  ·  $code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption(),
                ),
              ),
              if (_isLab) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'LAB',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          if (entry.isOngoing) ...[
            _AnimatedClassProgressBar(
              progress: progress,
              animate: animateProgress,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(_formatTimeLeft(entry.end.difference(now)), style: caption()),
          ] else
            Text(
              'Starts at ${DateFormat('h:mm a').format(entry.start)}',
              style: caption(),
            ),
        ],
      ),
    );
  }
}
