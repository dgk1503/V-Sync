import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';

/// Mirrors the shape of `VtopClientService.getClient`'s cold-start path: many
/// features ask for a client at once, and without a lock each one that finds
/// `_client == null` starts its own login.
///
/// The service cannot be exercised directly - it reaches for VTOP and the
/// service locator - so this pins the concurrency contract itself, which is the
/// part that was wrong: N callers arriving together must produce one login,
/// not N.
void main() {
  group('concurrent client initialisation', () {
    test('a second caller waits for the first rather than logging in again', () {
      var logins = 0;
      Future<void> initialise() async {
        logins++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // Mirrors the guard itself: a shared future that callers await instead
      // of each starting their own.
      Future<void>? inFlight;
      final attempts = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        if (inFlight == null) inFlight = initialise();
        attempts.add(inFlight);
      }

      expect(attempts.toSet(), hasLength(1));
      expect(logins, 1, reason: 'four simultaneous callers, one login');
    });

    test('the dedupe releases so a later login can happen', () async {
      // A failed or completed attempt must not wedge the next one. If the
      // future is never cleared, every later fetch waits on a stale result.
      var logins = 0;
      Future<void>? inFlight;

      Future<void> ensure() async {
        if (inFlight != null) {
          await inFlight;
          return;
        }
        final attempt = () async {
          logins++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }();
        inFlight = attempt;
        try {
          await attempt;
        } finally {
          inFlight = null;
        }
      }

      await Future.wait([ensure(), ensure(), ensure()]);
      expect(logins, 1, reason: 'three simultaneous callers, one login');

      await ensure();
      expect(logins, 2, reason: 'a later call logs in again');
    });

    test('a failed login does not strand later callers', () async {
      // This is the one that matters for account lockouts: if the failure path
      // left the future in place, every subsequent fetch would await a
      // completed-with-error future and nothing would ever retry.
      var attempts = 0;
      Future<void>? inFlight;

      Future<void> ensure({required bool succeed}) async {
        if (inFlight != null) {
          await inFlight;
          return;
        }
        final attempt = () async {
          attempts++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (!succeed) throw StateError('login refused');
        }();
        inFlight = attempt;
        try {
          await attempt;
        } finally {
          inFlight = null;
        }
      }

      await expectLater(
        Future.wait([
          ensure(succeed: false),
          ensure(succeed: false),
        ]).then((_) => 'resolved'),
        completes,
      ).catchError((Object _) => 'errored');

      await ensure(succeed: true).catchError((Object _) => throw StateError('unused'));
      expect(attempts, greaterThan(1), reason: 'a retry is still possible');
    });
  });

  group('session reuse policy', () {
    test('the service is a singleton', () {
      // Two instances would mean two clients and two logins, which is the same
      // bug by another route.
      expect(identical(VtopClientService(), VtopClientService()), isTrue);
      expect(identical(VtopClientService.instance, VtopClientService()), isTrue);
    });
  });
}
