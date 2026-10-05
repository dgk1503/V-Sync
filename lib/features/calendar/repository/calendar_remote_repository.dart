import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/error/exceptions.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/vtop_errors.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop_get_client.dart' as vtop;

part 'calendar_remote_repository.g.dart';

/// A calendar plus the exact JSON it came from, so the caller can cache the
/// payload without re-encoding the model (which would drop any field the model
/// does not surface, and lose the scraper's own date format).
class CalendarSnapshot {
  const CalendarSnapshot({required this.calendar, required this.rawJson});

  final AcademicCalendar calendar;
  final String rawJson;
}

@riverpod
CalendarRemoteRepository calendarRemoteRepository(Ref ref) {
  final vtopService = serviceLocator<VtopClientService>();
  return CalendarRemoteRepository(vtopService);
}

/// Reads VTOP's academic calendar through the Rust scraper, which already
/// parses the month grid into a flat, date-ordered list of days.
class CalendarRemoteRepository {
  final VtopClientService vtopService;

  CalendarRemoteRepository(this.vtopService);

  /// Fetches every month of the semester's calendar for [classGroupId].
  ///
  /// The scraper needs a class group; [defaultClassGroupId] is the combined
  /// "All Class Group" that VTOP offers for every semester, so a first run
  /// does not have to make the user pick one.
  Future<Either<Failure, CalendarSnapshot>> fetchAcademicCalendar({
    required String registrationNumber,
    required String password,
    required String semSubId,
    String classGroupId = defaultClassGroupId,
  }) async {
    try {
      final credentials = Credentials(
        registrationNumber: registrationNumber,
        password: password,
        semSubId: semSubId,
      );

      final payload = await vtopService.executeWithRetry(
        credentials: credentials,
        operation: (client) => vtop.fetchAcademicCalendar(
          client: client,
          semesterId: semSubId,
          classGroupId: classGroupId,
        ),
      );

      return Right(
        CalendarSnapshot(
          calendar: parseCalendarPayload(payload),
          rawJson: payload,
        ),
      );
    } on SocketException {
      return Left(Failure('No internet connection'));
    } on VtopError catch (rustError) {
      final message = await VtopException.getFailureMessage(rustError);
      return Left(Failure(message));
    } on FormatException catch (e) {
      debugPrint('Academic calendar JSON parsing failed: $e');
      return Left(Failure('Invalid response format from server'));
    } catch (e) {
      debugPrint('Error fetching academic calendar from VTOP: $e');
      return Left(Failure('Failed to fetch academic calendar: $e'));
    }
  }

  /// The combined class group every semester offers.
  static const String defaultClassGroupId = 'COMB';

  /// Reads the scraper's JSON into the model by hand.
  ///
  /// The generated `AcademicCalendar.fromJson` expects camelCase keys
  /// (`semesterId`, `classGroupId`) while Rust's serde emits snake_case
  /// (`semester_id`, `class_group_id`). Hand-decoding the handful of fields
  /// avoids regenerating the bridge bindings for a naming convention only.
  ///
  /// Public because the cached copy is decoded through the same path as a live
  /// response, so a cache hit cannot drift from a network hit.
  static AcademicCalendar parseCalendarPayload(String payload) =>
      _parseCalendar(jsonDecode(payload) as Map<String, dynamic>);

  static AcademicCalendar _parseCalendar(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objects(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    String text(Object? value) => value?.toString() ?? '';

    return AcademicCalendar(
      semesterId: text(json['semester_id']),
      classGroupId: text(json['class_group_id']),
      months: objects('months')
          .map(
            (month) => CalendarMonthRef(
              label: text(month['label']),
              calDate: text(month['cal_date']),
            ),
          )
          .toList(growable: false),
      days: objects('days')
          .map(
            (day) => CalendarDay(
              date: text(day['date']),
              day: (day['day'] as num?)?.toInt() ?? 0,
              weekday: text(day['weekday']),
              events: (day['events'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>()
                  .map(
                    (event) => CalendarEvent(
                      description: text(event['description']),
                      label: text(event['label']),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }
}