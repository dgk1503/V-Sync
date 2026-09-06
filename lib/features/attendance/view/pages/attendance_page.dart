import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/common/widget/segmented_tab_switcher.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/attendance/view/widgets/attendance_course_card.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/attendance_viewmodel.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  AttendancePageState createState() => AttendancePageState();
}

class AttendancePageState extends ConsumerState<AttendancePage>
    with SingleTickerProviderStateMixin {
  DateTime? lastSynced;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadLastSynced();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadLastSynced() async {
    final prefs = ref.read(userPreferencesProvider);
    final DateTime? lastSyncedString = prefs.attendanceLastSync;
    if (lastSyncedString != null) {
      setState(() {
        lastSynced = lastSyncedString;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldRefresh()) {
        refreshAttendanceData(silentRefresh: true);
      }
    });
  }

  Future<void> saveLastSynced() async {
    final prefs = ref.read(userPreferencesProvider);
    await ref
        .read(userPreferencesProvider.notifier)
        .updatePreferences(prefs.copyWith(attendanceLastSync: lastSynced!));
  }

  Future<void> refreshAttendanceData({bool silentRefresh = false}) async {
    await ref
        .read(attendanceViewModeProvider.notifier)
        .refreshAttendance(silentRefresh: silentRefresh);
    final state = ref.read(attendanceViewModeProvider);
    if (state != null && !state.hasError) {
      lastSynced = DateTime.now();
      await saveLastSynced();
    }
  }

  bool _shouldRefresh() {
    if (lastSynced == null) return true;
    final difference = DateTime.now().difference(lastSynced!);
    return difference.inHours >= 24;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final isLoading = ref.watch(
      attendanceViewModeProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(attendanceViewModeProvider, (_, next) {
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
        child: isLoading
            ? const Loader()
            : Column(
                children: [
                  const SizedBox(height: 12),
                  if (lastSynced != null)
                    Text(
                      'Last synced ${timeago.format(lastSynced!)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Capsule segmented control for Theory / Lab.
                  SegmentedTabSwitcher(
                    controller: _tabController,
                    labels: const ['Theory', 'Lab'],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBody(user, 'Theory'),
                        _buildBody(user, 'Lab'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBody(User? user, String courseTypeFilter) {
    // Pull-to-refresh works in every state (list, empty view, error view).
    return RefreshIndicator(
      onRefresh: () => refreshAttendanceData(silentRefresh: true),
      child: _buildBodyContent(user, courseTypeFilter),
    );
  }

  Widget _buildBodyContent(User? user, String courseTypeFilter) {
    if (user == null) {
      return const ErrorContentView(error: 'User not found!');
    }

    final attendances = user.attendance.toList();

    final filteredAttendances = attendances.where((attendance) {
      return attendance.courseType.contains(courseTypeFilter);
    }).toList();

    if (filteredAttendances.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: EmptyContentView(
              primaryText: 'No $courseTypeFilter Courses found',
              secondaryText: 'Feels so empty',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      itemCount: filteredAttendances.length,
      itemBuilder: (context, index) {
        final attendance = filteredAttendances[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            children: [
              Flexible(child: AttendanceCourseCard(attendance: attendance)),
            ],
          ),
        );
      },
    );
  }
}
