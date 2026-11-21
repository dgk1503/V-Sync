import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

/// One semester inside an academic year, with the year taken out of its name:
/// "Fall Semester 2025-26" under the "2025-26" heading reads "Fall Semester".
class SemesterEntry {
  const SemesterEntry({required this.info, required this.shortName});

  final SemesterInfo info;
  final String shortName;
}

/// An academic year and the semesters that belong to it.
class SemesterYear {
  const SemesterYear({required this.label, required this.entries});

  /// "2025-26", or "Other" for a name with no year in it.
  final String label;
  final List<SemesterEntry> entries;

  bool contains(String? semesterId) =>
      semesterId != null && entries.any((e) => e.info.id == semesterId);
}

/// Groups VTOP's flat semester list into academic years, newest year first.
///
/// VTOP names a semester "Fall Semester 2025-26", so the year is read out of the
/// name. Inside a year the order VTOP gave is kept, since that is the order it
/// thinks the semesters belong in. A name with no recognisable year is not
/// dropped: it goes under "Other", last.
class SemesterGrouping {
  const SemesterGrouping._();

  static const String other = 'Other';

  // "2025-26", "2025 - 26", "2025–2026", "2025/26".
  static final RegExp _span = RegExp(r'(\d{4})\s*[-–/]\s*(\d{2,4})');
  // A lone year such as "Fall 2025".
  static final RegExp _single = RegExp(r'\b(20\d{2})\b');

  static List<SemesterYear> group(List<SemesterInfo> semesters) {
    final byLabel = <String, List<SemesterEntry>>{};
    final startOf = <String, int>{};

    for (final semester in semesters) {
      final parsed = _yearOf(semester.name);
      final label = parsed?.label ?? other;
      startOf[label] = parsed?.start ?? -1;
      byLabel
          .putIfAbsent(label, () => <SemesterEntry>[])
          .add(
            SemesterEntry(
              info: semester,
              shortName: _withoutYear(semester.name, parsed?.token),
            ),
          );
    }

    final labels = byLabel.keys.toList()
      ..sort((a, b) {
        // "Other" always last, then newest year first.
        if (a == other) return 1;
        if (b == other) return -1;
        return startOf[b]!.compareTo(startOf[a]!);
      });

    return [
      for (final label in labels)
        SemesterYear(label: label, entries: byLabel[label]!),
    ];
  }

  static ({String label, int start, String token})? _yearOf(String name) {
    final span = _span.firstMatch(name);
    if (span != null) {
      final start = int.parse(span.group(1)!);
      final end = span.group(2)!;
      final endShort = end.length == 4 ? end.substring(2) : end;
      return (label: '$start-$endShort', start: start, token: span.group(0)!);
    }
    final single = _single.firstMatch(name);
    if (single != null) {
      final start = int.parse(single.group(1)!);
      return (label: '$start', start: start, token: single.group(0)!);
    }
    return null;
  }

  /// The name with the year removed and the leftovers tidied, or the name as it
  /// was when there is nothing left to show.
  static String _withoutYear(String name, String? token) {
    if (token == null) return name.trim();
    final tidy = name
        .replaceFirst(token, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–,]+|[\s\-–,]+$'), '')
        .replaceAll(RegExp(r'\s+[-–]\s+[-–]\s+'), ' - ')
        .trim();
    return tidy.isEmpty ? name.trim() : tidy;
  }
}
