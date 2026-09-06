import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/common/widget/segmented_tab_switcher.dart';
import 'package:vit_ap_student_app/core/models/exam_schedule.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/utils/exam_schedule/exam_schedule_utils.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/exam_schedule/exam_schedule_tab_view.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/exam_schedule_viewmodel.dart';

class ExamSchedulePage extends ConsumerStatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  ConsumerState<ExamSchedulePage> createState() => _MyExamScheduleState();
}

class _MyExamScheduleState extends ConsumerState<ExamSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? lastSynced;
  bool _hasAutoSelectedTab = false;

  @override
  void initState() {
    super.initState();
    loadLastSynced();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void loadLastSynced() {
    final prefs = ref.read(userPreferencesProvider);
    final DateTime? lastSyncedString = prefs.examScheduleLastSync;
    if (lastSyncedString != null) {
      setState(() {
        lastSynced = lastSyncedString;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshExamSchedule();
    });
  }

  Future<void> saveLastSynced() async {
    final prefs = ref.read(userPreferencesProvider);
    await ref
        .read(userPreferencesProvider.notifier)
        .updatePreferences(prefs.copyWith(examScheduleLastSync: lastSynced!));
  }

  Future<void> refreshExamSchedule() async {
    await ref
        .read(examScheduleViewModelProvider.notifier)
        .refreshExamSchedule();
    // Only stamp "last synced" when the refresh actually succeeded.
    final state = ref.read(examScheduleViewModelProvider);
    if (state != null && !state.hasError) {
      lastSynced = DateTime.now();
      await saveLastSynced();
    }
  }

  void _autoSelectUpcomingTab(List<ExamSchedule> schedule) {
    if (_hasAutoSelectedTab) return;
    if (schedule.isEmpty) return;

    final targetIndex = findUpcomingExamTabIndex(schedule);
    _hasAutoSelectedTab = true;

    if (targetIndex != null && targetIndex != _tabController.index && mounted) {
      _tabController.animateTo(targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    final examSchedule = user?.examSchedule;
    final examScheduleList = examSchedule?.toList() ?? [];

    final isLoading = ref.watch(
      examScheduleViewModelProvider.select((val) => val?.isLoading == true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectUpcomingTab(examScheduleList);
    });

    ref.listen(examScheduleViewModelProvider, (_, next) {
      next?.when(
        data: (data) {},
        loading: () {},
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: user == null
            ? const ErrorContentView(error: 'User not found!')
            : isLoading
                ? const Loader()
                : RefreshIndicator(
                    onRefresh: refreshExamSchedule,
                    notificationPredicate: (notification) =>
                        notification.depth == 1,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        if (lastSynced != null)
                          Text(
                            'Last synced ${timeago.format(lastSynced!)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Capsule segmented control for CAT-1 / CAT-2 / FAT.
                        SegmentedTabSwitcher(
                          controller: _tabController,
                          labels: const ['CAT - 1', 'CAT - 2', 'FAT'],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ExamScheduleTabView(
                            tabController: _tabController,
                            examSchedule: examScheduleList,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
