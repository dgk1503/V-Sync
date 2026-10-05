import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';
import 'package:vit_ap_student_app/features/calendar/model/calendar_chip.dart';
import 'package:vit_ap_student_app/features/calendar/repository/calendar_remote_repository.dart';
import 'package:vit_ap_student_app/features/home/model/milestone.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/milestones_viewmodel.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/academic_calendar.dart';

part 'calendar_viewmodel.g.dart';

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const Map<String, int> _monthNumbers = {
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
  'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
};

/// A month ready to render: its chips, date-ordered, with the most
/// consequential kind winning the chip on any day that carries several.
class CalendarMonth {
  const CalendarMonth({
    required this.year,
    required this.month,
    required this.chips,
  });

  final int year;
  final int month;
  final List<CalendarChip> chips;

  DateTime get firstDay => DateTime(year, month);

  String get label => '${_monthNames[month - 1]} $year';

  /// Chips falling on [date], strongest kind first.
  List<CalendarChip> chipsOn(DateTime date) => chips
      .where((chip) =>
          chip.date.year == date.year &&
          chip.date.month == date.month &&
          chip.date.day == date.day)
      .toList(growable: false);

  /// The single chip to draw on [date], or null when nothing applies.
  CalendarChip? chipFor(DateTime date) {
    final onDay = chipsOn(date);
    return onDay.isEmpty ? null : onDay.first;
  }
}

@riverpod
class CalendarViewmodel extends _$CalendarViewmodel {
  /// Cache key for the semester calendar. Not namespaced by semester because
  /// the box is wiped on logout, which is how `SemesterCache` is handled too.
  static const String cacheKey = 'calendar';

  /// How stale a cached calendar may get before VTOP is asked again.
  ///
  /// VTOP publishes the semester calendar once and then changes a handful of
  /// days, so this is deliberately weeks rather than hours: seven sequential
  /// requests on every page open was costing real time to re-learn an answer
  /// that had not moved.
  static const Duration maxAge = Duration(days: 5);

  /// Guards against two callers both deciding to refresh. The page opens and
  /// the attendance card both reach for this, and a duplicate refresh would
  /// mean two full chains of VTOP requests for one calendar.
  Future<void>? _inFlight;

  @override
  AsyncValue<List<CalendarMonth>> build() {
    // Synchronous on purpose. An `async` build puts the provider in its loading
    // state for a frame before it can return, so even a perfect cache hit cost
    // a spinner flash. Reading the cache needs no await, so nothing does.
    // Returned synchronously as data rather than as an awaited Future: an
    // async build puts the provider in AsyncLoading for a frame first, which
    // is a spinner flash even when the cache is warm. Keeping the AsyncValue
    // return type is what preserves refresh()'s ability to publish an error.
    final cached = _readCache();
    if (cached == null) return const AsyncValue.data(<CalendarMonth>[]);
    return AsyncValue.data(_applyCountdowns(cached));
  }

  /// The cached months, or null when there is no cache or it cannot be read.
  ///
  /// Both cases are deliberately the same answer. A row this build cannot
  /// decode - because an older build wrote it in a different shape - has to be
  /// treated as *absent*, not as *stale*: if it counted as stale-but-present
  /// then the TTL below would see a recent timestamp, skip the fetch, and the
  /// page would sit empty for the whole five days.
  List<CalendarMonth>? _readCache() {
    final entry = ref.read(dataCacheServiceProvider).readEntry(cacheKey);
    if (entry == null) return null;

    final months = _tryUnwrap(entry.payload);
    if (months.isEmpty) {
      // Drop it so a shape this build cannot read stops shadowing every
      // future fetch.
      ref.read(dataCacheServiceProvider).remove(cacheKey);
      return null;
    }
    return months;
  }

  /// The entry point a page should call on open.
  ///
  /// Paints whatever is cached, then refreshes only when the cache has actually
  /// gone stale. That keeps repeat visits instant and stops the app from asking
  /// VTOP for the same calendar on every single navigation.
  Future<void> ensureLoaded({bool includeCountdowns = true}) async {
    final shown = state.asData?.value ?? const <CalendarMonth>[];
    if (shown.isEmpty) _paintFromCache(includeCountdowns);

    // A readable cache that is still fresh is the whole point: no request, no
    // spinner, no flash. Anything else goes to VTOP.
    final entry = ref.read(dataCacheServiceProvider).readEntry(cacheKey);
    if (_readCache() != null && entry != null && !entry.isOlderThan(maxAge)) {
      return;
    }

    await refresh(includeCountdowns: includeCountdowns);
  }

