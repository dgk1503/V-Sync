import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const _cardHeight = 148.0;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final venue = entry.classInfo.venue?.trim();
    final locationLabel = venue == null || venue.isEmpty ? 'N/A' : venue;
    final totalSeconds = entry.end.difference(entry.start).inSeconds;
    final elapsedSeconds = now.difference(entry.start).inSeconds;
    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();
    final minutesUntil = entry.start.difference(now).inMinutes;
    final statusLabel = entry.isOngoing
        ? 'ONGOING'
        : 'NEXT · IN ${_formatTimeUntil(minutesUntil)}';

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.isOngoing)
              _AnimatedClassProgressBar(
                progress: progress,
                animate: animateProgress,
                color: colorScheme.tertiary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              )
            else
              const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      entry.classInfo.courseName?.trim().isNotEmpty == true
                          ? entry.classInfo.courseName!.trim()
                          : 'Class',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
