class Milestone {
  final String id;
  final String title;
  final String? info;
  final DateTime targetDate;

  /// Whether a local notification should fire before [targetDate].
  /// Defaults to false — reminders are strictly opt-in per countdown.
  final bool reminderEnabled;

  /// How many minutes before [targetDate] the reminder fires.
  /// Ignored unless [reminderEnabled] is true.
  final int reminderMinutesBefore;

  const Milestone({
    required this.id,
    required this.title,
    this.info,
    required this.targetDate,
    this.reminderEnabled = false,
    this.reminderMinutesBefore = 30,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'info': info,
        'targetDate': targetDate.toIso8601String(),
        'reminderEnabled': reminderEnabled,
        'reminderMinutesBefore': reminderMinutesBefore,
      };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        title: json['title'] as String,
        info: json['info'] as String?,
        targetDate: DateTime.parse(json['targetDate'] as String),
        // Fields are optional in the stored JSON so countdowns saved before
        // reminders existed keep loading (they default to "no reminder").
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 30,
      );

  /// Whole days between today and the target date (negative once passed).
  int daysLeft() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
        targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  /// Whole hours between now and the target moment (negative once passed).
  int hoursLeft() => targetDate.difference(DateTime.now()).inHours;

  /// True once the target moment is in the past.
  bool isPassed() => targetDate.isBefore(DateTime.now());
}
