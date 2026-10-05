import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_page.dart';
import 'package:vit_ap_student_app/features/calendar/view/pages/academic_calendar_page.dart';
import 'package:vit_ap_student_app/features/digital_assignment/view/pages/digital_assignment_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/exam_schedule_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/faculty_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/grade_history_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/marks_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/outing_page.dart';
import 'package:vit_ap_student_app/features/vtop_webview/view/pages/vtop_webview_page.dart';

/// Landing page for the third tab. The three heavy-use entries (Attendance,
/// Marks, Exam Schedule) always stay; the rest can be hidden by the user
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
    final cards = <Widget>[
      _HubCard(
        icon: LucideIcons.clipboardCheck,
        title: 'Attendance',
        onTap: () => _push(context, const AttendancePage()),
      ),
      _HubCard(
        icon: LucideIcons.listChecks,
        title: 'Marks',
        onTap: () => _push(context, const MarksPage()),
      ),
      _HubCard(
        icon: LucideIcons.calendarClock,
        title: 'Exam Schedule',
        onTap: () => _push(context, const ExamSchedulePage()),
      ),
      if (!prefs.hideAcademicCalendar)
        _HubCard(
          icon: LucideIcons.calendarRange,
          title: 'Academic Calendar',
          onTap: () => _push(context, const AcademicCalendarPage()),
        ),
      if (!prefs.hideGrades)
        _HubCard(
          icon: LucideIcons.graduationCap,
          title: 'Grades',
          onTap: () => _push(context, const GradeHistoryPage()),
        ),
      if (!prefs.hideDigitalAssignments)
        _HubCard(
          icon: LucideIcons.fileUp,
          title: 'Digital Assignment Upload',
          onTap: () => _push(context, const DigitalAssignmentPage()),
        ),
      if (!prefs.hideOuting)
        _HubCard(
          icon: LucideIcons.planeTakeoff,
          title: 'Outing',
          onTap: () => _push(context, const OutingPage()),
        ),
      if (!prefs.hideFacultyInfo)
        _HubCard(
          icon: LucideIcons.users,
          title: 'Faculty Info',
          onTap: () => _push(context, const FacultiesPage()),
        ),
      if (!prefs.hideOpenVtop)
        _HubCard(
          icon: LucideIcons.globe,
          title: 'Open VTOP',
          onTap: () => _push(context, const VtopWebViewPage()),
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
            kFloatingNavBarClearance +
                MediaQuery.paddingOf(context).bottom,
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
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            // Bare outlined icon — same sharp treatment as the settings
            // tiles, no container behind it. The icon follows the active
            // theme accent while the card and title stay monochrome.
            Icon(icon, size: 24, color: colorScheme.tertiary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
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
