import 'package:vit_ap_student_app/core/models/timetable.dart';

List<Day> getClassesForDay(Timetable timetable, String day) {
  switch (day.toLowerCase()) {
    case 'monday':
      return timetable.monday.toList();
    case 'tuesday':
      return timetable.tuesday.toList();
    case 'wednesday':
      return timetable.wednesday.toList();
    case 'thursday':
      return timetable.thursday.toList();
    case 'friday':
      return timetable.friday.toList();
    case 'saturday':
      return timetable.saturday.toList();
    case 'sunday':
      return timetable.sunday.toList();
    default:
      return [];
  }
}

int _parseMinutes(String? time) {
  if (time == null || time.isEmpty) return 0;
  try {
    final parts = time.trim().split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  } catch (_) {
    return 0;
  }
}

/// Labs run ~2 hours (e.g. 8:00 - 9:50); theory runs 50 minutes
/// (e.g. 2:00 - 2:50). Trust `courseType` first, then the venue
/// (labs are held in venues named "... Lab"), then the slot — VTOP lab
/// slots always start with "L" (L1, L2, ...). Duration is the last
/// fallback.
bool isLabClass(Day classInfo) {
  final type = (classInfo.courseType ?? '').toLowerCase();
  if (type.contains('lab')) return true;

  final venue = (classInfo.venue ?? '').toLowerCase();
  if (venue.contains('lab')) return true;

  final slot = (classInfo.slot ?? '').trim().toUpperCase();
  if (slot.startsWith('L') &&
      slot.isNotEmpty &&
      RegExp(r'^L\d').hasMatch(slot)) {
    return true;
  }

  return _parseMinutes(classInfo.endTime) -
          _parseMinutes(classInfo.startTime) >=
      90;
}
