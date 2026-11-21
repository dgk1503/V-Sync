import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/capstone_attendance.dart';
import 'package:vit_ap_student_app/features/attendance/repository/capstone_repository.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/capstone_attendance_page.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/capstone_viewmodel.dart';

/// What the scraper sends for a student with a capstone.
const _reply = '''
{
  "records": [],
  "capstone": {
    "title": "Capstone",
    "guide_evaluation_status": "Registered, Invoice Generated,",
    "date_of_registration": "2026-07-06 00:00:00.0",
    "present": "14", "on_duty": "4", "absent": "12", "percentage": "60",
    "punches": [
      {"serial":"1","date":"17-07-2026","day":"FRIDAY","day_type":"Instructional","status":"Absent","punch_time":""},
      {"serial":"2","date":"18-07-2026","day":"SATURDAY","day_type":"Instructional","status":"Present","punch_time":"09:14:22"},
      {"serial":"3","date":"19-07-2026","day":"SUNDAY","day_type":"Holiday","status":"","punch_time":""}
    ]
  }
}
''';

/// A student with no registration: the scraper sends `null`.
const _none = '{"records": [], "capstone": null}';

/// A cache in memory, so no database is needed.
class _MemoryCache implements DataCacheService {
  final rows = <String, CacheEntry>{};

  @override
  CacheEntry? readEntry(String key) => rows[key];

  @override
  String? read(String key) => rows[key]?.payload;

