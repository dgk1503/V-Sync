import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/features/attendance/model/attendance_detail.dart';
import 'package:vit_ap_student_app/features/attendance/repository/attendance_remote_repository.dart';

part 'detailed_attendance_viewmodel.g.dart';

@riverpod
class DetailedAttendanceViewmodel extends _$DetailedAttendanceViewmodel {
  late AttendanceRemoteRepository _attendanceRemoteRepository;

  @override
  AsyncValue<List<AttendanceDetail>>? build() {
    _attendanceRemoteRepository = ref.watch(attendanceRemoteRepositoryProvider);
    return null;
  }

  Future<void> fetchDetailedAttendance({
    required String courseId,
    required String courseType,
  }) async {
    final key = _cacheKey(courseId, courseType);

    // Show the last known history immediately rather than a spinner. Day-wise
    // attendance is history, so yesterday's answer is a perfectly good answer
    // to "which days did I attend"; the refresh below corrects it.
    final cached = ref.read(dataCacheServiceProvider).read(key);
    if (cached != null) {
      state = AsyncValue.data(_decode(cached));
    } else {
      state = const AsyncValue.loading();
    }

    // Demo mode: serve bundled sample detailed attendance. Caching it would
    // only pin a fixture to disk.
    if (DemoService.isDemoMode) {
      state = AsyncValue.data(
        await DemoService.instance.detailedAttendance(),
      );
      return;
    }

    final userNotifier = ref.read(currentUserProvider.notifier);
    final Credentials? credentials = await userNotifier.getSavedCredentials();

    if (credentials == null) {
      state = AsyncValue.error(
          'User not found. Please Logout and Login.', StackTrace.current);
      return;
    }

    final res = await _attendanceRemoteRepository.fetchDetailedAttendance(
      registrationNumber: credentials.registrationNumber,
      password: credentials.password,
      semSubId: credentials.semSubId,
      courseId: courseId,
      courseType: courseType,
    );

    if (res case Left(value: final failure)) {
      // Keep the cached history on screen; a dropped connection should not
      // erase attendance the user is reading.
      final shown = state?.asData?.value;
      if (shown != null && shown.isNotEmpty) return;
      state = AsyncValue.error(failure.message, StackTrace.current);
    } else if (res case Right(value: final detailedAttendance)) {
      state = AsyncValue.data(detailedAttendance);
      ref
          .read(dataCacheServiceProvider)
          .write(key, attendanceDetailToJson(detailedAttendance));
    }
  }

  /// Keyed per course, so switching courses does not show the previous
  /// course's grid while the new one loads.
  static String _cacheKey(String courseId, String courseType) =>
      'attendance-detail:$courseId:$courseType';

  /// Decodes a cached payload, treating anything unreadable as no cache rather
  /// than throwing on a stale format.
  static List<AttendanceDetail> _decode(String payload) {
    try {
      return attendanceDetailFromJson(payload);
    } on FormatException {
      return const [];
    }
  }
}
