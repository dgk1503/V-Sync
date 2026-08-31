import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/utils/get_classes.dart';
import 'package:vit_ap_student_app/features/timetable/view/widgets/schedule_list.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage>
    with TickerProviderStateMixin {
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  TabController? _tabController;

  /// Indices (0 = Sunday ... 6 = Saturday) of days that actually have classes.
  List<int> _getActiveDays(Timetable timetable) {
    final active = <int>[];
    for (var i = 0; i < 7; i++) {
      if (getClassesForDay(timetable, _dayNames[i]).isNotEmpty) {
        active.add(i);
      }
    }
    return active;
  }

  void _syncTabController(List<int> activeDays) {
    if (_tabController?.length == activeDays.length) return;
    _tabController?.dispose();

    // Open on today if it has classes, otherwise the next upcoming
    // day that does.
    final today = DateTime.now().weekday % 7;
    var initialIndex = activeDays.indexOf(today);
    if (initialIndex == -1) {
      initialIndex = 0;
      for (var i = 0; i < activeDays.length; i++) {
        if (activeDays[i] > today) {
          initialIndex = i;
          break;
        }
      }
    }

    _tabController = TabController(
      length: activeDays.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  Future<void> refresh() async {
    await ref.read(timetableViewModelProvider.notifier).refreshTimetable();
  }

  String _buildSubtitle(Timetable timetable, int dayIndex) {
    final classes = getClassesForDay(timetable, _dayNames[dayIndex]);
    if (classes.isEmpty) return 'No classes';

    final labs = classes.where(isLabClass).length;
    final theory = classes.length - labs;

    final parts = <String>[];
    if (labs > 0) parts.add('$labs lab${labs == 1 ? '' : 's'}');
    if (theory > 0) {
      parts.add('$theory theor${theory == 1 ? 'y' : 'y'} class'
          '${theory == 1 ? '' : 'es'}');
    }

    final isToday = dayIndex == DateTime.now().weekday % 7;
    final suffix = isToday ? 'today' : 'on ${_dayNames[dayIndex]}';
    return 'You have ${parts.join(', ')} $suffix';
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final timetable = user?.timetable.target;

    final isLoading = ref.watch(
      timetableViewModelProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(timetableViewModelProvider, (_, next) {
      next?.when(
        data: (data) {},
        loading: () {},
        error: (error, st) {},
      );
    });

    if (user == null || timetable == null) {
      return const Scaffold(
        body: Center(child: Text('User not found!')),
      );
    }

    final activeDays = _getActiveDays(timetable);
    _syncTabController(activeDays);
    final controller = _tabController!;
    final colorScheme = Theme.of(context).colorScheme;

    // Aura color follows the accent theme (tertiary carries the accent
    // in gold/pink/red/emerald; monochrome falls back to primary).
    final auraColor = colorScheme.tertiary == colorScheme.primary
        ? colorScheme.primary
        : colorScheme.tertiary;

    return Scaffold(
      body: activeDays.isEmpty
          ? _buildCompletelyEmpty(context)
          : Stack(
              children: [
                // Subtle theme-colored aura behind the day strip.
                Positioned(
                  top: -140,
                  left: -60,
                  right: -60,
                  child: IgnorePointer(
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            auraColor.withValues(alpha: 0.30),
                            auraColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        // Track the swipe live instead of waiting for the
                        // page to settle.
                        final liveIndex = (controller.animation?.value ??
                                controller.index.toDouble())
                            .round()
                            .clamp(0, activeDays.length - 1);
                        return Column(
                          children: [
                            Row(
                              children: [
                                for (var i = 0; i < activeDays.length; i++)
                                  Expanded(
                                    child: _buildDayChip(
                                      context,
                                      letter: _dayLetters[activeDays[i]],
                                      isSelected: liveIndex == i,
                                      onTap: () => controller.animateTo(i),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _buildSubtitle(
                                  timetable, activeDays[liveIndex]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFB3B3B3)
                                    : const Color(0xFF4D4D4D),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoading
                        ? const Loader()
                        : TabBarView(
                            controller: controller,
                            physics: const BouncingScrollPhysics(),
                            children: [
                             for (final dayIndex in activeDays)
                                 ScheduleList(
                                   day: _dayNames[dayIndex],
                                   onRefresh: refresh,
                                 ),
                             ],
                           ),
                   ),
                 ],
               ),
             ),
           ],
         ),
      );
   }

  Widget _buildDayChip(
    BuildContext context, {
    required String letter,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? colorScheme.primary : Colors.transparent,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletelyEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.calendar_circle,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No classes this week',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
