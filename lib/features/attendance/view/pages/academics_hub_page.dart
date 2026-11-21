import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_page.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/capstone_attendance_page.dart';
import 'package:vit_ap_student_app/features/calendar/view/pages/academic_calendar_page.dart';
import 'package:vit_ap_student_app/features/course_page/view/pages/course_page.dart';
import 'package:vit_ap_student_app/features/digital_assignment/view/pages/digital_assignment_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/biometric_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/exam_schedule_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/faculty_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/gpa_planner_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/grade_history_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/marks_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/outing_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/payments_page.dart';
import 'package:vit_ap_student_app/features/skip_planner/view/skip_planner_page.dart';
import 'package:vit_ap_student_app/features/vtop_webview/view/pages/vtop_webview_page.dart';

/// Landing page for the third tab. The heavy-use entries (Attendance, Marks,
/// Exam Schedule, Course Page) always stay; the rest can be hidden by the user
/// from Settings > Customization.
class AcademicsHubPage extends ConsumerWidget {
  const AcademicsHubPage({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (builder) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);

    // One unique Lucide glyph per feature — no glyph is reused in this
    // list, and each is chosen to read as its feature at a glance.
    final entries = <_HubEntry>[
      _HubEntry(
        icon: LucideIcons.clipboardCheck,
        title: 'Attendance',
        onTap: () => _push(context, const AttendancePage()),
      ),
      _HubEntry(
        icon: LucideIcons.listChecks,
        title: 'Marks',
        onTap: () => _push(context, const MarksPage()),
      ),
      _HubEntry(
        icon: LucideIcons.calendarClock,
        title: 'Exam Schedule',
        onTap: () => _push(context, const ExamSchedulePage()),
      ),
      // Always shown, like Attendance, Marks and Exam Schedule: a hide switch
      // would need a new column on the preferences row.
      _HubEntry(
        icon: LucideIcons.bookText,
        title: 'Course Page',
        onTap: () => _push(context, const CoursePage()),
      ),
      if (!prefs.hideAcademicCalendar)
        _HubEntry(
          icon: LucideIcons.calendarRange,
          title: 'Calendar',
          onTap: () => _push(context, const AcademicCalendarPage()),
        ),
      if (!prefs.hideGrades)
        _HubEntry(
          icon: LucideIcons.graduationCap,
          title: 'Grades',
          onTap: () => _push(context, const GradeHistoryPage()),
        ),
      if (!prefs.hideBiometric)
        _HubEntry(
          icon: LucideIcons.fingerprintPattern,
          title: 'Biometric Log',
          onTap: () => _push(context, const BiometricPage()),
        ),
      if (!prefs.hideDigitalAssignments)
        _HubEntry(
          icon: LucideIcons.fileUp,
          title: 'DA Upload',
          onTap: () => _push(context, const DigitalAssignmentPage()),
        ),
      if (!prefs.hideOuting)
        _HubEntry(
          icon: LucideIcons.planeTakeoff,
          title: 'Outing',
          onTap: () => _push(context, const OutingPage()),
        ),
      if (!prefs.hideFacultyInfo)
        _HubEntry(
          icon: LucideIcons.users,
          title: 'Faculty Info',
          onTap: () => _push(context, const FacultiesPage()),
        ),
      if (!prefs.hideOpenVtop)
        _HubEntry(
          icon: LucideIcons.globe,
          title: 'Open VTOP',
          onTap: () => _push(context, const VtopWebViewPage()),
        ),
      // Always last and always shown. The skip planner, GPA planner, payments and
      // capstone live behind it, so the hub stays a short, even grid.
      _HubEntry(
        icon: LucideIcons.ellipsis,
        title: 'More',
        onTap: () => _push(context, const MorePage()),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        // bottom: false lets content scroll underneath the floating capsule
        // nav bar; the scroll padding below keeps the last card clear of it
        // when fully scrolled.
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            kFloatingNavBarClearance + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const AccentGradientText(
                'Academics',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              if (!prefs.academicsListView)
                _HubGrid(entries: entries)
              else
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _HubCard(entry: entries[i]),
                ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is behind the hub's "More" tile: the planners, capstone attendance and
/// payments. The skip planner is also still on the attendance page, and the GPA
/// planner on the grades page; this is one more way to reach them.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (builder) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final entries = <_HubEntry>[
      _HubEntry(
        icon: LucideIcons.calendarX,
        title: 'Skip Planner',
        onTap: () => _push(context, const SkipPlannerPage()),
      ),
      _HubEntry(
        icon: LucideIcons.calculator,
        title: 'GPA Planner',
        onTap: () => _push(context, const GpaPlannerPage()),
      ),
      _HubEntry(
        icon: LucideIcons.wallet,
        title: 'Payments',
        onTap: () => _push(context, const PaymentsPage()),
      ),
      _HubEntry(
        icon: LucideIcons.rocket,
        title: 'Capstone',
        onTap: () => _push(context, const CapstoneAttendancePage()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const AccentGradientText(
          'More',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: prefs.academicsListView
              ? Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _HubCard(entry: entries[i]),
                    ],
                  ],
                )
              : _HubGrid(entries: entries),
        ),
      ),
    );
  }
}

/// One destination on the hub, whichever way it is laid out.
class _HubEntry {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HubEntry({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// The list layout: one full-width card per destination.
class _HubCard extends StatelessWidget {
  final _HubEntry entry;

  const _HubCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: entry.onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            // Bare outlined icon — same sharp treatment as the settings
            // tiles, no container behind it. The icon follows the active
            // theme accent while the card and title stay monochrome.
            Icon(entry.icon, size: 24, color: colorScheme.tertiary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                entry.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grid layout: two destinations per row, the icon above its name.
///
/// Built from the same card as the list so the two layouts stay one design;
/// only the arrangement changes. Each row is as tall as its taller tile, so a
/// title that wraps ("Academic Calendar") never leaves its neighbour shorter.
class _HubGrid extends StatelessWidget {
  final List<_HubEntry> entries;

  const _HubGrid({required this.entries});

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i += 2) ...[
          if (i > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _HubTile(entry: entries[i])),
                const SizedBox(width: _gap),
                // An odd last entry leaves its half of the row empty.
                Expanded(
                  child: i + 1 < entries.length
                      ? _HubTile(entry: entries[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  final _HubEntry entry;

  const _HubTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: entry.onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entry.icon, size: 28, color: colorScheme.tertiary),
              const SizedBox(height: 12),
              Text(
                entry.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14.5,
                  height: 1.25,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
