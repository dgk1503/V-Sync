// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:objectbox/objectbox.dart';

@Entity()
class UserPreferences {
  @Id()
  int? id;

  String pfpPath;
  bool isTimetableNotificationsEnabled;
  bool isExamScheduleNotificationEnabled;
  int timetableNotificationDelay;
  int examScheduleNotificationDelay;
  bool isPrivacyEnabled;
  bool isDarkModeEnabled;
  bool hasUserChosenTheme;
  bool isAmoledEnabled;
  bool bypassWeekendOutingRestriction;

  String? appTheme; // Store theme as string: 'blue', 'sakura', etc.
  double? fontScale;

  @Property(type: PropertyType.date)
  DateTime? lastSync;

  @Property(type: PropertyType.date)
  DateTime? attendanceLastSync;

  @Property(type: PropertyType.date)
  DateTime? marksLastSync;

  @Property(type: PropertyType.date)
  DateTime? examScheduleLastSync;
  bool isFirstLaunch;

  // Academics hub customization. Stored as *hide* flags (default false =
  // card visible) so existing ObjectBox rows — which read new bool columns
  // as false — keep every card visible after the schema change.
  bool hideGrades;
  bool hideDigitalAssignments;
  bool hideOuting;
  bool hideFacultyInfo;
  bool hideOpenVtop;

  // Experimental Liquid Glass navbar (shader refraction). On by default.
  bool liquidGlassNavbar;

  UserPreferences({
    this.id,
    this.pfpPath = 'assets/images/pfp/default.png',
    this.isTimetableNotificationsEnabled = true,
    this.isExamScheduleNotificationEnabled = true,
    this.timetableNotificationDelay = 10,
    this.examScheduleNotificationDelay = 60,
    this.isPrivacyEnabled = true,
    // The app's identity look is dark monochrome — new users start in dark
    // mode regardless of the OS setting. Existing installs whose row predates
    // [hasUserChosenTheme] (false) also resolve to dark until the user
    // explicitly toggles, which flips that flag.
    this.isDarkModeEnabled = true,
    this.hasUserChosenTheme = false,
    this.isAmoledEnabled = false,
    this.bypassWeekendOutingRestriction = false,
    this.appTheme = 'blue',
    this.fontScale = 1.2,
    this.lastSync,
    this.attendanceLastSync,
    this.marksLastSync,
    this.examScheduleLastSync,
    this.isFirstLaunch = true,
    this.hideGrades = false,
    this.hideDigitalAssignments = false,
    this.hideOuting = false,
    this.hideFacultyInfo = false,
    this.hideOpenVtop = false,
    this.liquidGlassNavbar = true,
  });

  UserPreferences copyWith({
    int? id,
    String? pfpPath,
    bool? isTimetableNotificationsEnabled,
    bool? isExamScheduleNotificationEnabled,
    int? timetableNotificationDelay,
    int? examScheduleNotificationDelay,
    bool? isPrivacyEnabled,
    bool? isDarkModeEnabled,
    bool? hasUserChosenTheme,
    bool? isAmoledEnabled,
    bool? bypassWeekendOutingRestriction,
    String? appTheme,
    double? fontScale,
    DateTime? lastSync,
    DateTime? attendanceLastSync,
    DateTime? marksLastSync,
    DateTime? examScheduleLastSync,
    bool? isFirstLaunch,
    bool? hideGrades,
    bool? hideDigitalAssignments,
    bool? hideOuting,
    bool? hideFacultyInfo,
    bool? hideOpenVtop,
    bool? liquidGlassNavbar,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      pfpPath: pfpPath ?? this.pfpPath,
      isTimetableNotificationsEnabled:
          isTimetableNotificationsEnabled ??
          this.isTimetableNotificationsEnabled,
      isExamScheduleNotificationEnabled:
          isExamScheduleNotificationEnabled ??
          this.isExamScheduleNotificationEnabled,
      timetableNotificationDelay:
          timetableNotificationDelay ?? this.timetableNotificationDelay,
      examScheduleNotificationDelay:
          examScheduleNotificationDelay ?? this.examScheduleNotificationDelay,
      isPrivacyEnabled: isPrivacyEnabled ?? this.isPrivacyEnabled,
      isDarkModeEnabled: isDarkModeEnabled ?? this.isDarkModeEnabled,
      hasUserChosenTheme: hasUserChosenTheme ?? this.hasUserChosenTheme,
      isAmoledEnabled: isAmoledEnabled ?? this.isAmoledEnabled,
      bypassWeekendOutingRestriction:
          bypassWeekendOutingRestriction ?? this.bypassWeekendOutingRestriction,
      appTheme: appTheme ?? this.appTheme,
      fontScale: fontScale ?? this.fontScale,
      lastSync: lastSync ?? this.lastSync,
      attendanceLastSync: attendanceLastSync ?? this.attendanceLastSync,
      marksLastSync: marksLastSync ?? this.marksLastSync,
      examScheduleLastSync: examScheduleLastSync ?? this.examScheduleLastSync,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      hideGrades: hideGrades ?? this.hideGrades,
      hideDigitalAssignments:
          hideDigitalAssignments ?? this.hideDigitalAssignments,
      hideOuting: hideOuting ?? this.hideOuting,
      hideFacultyInfo: hideFacultyInfo ?? this.hideFacultyInfo,
      hideOpenVtop: hideOpenVtop ?? this.hideOpenVtop,
      liquidGlassNavbar: liquidGlassNavbar ?? this.liquidGlassNavbar,
    );
  }
}
