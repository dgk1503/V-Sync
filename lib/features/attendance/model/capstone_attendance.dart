import 'dart:convert';

/// One day in the capstone attendance calendar.
class CapstonePunch {
  const CapstonePunch({
    required this.serial,
    required this.date,
    required this.day,
    required this.dayType,
    required this.status,
    required this.punchTime,
  });

  final String serial;

  /// As VTOP writes it: `17-07-2026`.
  final String date;
  final String day;

  /// "Instructional", "Holiday", "No Instructional", "CAT1", ...: free text.
  final String dayType;

  /// "Present", "Absent" or "On Duty"; empty on a day that carries none.
  final String status;

  /// Empty when there was no punch.
  final String punchTime;

  /// The day as a date, or null when VTOP wrote it some other way.
  DateTime? get when {
    final m = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$').firstMatch(date.trim());
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    return DateTime(y, mo, d);
  }

  bool get isInstructional => dayType.toLowerCase().trim() == 'instructional';

  factory CapstonePunch.fromJson(Map<String, dynamic> json) => CapstonePunch(
    serial: _text(json['serial']),
    date: _text(json['date']),
    day: _text(json['day']),
    dayType: _text(json['day_type']),
    status: _text(json['status']),
    punchTime: _text(json['punch_time']),
  );

  Map<String, dynamic> toJson() => {
    'serial': serial,
    'date': date,
    'day': day,
    'day_type': dayType,
    'status': status,
    'punch_time': punchTime,
  };
}

/// Capstone (or SDP) attendance for one semester.
///
/// Not per-course: it is a present / on-duty / absent tally with a day-by-day
/// calendar. An on-duty day is neither attended nor absent, so the three counts
/// stay apart.
class CapstoneAttendance {
  const CapstoneAttendance({
    required this.title,
    required this.guideEvaluationStatus,
    required this.dateOfRegistration,
    required this.present,
    required this.onDuty,
    required this.absent,
    required this.percentage,
    required this.punches,
  });

  /// "Capstone" or "SDP".
  final String title;
  final String guideEvaluationStatus;
  final String dateOfRegistration;
  final int present;
  final int onDuty;
  final int absent;

  /// 0 to 100, as VTOP reports it; null when it did not read as a number.
  final double? percentage;
  final List<CapstonePunch> punches;

  /// The days that carry a status, newest first.
  List<CapstonePunch> get markedDays {
    final days = [
      for (final p in punches)
        if (p.status.isNotEmpty) p,
    ];
    days.sort(
      (a, b) => (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0)),
    );
    return days;
  }

  /// Every other day (holidays, days not yet reached), newest first.
  List<CapstonePunch> get otherDays {
    final days = [
      for (final p in punches)
        if (p.status.isEmpty) p,
    ];
    days.sort(
      (a, b) => (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0)),
    );
    return days;
  }

  factory CapstoneAttendance.fromJson(Map<String, dynamic> json) =>
      CapstoneAttendance(
        title: _text(json['title']),
        guideEvaluationStatus: _text(json['guide_evaluation_status']),
        dateOfRegistration: _text(json['date_of_registration']),
        present: _count(json['present']),
        onDuty: _count(json['on_duty']),
        absent: _count(json['absent']),
        percentage: double.tryParse(
          _text(json['percentage']).replaceAll('%', ''),
        ),
        punches: [
          for (final p in (json['punches'] as List? ?? const []))
            if (p is Map<String, dynamic>) CapstonePunch.fromJson(p),
        ],
      );

  Map<String, dynamic> toJson() => {
    'title': title,
    'guide_evaluation_status': guideEvaluationStatus,
    'date_of_registration': dateOfRegistration,
    'present': '$present',
    'on_duty': '$onDuty',
    'absent': '$absent',
    'percentage': percentage?.toString() ?? '',
    'punches': [for (final p in punches) p.toJson()],
  };

  /// The capstone in the scraper's reply (`{"records": [...], "capstone": ...}`),
  /// or null for a student who has none.
  static CapstoneAttendance? fromResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected attendance response');
    }
    final capstone = decoded['capstone'];
    if (capstone == null) return null;
    if (capstone is! Map<String, dynamic>) {
      throw const FormatException('Unexpected capstone response');
    }
    return CapstoneAttendance.fromJson(capstone);
  }
}

String _text(Object? value) => value == null ? '' : '$value'.trim();

int _count(Object? value) => int.tryParse(_text(value)) ?? 0;
