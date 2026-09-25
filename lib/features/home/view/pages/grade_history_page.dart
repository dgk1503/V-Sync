import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/models/grade_history.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/grade_card.dart';

class GradeHistoryPage extends ConsumerStatefulWidget {
  const GradeHistoryPage({super.key});

  @override
  ConsumerState<GradeHistoryPage> createState() => _GradeHistoryPageState();
}

class _GradeHistoryPageState extends ConsumerState<GradeHistoryPage> {
  String selectedFilter = 'All';
  String searchQuery = '';
  bool showFilters = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getUniqueExamMonths(GradeHistory gradeHistory) {
    final months = gradeHistory.courses
        .map((course) => course.examMonth)
        .toSet()
        .toList();
    months.sort();
    return ['All', ...months];
  }

  List<Course> _getFilteredCourses(GradeHistory gradeHistory) {
    List<Course> courses = gradeHistory.courses.toList();

    // Apply month filter
    if (selectedFilter != 'All') {
      courses = courses
          .where((course) => course.examMonth == selectedFilter)
          .toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      courses = courses
          .where(
            (course) =>
                course.courseTitle.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                course.courseCode.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                course.grade.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                course.examMonth.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return courses;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final gradeHistory = user?.profile.target?.gradeHistory.target;
    final colorScheme = Theme.of(context).colorScheme;

    final hasCourses = gradeHistory != null && gradeHistory.courses.isNotEmpty;
    final filteredCount = hasCourses
        ? _getFilteredCourses(gradeHistory).length
        : 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: user == null
            ? const ErrorContentView(error: 'User not found!')
            : gradeHistory == null || gradeHistory.courses.isEmpty
                ? const EmptyContentView(
                    primaryText: 'No grades available',
                    secondaryText:
                        'Your grade history will appear here once available.',
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Search bar + filter button
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                  },
                                  style: TextStyle(
                                    fontFamily: 'Instrument Sans',
                                    fontSize: 15,
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search $filteredCount courses...',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Instrument Sans',
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    prefixIcon: Icon(
                                      Iconsax.search_normal_copy,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    filled: true,
                                    fillColor:
                                        colorScheme.surfaceContainerLow,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showFilters = !showFilters;
                                  });
                                },
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: showFilters
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Iconsax.setting_4_copy,
                                    size: 20,
                                    color: showFilters
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Month filter chips
                      if (showFilters)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: SizedBox(
                              height: 52,
                              child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  _getUniqueExamMonths(gradeHistory).length,
                              itemBuilder: (context, index) {
                                final filter =
                                    _getUniqueExamMonths(gradeHistory)[index];
                                final isSelected = selectedFilter == filter;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedFilter = filter;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme
                                                .surfaceContainerLow,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        filter,
                                        style: TextStyle(
                                          fontFamily: 'Instrument Sans',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? colorScheme.onPrimary
                                              : colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          ),
                        ),

                      // Course list
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final courses = _getFilteredCourses(gradeHistory);
                              if (courses.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 44,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No courses found',
                                        style: TextStyle(
                                          fontFamily: 'Instrument Sans',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final course = courses[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5.0),
                                child: GradeCard(course: course),
                              );
                            },
                            childCount: _getFilteredCourses(gradeHistory)
                                    .isEmpty
                                ? 1
                                : _getFilteredCourses(gradeHistory).length,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
