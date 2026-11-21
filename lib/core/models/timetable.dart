// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'timetable.g.dart';

@Entity()
@JsonSerializable()
class Timetable {
  @Id()
  int? id;

  @JsonKey(name: 'Monday')
  @_DayRelToManyConverter()
  final ToMany<Day> monday;

  @JsonKey(name: 'Tuesday')
  @_DayRelToManyConverter()
  final ToMany<Day> tuesday;

  @JsonKey(name: 'Wednesday')
  @_DayRelToManyConverter()
  final ToMany<Day> wednesday;

  @JsonKey(name: 'Thursday')
  @_DayRelToManyConverter()
  final ToMany<Day> thursday;

  @JsonKey(name: 'Friday')
  @_DayRelToManyConverter()
  final ToMany<Day> friday;

  @JsonKey(name: 'Saturday')
  @_DayRelToManyConverter()
  final ToMany<Day> saturday;

  @JsonKey(name: 'Sunday')
  @_DayRelToManyConverter()
  final ToMany<Day> sunday;

  /// VTOP's course table: every course (and part of a course) the student is
  /// registered for, with its credits, as JSON text. Unlike the weekly grid above
  /// it also has courses that never meet (a project, an online course).
  ///
  /// Null on a timetable saved before the scraper read it; read it through
  /// [courses].
  @JsonKey(name: 'courses')
  @_CourseTableConverter()
  String? courseTable;

  /// [courseTable] decoded. Empty when there is none.
  @Transient()
  List<TimetableCourse> get courses {
    final text = courseTable;
    if (text == null || text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) TimetableCourse.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  factory Timetable.fromJson(Map<String, dynamic> json) =>
      _$TimetableFromJson(json);

  Timetable({
    this.id,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    this.courseTable,
  });
  Map<String, dynamic> toJson() => _$TimetableToJson(this);

  @override
  String toString() {
    return 'Timetable(id: $id, monday: $monday, tuesday: $tuesday, wednesday: $wednesday, thursday: $thursday, friday: $friday, saturday: $saturday, sunday: $sunday)';
  }
}

@Entity()
@JsonSerializable()
class Day {
  @Id()
  int? id;

  @JsonKey(name: 'start_time')
  String? startTime;
  @JsonKey(name: 'end_time')
  String? endTime;
  @JsonKey(name: 'course_name')
  String? courseName;
  @JsonKey(name: 'slot')
  String? slot;
  @JsonKey(name: 'venue')
  String? venue;
  @JsonKey(name: 'faculty')
  String? faculty;
  @JsonKey(name: 'course_code')
  String? courseCode;
  @JsonKey(name: 'course_type')
  String? courseType;

  /// Credits of this part of the course (theory or lab) as VTOP prints them, e.g.
  /// `3.0`. Null on a timetable saved before the scraper read credits, and
  /// empty when the page gave none.
  @JsonKey(name: 'credits')
  String? credits;

  Day({
    this.id,
    this.startTime,
    this.endTime,
    this.courseName,
    this.slot,
    this.venue,
    this.faculty,
    this.courseCode,
    this.courseType,
    this.credits,
  });

  factory Day.fromJson(Map<String, dynamic> json) => _$DayFromJson(json);
  Map<String, dynamic> toJson() => _$DayToJson(this);
}

class _DayRelToManyConverter
    implements JsonConverter<ToMany<Day>, List<dynamic>?> {
  const _DayRelToManyConverter();

  @override
  ToMany<Day> fromJson(List<dynamic>? json) {
    final items =
        json?.map((e) => Day.fromJson(e as Map<String, dynamic>)).toList() ??
        [];
    return ToMany<Day>(items: items);
  }

  @override
  List<Map<String, dynamic>>? toJson(ToMany<Day> rel) =>
      rel.map((e) => e.toJson()).toList();
}

/// Keeps the course table as one JSON text column: the scraper sends a list, and
/// a list of small records is not worth a table of its own.
class _CourseTableConverter implements JsonConverter<String?, Object?> {
  const _CourseTableConverter();

  @override
  String? fromJson(Object? json) => json == null ? null : jsonEncode(json);

  @override
  Object? toJson(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}

/// One row of VTOP's course table: a course, or one part of it (a course with a
/// theory and a lab part has a row for each).
class TimetableCourse {
  const TimetableCourse({
    required this.code,
    required this.name,
    required this.kind,
    required this.typeCode,
    required this.credits,
  });

  final String code;
  final String name;

  /// The part's kind as VTOP words it: "Embedded Theory", "Lab Only", ...
  final String kind;

  /// The short code the weekly grid uses: `ETH`, `ELA`, `TH`, `LO`, `PJT`, ...
  final String typeCode;

  /// As VTOP prints them (`3.0`); empty when the page gave none.
  final String credits;

  factory TimetableCourse.fromJson(Map<String, dynamic> json) =>
      TimetableCourse(
        code: (json['course_code'] as String? ?? '').trim(),
        name: (json['course_name'] as String? ?? '').trim(),
        kind: (json['course_type'] as String? ?? '').trim(),
        typeCode: (json['type_code'] as String? ?? '').trim(),
        credits: (json['credits'] as String? ?? '').trim(),
      );
}