  /// Forces a re-read from VTOP, e.g. pull to refresh. Concurrent callers share
  /// one request rather than each starting their own.
  Future<void> refresh({bool includeCountdowns = true}) {
    return _inFlight ??= _refresh(includeCountdowns: includeCountdowns)
            .whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _refresh({required bool includeCountdowns}) async {
    // Only fall back to a full-screen loader when there is nothing to show.
    // This is the same `silentRefresh` idea `refreshAttendance` already uses:
    // a background refresh must not blank a screen the user is reading.
    final shown = state.asData?.value ?? const <CalendarMonth>[];
    if (shown.isEmpty) _paintFromCache(includeCountdowns);
    if ((state.asData?.value ?? const <CalendarMonth>[]).isEmpty) {
      state = const AsyncValue<List<CalendarMonth>>.loading();
    }

    final credentials = await ref
        .read(currentUserProvider.notifier)
        .getSavedCredentials();
    if (credentials == null) {
      state = AsyncValue<List<CalendarMonth>>.error(
        'User not found. Please Logout and Login.',
        StackTrace.current,
      );
      return;
    }

    final Either<Failure, CalendarSnapshot> result =
        await ref.read(calendarRemoteRepositoryProvider).fetchAcademicCalendar(
              registrationNumber: credentials.registrationNumber,
              password: credentials.password,
              semSubId: credentials.semSubId,
            );

    result.fold(
      (failure) {
        // Keep whatever is on screen: a failed refresh should not blank a
        // calendar the user is already reading.
        if ((state.asData?.value ?? const <CalendarMonth>[]).isNotEmpty) {
          return;
        }
        state = AsyncValue<List<CalendarMonth>>.error(
          failure.message,
          StackTrace.current,
        );
      },
      (snapshot) {
        ref
            .read(dataCacheServiceProvider)
            .write(cacheKey, _wrap(snapshot.rawJson, credentials.semSubId));
        final months = _toMonths(snapshot.calendar);
        state = AsyncValue.data(
          includeCountdowns
              ? _withCountdowns(months, ref.read(milestonesProvider))
              : months,
        );
      },
    );
  }

  /// Shows the cached months, if there are any. Kept separate so `build` and
  /// both refresh paths agree on how a cache hit is turned into state.
  void _paintFromCache(bool includeCountdowns) {
    final months = _readCache();
    if (months == null) return;
    state = AsyncValue.data(
      includeCountdowns ? _applyCountdowns(months) : months,
    );
  }

  /// The cached payload carries the semester it belongs to, so a semester
  /// switch is detectable without waiting on secure storage.
  String _wrap(String rawJson, String semSubId) =>
      jsonEncode({'semSubId': semSubId, 'payload': rawJson});

  List<CalendarMonth> _tryUnwrap(String cached) {
    try {
      final wrapper = jsonDecode(cached) as Map<String, dynamic>;
      final raw = wrapper['payload'] as String;
      return _toMonths(CalendarRemoteRepository.parseCalendarPayload(raw));
    } on Object {
      // A payload written by an older build, or a half-written row, is not
      // worth an error screen. Treated as no cache.
      return const [];
    }
  }

  List<CalendarMonth> _applyCountdowns(List<CalendarMonth> months) =>
      _withCountdowns(months, ref.read(milestonesProvider));

  /// Re-renders the already-fetched months with or without countdowns, without
  /// hitting VTOP again.
  void setIncludeCountdowns(List<Milestone> milestones, bool includeCountdowns) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(
      includeCountdowns ? _withCountdowns(current, milestones) : current,
    );
  }

  List<CalendarMonth> _toMonths(AcademicCalendar calendar) {
    final byMonth = <String, List<CalendarChip>>{};
    for (final day in calendar.days) {
      final date = DateTime.parse(day.date);
      byMonth
          .putIfAbsent('${date.year}-${date.month}', () => <CalendarChip>[])
          .addAll(CalendarEventClassifier.chipsFor(day));
    }

    final months = <CalendarMonth>[];
    for (final monthRef in calendar.months) {
      final parsed = _parseCalDate(monthRef.calDate);
      if (parsed == null) continue;
      months.add(
        CalendarMonth(
          year: parsed.year,
          month: parsed.month,
          chips: byMonth['${parsed.year}-${parsed.month}'] ?? const [],
        ),
      );
    }
    months.sort((a, b) => a.firstDay.compareTo(b.firstDay));
    return months;
  }

  /// Adds each countdown as a chip on the day it lands. Countdowns rank lowest
  /// so they never hide a real holiday or exam on the same day.
  List<CalendarMonth> _withCountdowns(
    List<CalendarMonth> months,
    List<Milestone> milestones,
  ) {
    return [
      for (final month in months)
        CalendarMonth(
          year: month.year,
          month: month.month,
          chips: () {
            final extras = <CalendarChip>[
              for (final milestone in milestones)
                if (milestone.targetDate.year == month.year &&
                    milestone.targetDate.month == month.month)
                  CalendarChip(
                    date: DateTime(
                      milestone.targetDate.year,
                      milestone.targetDate.month,
                      milestone.targetDate.day,
                    ),
                    kind: CalendarDayKind.countdown,
                    title: milestone.title,
                    detail: milestone.info,
                  ),
            ];
            return _sorted([...month.chips, ...extras]);
          }(),
        ),
    ];
  }

  List<CalendarChip> _sorted(List<CalendarChip> chips) {
    final out = [...chips];
    out.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return b.precedence.compareTo(a.precedence);
    });
    return out;
  }

  /// Parses the `01-AUG-2026` form VTOP puts in its month buttons.
  DateTime? _parseCalDate(String calDate) {
    final parts = calDate.split('-');
    if (parts.length != 3) return null;
    final month = _monthNumbers[parts[1].toUpperCase()];
    final year = int.tryParse(parts[2]);
    if (month == null || year == null) return null;
    return DateTime(year, month);
  }
}