  @override
  void write(String key, String payload) => rows[key] = CacheEntry(
    payload: payload,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUser extends CurrentUserNotifier {
  @override
  User? build() => null;

  @override
  Future<Credentials?> getSavedCredentials() async =>
      Credentials(registrationNumber: 'R1', password: 'p', semSubId: 'SEM1');
}

class _FakeRepository implements CapstoneRepository {
  _FakeRepository(this.replies);

  /// What each call answers, in order; the last one repeats.
  final List<Either<Failure, CapstoneFetch>> replies;
  int calls = 0;

  @override
  Future<Either<Failure, CapstoneFetch>> fetch(Credentials credentials) async =>
      replies[calls++ < replies.length ? calls - 1 : replies.length - 1];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Either<Failure, CapstoneFetch> ok(String body) => Right(
  CapstoneFetch(capstone: CapstoneAttendance.fromResponse(body), raw: body),
);

ProviderContainer container(_MemoryCache cache, _FakeRepository repository) {
  final c = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith(_FakeUser.new),
      dataCacheServiceProvider.overrideWithValue(cache),
      capstoneRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  group('reading the scraper\'s reply', () {
    test('gives the tally, the registration and every day', () {
      final c = CapstoneAttendance.fromResponse(_reply)!;

      expect(c.title, 'Capstone');
      expect((c.present, c.onDuty, c.absent), (14, 4, 12));
      expect(c.percentage, 60);
      expect(c.punches, hasLength(3));
    });

    test('is null for a student without a capstone', () {
      expect(CapstoneAttendance.fromResponse(_none), isNull);
    });

    test('lists marked days newest first, and keeps holidays apart', () {
      final c = CapstoneAttendance.fromResponse(_reply)!;

      expect(c.markedDays.map((d) => d.date), ['18-07-2026', '17-07-2026']);
      expect(c.otherDays.map((d) => d.date), ['19-07-2026']);
      expect(c.markedDays.first.when, DateTime(2026, 7, 18));
    });

    test('survives being saved and read back', () {
      final c = CapstoneAttendance.fromResponse(_reply)!;
      final again = CapstoneAttendance.fromResponse(
        jsonEncode({'capstone': c.toJson()}),
      )!;

      expect(again.present, 14);
      expect(again.punches, hasLength(3));
      expect(again.percentage, 60);
    });

    test('something that is not an object is refused, not guessed at', () {
      expect(
        () => CapstoneAttendance.fromResponse('[1, 2]'),
        throwsFormatException,
      );
    });
  });

  group('the view model', () {
    test('fetches when nothing is saved, and saves the answer', () async {
      final cache = _MemoryCache();
      final c = container(cache, _FakeRepository([ok(_reply)]));

      c.listen(capstoneViewModelProvider, (_, _) {});
      await settle();

      final state = c.read(capstoneViewModelProvider);
      expect(state.loaded, isTrue);
      expect(state.capstone!.present, 14);
      expect(cache.rows.containsKey('capstone:SEM1'), isTrue);
    });

    test('shows what is saved without asking VTOP when it is fresh', () async {
      final cache = _MemoryCache()
        ..write('capstone:SEM1', jsonEncode(jsonDecode(_reply)));
      final repo = _FakeRepository([ok(_none)]);
      final c = container(cache, repo);

      c.listen(capstoneViewModelProvider, (_, _) {});
      await settle();

      expect(c.read(capstoneViewModelProvider).capstone!.present, 14);
      expect(repo.calls, 0);
    });

    test('a student with none is told so, and it is remembered', () async {
      final cache = _MemoryCache();
      final c = container(cache, _FakeRepository([ok(_none)]));

      c.listen(capstoneViewModelProvider, (_, _) {});
      await settle();

      final state = c.read(capstoneViewModelProvider);
      expect(state.loaded, isTrue);
      expect(state.capstone, isNull);
      expect(cache.rows['capstone:SEM1']!.payload, '{"capstone":null}');
    });

    test('a refresh that finds none never wipes a saved capstone', () async {
      final cache = _MemoryCache()
        ..write('capstone:SEM1', jsonEncode(jsonDecode(_reply)));
      final c = container(cache, _FakeRepository([ok(_none)]));

      c.listen(capstoneViewModelProvider, (_, _) {});
      await settle();
      await c.read(capstoneViewModelProvider.notifier).refresh();

      final state = c.read(capstoneViewModelProvider);
      expect(state.capstone!.present, 14, reason: 'still the saved one');
      expect(state.error, isNotNull);
      expect(cache.rows['capstone:SEM1']!.payload, contains('"present":"14"'));
    });

    test('a failed refresh keeps what is saved and says why', () async {
      final cache = _MemoryCache()
        ..write('capstone:SEM1', jsonEncode(jsonDecode(_reply)));
      final c = container(
        cache,
        _FakeRepository([Left(Failure('VTOP is down'))]),
      );

      c.listen(capstoneViewModelProvider, (_, _) {});
      await settle();
      await c.read(capstoneViewModelProvider.notifier).refresh();

      final state = c.read(capstoneViewModelProvider);
      expect(state.capstone!.present, 14);
      expect(state.error, 'VTOP is down');
    });

    test(
      'a failure with nothing saved is an error, not an empty answer',
      () async {
        final c = container(
          _MemoryCache(),
          _FakeRepository([Left(Failure('No internet connection'))]),
        );

        c.listen(capstoneViewModelProvider, (_, _) {});
        await settle();

        final state = c.read(capstoneViewModelProvider);
        expect(state.capstone, isNull);
        expect(state.error, 'No internet connection');
      },
    );
  });

  group('the page', () {
    Future<void> mount(
      WidgetTester tester,
      _MemoryCache cache,
      _FakeRepository repo,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(_FakeUser.new),
            dataCacheServiceProvider.overrideWithValue(cache),
            capstoneRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: getThemeData(isDarkMode: true),
            home: const CapstoneAttendancePage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows the percentage, the three counts and the days', (
      tester,
    ) async {
      await mount(tester, _MemoryCache(), _FakeRepository([ok(_reply)]));

      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Present'), findsWidgets);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Sat, 18 Jul'), findsOneWidget);
      expect(find.text('09:14:22'), findsOneWidget);
      expect(find.text('6 Jul 2026'), findsOneWidget);
      expect(find.text('Registered, Invoice Generated'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('holidays are tucked away until asked for', (tester) async {
      await mount(tester, _MemoryCache(), _FakeRepository([ok(_reply)]));

      expect(find.text('Sun, 19 Jul'), findsNothing);
      await tester.tap(find.textContaining('Show holidays'));
      await tester.pump();
      expect(find.text('Sun, 19 Jul'), findsOneWidget);
    });

    testWidgets('a student without one sees a plain none', (tester) async {
      await mount(tester, _MemoryCache(), _FakeRepository([ok(_none)]));

      expect(find.text('No capstone this semester'), findsOneWidget);
    });
  });
}
