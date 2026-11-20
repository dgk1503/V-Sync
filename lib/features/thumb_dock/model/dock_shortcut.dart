import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/attendance_page.dart';
import 'package:vit_ap_student_app/features/calendar/view/pages/academic_calendar_page.dart';
import 'package:vit_ap_student_app/features/digital_assignment/view/pages/digital_assignment_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/biometric_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/exam_schedule_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/faculty_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/grade_history_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/marks_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/outing_page.dart';

/// A page the Academics row of the Thumb Dock can open directly.
class DockShortcut {
  const DockShortcut({
    required this.id,
    required this.label,
    required this.icon,
    required this.build,
  });

  /// Stable, saved with the user's choice. Never reuse or rename one.
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() build;
}

/// Every page that can be pinned to the dock's Academics row.
///
/// The glyphs match the Academics hub, so a shortcut looks like the card it
/// opens.
abstract final class DockShortcuts {
  static final all = <DockShortcut>[
    DockShortcut(
      id: 'attendance',
      label: 'Attendance',
      icon: LucideIcons.clipboardCheck,
      build: () => const AttendancePage(),
    ),
    DockShortcut(
      id: 'marks',
      label: 'Marks',
      icon: LucideIcons.listChecks,
      build: () => const MarksPage(),
    ),
    DockShortcut(
      id: 'exams',
      label: 'Exam Schedule',
      icon: LucideIcons.calendarClock,
      build: () => const ExamSchedulePage(),
    ),
    DockShortcut(
      id: 'calendar',
      label: 'Academic Calendar',
      icon: LucideIcons.calendarRange,
      build: () => const AcademicCalendarPage(),
    ),
    DockShortcut(
      id: 'grades',
      label: 'Grades',
      icon: LucideIcons.graduationCap,
      build: () => const GradeHistoryPage(),
    ),
    DockShortcut(
      id: 'biometric',
      label: 'Biometric Log',
      icon: LucideIcons.fingerprintPattern,
      build: () => const BiometricPage(),
    ),
    DockShortcut(
      id: 'assignments',
      label: 'Digital Assignments',
      icon: LucideIcons.fileUp,
      build: () => const DigitalAssignmentPage(),
    ),
    DockShortcut(
      id: 'outing',
      label: 'Outing',
      icon: LucideIcons.planeTakeoff,
      build: () => const OutingPage(),
    ),
    DockShortcut(
      id: 'faculty',
      label: 'Faculty Info',
      icon: LucideIcons.users,
      build: () => const FacultiesPage(),
    ),
  ];

  static DockShortcut? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The saved ids resolved to shortcuts, in order, dropping any that no longer
  /// exist.
  static List<DockShortcut> resolve(List<String> ids) => [
    for (final id in ids)
      if (byId(id) != null) byId(id)!,
  ];
}
