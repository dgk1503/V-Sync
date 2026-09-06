import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_page.dart';
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

    final cards = <Widget>[
      _HubCard(
        icon: Iconsax.tick_circle,
        title: 'Attendance',
        onTap: () => _push(context, const AttendancePage()),
      ),
      _HubCard(
        icon: Iconsax.document_text,
        title: 'Marks',
        onTap: () => _push(context, const MarksPage()),
      ),
      _HubCard(
        icon: Iconsax.calendar_tick,
        title: 'Exam Schedule',
        onTap: () => _push(context, const ExamSchedulePage()),
      ),
      if (!prefs.hideGrades)
        _HubCard(
          icon: Iconsax.award,
          title: 'Grades',
          onTap: () => _push(context, const GradeHistoryPage()),
        ),
      if (!prefs.hideDigitalAssignments)
        _HubCard(
          icon: Iconsax.document_upload,
          title: 'Digital Assignment Upload',
          onTap: () => _push(context, const DigitalAssignmentPage()),
        ),
      if (!prefs.hideOuting)
        _HubCard(
          icon: Iconsax.logout,
          title: 'Outing',
          onTap: () => _push(context, const OutingPage()),
        ),
      if (!prefs.hideFacultyInfo)
        _HubCard(
          icon: Iconsax.teacher,
          title: 'Faculty Info',
          onTap: () => _push(context, const FacultiesPage()),
        ),
      if (!prefs.hideOpenVtop)
        _HubCard(
          icon: Iconsax.global,
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
            MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const AccentGradientText(
                'Academics',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
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
            // tiles, no container behind it.
            Icon(icon, size: 24, color: colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
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
