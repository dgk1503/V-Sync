import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/marks/dynamic_course_type_tab_bar.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/marks_detail_bottom_sheet.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/marks_viewmodel.dart';

class MarksPage extends ConsumerStatefulWidget {
  const MarksPage({super.key});

  @override
  ConsumerState<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends ConsumerState<MarksPage>
    with SingleTickerProviderStateMixin {
  DateTime? lastSynced;
  TabController? _tabController;
  List<String> _courseCategories = [];

  @override
  void initState() {
    super.initState();
    loadLastSynced();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabController(List<String> categories) {
    if (_courseCategories.length != categories.length ||
        !_courseCategories.every((e) => categories.contains(e))) {
      _tabController?.dispose();
      _courseCategories = categories;
      _tabController = TabController(length: categories.length, vsync: this);
    }
  }

  Future<void> loadLastSynced() async {
    final prefs = ref.read(userPreferencesProvider);
    final DateTime? lastSyncedString = prefs.marksLastSync;
    if (lastSyncedString != null) {
      setState(() {
        lastSynced = lastSyncedString;
      });
    }
  }

  Future<void> saveLastSynced() async {
    final prefs = ref.read(userPreferencesProvider);
    await ref
        .read(userPreferencesProvider.notifier)
        .updatePreferences(prefs.copyWith(marksLastSync: lastSynced!));
  }

  Future<void> refreshMarksData() async {
    await ref.read(marksViewModelProvider.notifier).refreshMarks();
    // Only stamp "last synced" when the refresh actually succeeded.
    final state = ref.read(marksViewModelProvider);
    if (state != null && !state.hasError) {
      lastSynced = DateTime.now();
      await saveLastSynced();
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = ref.watch(currentUserProvider);

    final isLoading = ref.watch(
      marksViewModelProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(marksViewModelProvider, (_, next) {
      next?.when(
        data: (data) {},
        loading: () {},
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
      );
    });

    // Extract unique course categories from user marks
    final courseTypes = user?.marks.map((m) => m.courseType).toList() ?? [];
    final categories = CourseTypeHelper.getUniqueCourseCategories(courseTypes);

    // Initialize tab controller if categories changed
    if (categories.isNotEmpty) {
      _initTabController(categories);
    }

    final hasTabs = _tabController != null && _courseCategories.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Loader()
            : RefreshIndicator(
                onRefresh: refreshMarksData,
                notificationPredicate: (notification) => notification.depth == 1,
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
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (hasTabs)
                      AnimatedBuilder(
                        animation: _tabController!,
                        builder: (context, _) {
                          // Track the swipe live instead of waiting for the
                          // page to settle.
                          final liveIndex =
                              (_tabController!.animation?.value ?? 0).round();
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  for (var i = 0;
                                      i < _courseCategories.length;
                                      i++)
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () =>
                                            _tabController!.animateTo(i),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          curve: Curves.easeOutCubic,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                          decoration: BoxDecoration(
                                            color: liveIndex == i
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _courseCategories[i],
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 14.5,
                                                fontWeight: liveIndex == i
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: liveIndex == i
                                                    ? colorScheme.onPrimary
                                                    : colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: hasTabs
                          ? TabBarView(
                              controller: _tabController,
                              children: _courseCategories
                                  .map((category) => _buildBody(user, category))
                                  .toList(),
                            )
                          : _buildBody(user, ''),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBody(User? user, String courseTypeFilter) {
    if (user == null) {
      return const ErrorContentView(error: 'User not found!');
    }

    final marks = user.marks;

    // Filter marks based on course type category
    final filteredMarks = marks.where((mark) {
      if (courseTypeFilter.isEmpty) return true;
      return CourseTypeHelper.matchesCategory(
        mark.courseType,
        courseTypeFilter,
      );
    }).toList();

    if (filteredMarks.isEmpty) {
      return const EmptyContentView(
        primaryText: 'No courses found.',
        secondaryText: '',
      );
    }

    return ListView.builder(
      itemCount: filteredMarks.length,
      itemBuilder: (context, index) {
        final course = filteredMarks[index];

        double totalWeightage = 0;
        double maxWeightage = 0;
        for (var detail in course.details) {
          totalWeightage += double.tryParse(detail.weightageMark) ?? 0;
          maxWeightage += double.tryParse(detail.weightage) ?? 0;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: GestureDetector(
            onTap: () {
              showMarksDetailBottomSheet(course, context);
            },
            child: AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  course.courseTitle,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  course.faculty,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: totalWeightage.toStringAsFixed(0),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                     children: <TextSpan>[
                       TextSpan(
                         text: ' / ${maxWeightage.toStringAsFixed(0)}',
                         style: TextStyle(
                           fontFamily: 'Inter',
                           color: Theme.of(context).colorScheme.onSurfaceVariant,
                           fontSize: 16,
                           fontWeight: FontWeight.w400,
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
            ),
          ),
        );
      },
    );
  }
}
