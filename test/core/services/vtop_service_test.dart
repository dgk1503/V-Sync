import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/core/error/exceptions.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/vtop_client.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/vtop_errors.dart';

/// Stands in for the Rust opaque client. Nothing in this service calls methods
/// on it — it only passes it around — so any member access is a test bug.
class _FakeVtopClient implements VtopClient {
  _FakeVtopClient(this.username);

  final String username;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The fake VTOP client has no ${invocation.memberName}',
  );

  @override
  String toString() => 'FakeVtopClient($username)';
}

/// A [VtopClientService] with the bridge and the clock under the test's
/// control, plus counters for the things that cost a real OTP email.
class _Harness {
  _Harness() {
    service = VtopClientService.withOverrides(
      createClient: ({
        required String username,
        required String password,
        required String userAgent,
      }) {
        clientsCreated++;
        userAgents.add(userAgent);
        return _FakeVtopClient(username);
      },
      performLogin: ({required VtopClient client}) async {
        loginCalls++;
        final handler = onLogin;
        if (handler != null) await handler(loginCalls);
      },
      submitOtp: ({required VtopClient client, required String otpCode}) async {
        otpSubmissions.add(otpCode);
        if (otpCode != validOtp) throw const VtopError_LoginOtpIncorrect();
      },
      resendOtp: ({required VtopClient client}) async => resendCalls++,
      now: () => now,
    );

    otpRequests = service.onOtpRequired.listen((_) => otpRequiredEvents++);
    authFailures = service.onAuthFailure.listen(authFailureMessages.add);
  }

  late final VtopClientService service;
  late final StreamSubscription<void> otpRequests;
  late final StreamSubscription<String> authFailures;

  /// Every login is one credentials POST, and on a network VTOP has not
  /// verified that is one OTP email. This is the number most tests assert on.
  int loginCalls = 0;
  int clientsCreated = 0;
  int resendCalls = 0;
  int otpRequiredEvents = 0;
  final List<String> otpSubmissions = <String>[];
  final List<String> authFailureMessages = <String>[];

  /// The identity each session was created with. VTOP binds the session to it,
  /// so it has to be the same stable string every time.
  final List<String> userAgents = <String>[];

  static const String validOtp = '123456';

  /// What the nth login should do. Returning a pending future holds the login
  /// open, which is how the concurrency tests create the race.
  Future<void> Function(int callNumber)? onLogin;

  DateTime now = DateTime(2026, 8, 20, 9);

  Future<void> dispose() async {
    await otpRequests.cancel();
    await authFailures.cancel();
    service.dispose();
  }
}

final Credentials _credentials = Credentials(
  registrationNumber: '22BCE7001',
  password: 'hunter2',
  semSubId: 'AP2024255',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Harness harness;
  late VtopClientService service;

  setUp(() {
    harness = _Harness();
    service = harness.service;
  });

  tearDown(() async => harness.dispose());

  group('getClient — one login at a time', () {
    // The duplicate-OTP bug. getClient had no in-flight guard, so every caller
    // that arrived during a login started its own. VTOP emails a fresh code
    // for each credentials POST from an unverified IP, so N concurrent callers
    // meant N emails — and the OTP prompt could only ever validate one of the
    // resulting sessions, which is how a correctly typed code came back as
    // "Invalid OTP".
    test('concurrent callers share one login', () async {
      final gate = Completer<void>();
      harness.onLogin = (_) => gate.future;

      final futures = <Future<VtopClient>>[
        service.getClient(username: 'A', password: 'p'),
        service.getClient(username: 'A', password: 'p'),
        service.getClient(username: 'A', password: 'p'),
      ];
      gate.complete();
      final clients = await Future.wait(futures);

      expect(harness.loginCalls, 1);
      expect(harness.clientsCreated, 1);
      expect(identical(clients[0], clients[1]), isTrue);
      expect(identical(clients[1], clients[2]), isTrue);
    });

    // The same guarantee across the part of a login that lasts longest: the
    // pause while the OTP prompt is open. A caller arriving here used to start
    // a second login, which sent a second email while the user was still
    // reading the first.
    test('a caller arriving while the OTP prompt is open joins, not logs in',
        () async {
      harness.onLogin = (int call) async {
        if (call == 1) throw const VtopError_LoginOtpRequired();
      };

      final first = service.getClient(username: 'A', password: 'p');
      await pumpEventQueue();
      expect(service.isOtpPending, isTrue);

      final second = service.getClient(username: 'A', password: 'p');
      await service.submitLoginOtp(_Harness.validOtp);
      final clients = await Future.wait(<Future<VtopClient>>[first, second]);

      expect(harness.loginCalls, 1);
      expect(harness.otpRequiredEvents, 1);
      expect(identical(clients[0], clients[1]), isTrue);
    });

    // VTOP binds a session to the User-Agent that opened it, and the in-app
    // WebView reuses that session out of process — so the identity has to come
    // from the device and be identical on every session.
    test('every session is created with the same device user agent', () async {
      await service.getClient(username: 'A', password: 'p');
      harness.now = harness.now.add(const Duration(minutes: 20));
      await service.getClient(username: 'A', password: 'p');

      expect(harness.userAgents, hasLength(2));
      expect(harness.userAgents.first, 'test-user-agent');
      expect(harness.userAgents.toSet(), hasLength(1));
    });

    test('a settled session is reused without logging in again', () async {
      await service.getClient(username: 'A', password: 'p');
      await service.getClient(username: 'A', password: 'p');

      expect(harness.loginCalls, 1);
    });

    test('a failed login releases the slot so the next call can retry',
        () async {
      harness.onLogin = (int call) async {
        if (call == 1) throw const VtopError_VtopServerError();
      };

      await expectLater(
        service.getClient(username: 'A', password: 'p'),
        throwsA(isA<VtopError_VtopServerError>()),
      );
      await service.getClient(username: 'A', password: 'p');

      expect(harness.loginCalls, 2);
    });
  });

  group('getClient — credentials and session lifetime', () {
    test('a different password does not reuse the session', () async {
      await service.getClient(username: 'A', password: 'p');
      await service.getClient(username: 'A', password: 'changed');

      expect(harness.loginCalls, 2);
    });

    test('a different account does not reuse the session', () async {
      await service.getClient(username: 'A', password: 'p');
      await service.getClient(username: 'B', password: 'p');

      expect(harness.loginCalls, 2);
    });

    test('the session is renewed once it reaches the refresh threshold',
        () async {
      await service.getClient(username: 'A', password: 'p');

      harness.now = harness.now.add(const Duration(minutes: 13, seconds: 59));
      await service.getClient(username: 'A', password: 'p');
      expect(harness.loginCalls, 1, reason: 'still inside the threshold');

      harness.now = harness.now.add(const Duration(seconds: 1));
      await service.getClient(username: 'A', password: 'p');
      expect(harness.loginCalls, 2, reason: '14 minutes old, renew');
    });

    // Locks down the ordering bug this seam exposed: a login superseded by an
    // account switch used to clear the session state on its way out, wiping
    // the session the switch had just established a microtask earlier.
    test('a superseded login cannot clobber the session that replaced it',
        () async {
      final gate = Completer<void>();
      harness.onLogin = (int call) => call == 1 ? gate.future : Future.value();

      final abandoned = service.getClient(username: 'A', password: 'p');
      final current = service.getClient(username: 'B', password: 'p');

      gate.complete();
      await expectLater(abandoned, throwsA(isA<Exception>()));
      await current;

      expect(harness.loginCalls, 2);
      expect(service.isInitialized, isTrue);
      expect(service.hasSessionFor(username: 'B', password: 'p'), isTrue);
    });

    test('hasSessionFor matches only the live credentials', () async {
      await service.getClient(username: 'A', password: 'p');

      expect(service.hasSessionFor(username: 'A', password: 'p'), isTrue);
      expect(service.hasSessionFor(username: 'A', password: 'other'), isFalse);
      expect(service.hasSessionFor(username: 'B', password: 'p'), isFalse);
    });

    test('hasSessionFor goes false once the session has fully expired',
        () async {
      await service.getClient(username: 'A', password: 'p');

      harness.now = harness.now.add(const Duration(minutes: 15));

      expect(service.hasSessionFor(username: 'A', password: 'p'), isFalse);
    });

    test('getTimeUntilExpiry counts down and floors at zero', () async {
      expect(service.getTimeUntilExpiry(), isNull);

      await service.getClient(username: 'A', password: 'p');
      expect(service.getTimeUntilExpiry(), const Duration(minutes: 15));

      harness.now = harness.now.add(const Duration(minutes: 10));
      expect(service.getTimeUntilExpiry(), const Duration(minutes: 5));

      harness.now = harness.now.add(const Duration(minutes: 20));
      expect(service.getTimeUntilExpiry(), Duration.zero);
    });

    test('getSessionInfo reports age and both expiry flags', () async {
      expect(service.getSessionInfo()['sessionAge'], 'unknown');

      await service.getClient(username: 'A', password: 'p');
      harness.now = harness.now.add(const Duration(minutes: 2, seconds: 5));

      final info = service.getSessionInfo();
      expect(info['isInitialized'], isTrue);
      expect(info['sessionAge'], '2m 5s');
      expect(info['isNearExpiry'], isFalse);
      expect(info['isExpired'], isFalse);

      harness.now = harness.now.add(const Duration(hours: 1));
      expect(service.getSessionInfo()['sessionAge'], '1h 2m 5s');
      expect(service.getSessionInfo()['isExpired'], isTrue);
    });
  });

  group('OTP lifecycle', () {
    Future<Future<VtopClient>> startLoginNeedingOtp() async {
      harness.onLogin = (int call) async {
        if (call == 1) throw const VtopError_LoginOtpRequired();
      };
      final pending = service.getClient(username: 'A', password: 'p');
      await pumpEventQueue();
      return pending;
    }

    test('the blocked caller resumes once the OTP is accepted', () async {
      final pending = await startLoginNeedingOtp();
      expect(service.isOtpPending, isTrue);
      expect(harness.otpRequiredEvents, 1);

      await service.submitLoginOtp(_Harness.validOtp);

      expect(await pending, isA<_FakeVtopClient>());
      expect(service.isOtpPending, isFalse);
      expect(service.isInitialized, isTrue);
      expect(harness.otpSubmissions, <String>[_Harness.validOtp]);
    });

    // A wrong code must leave the session standing so the user can try again.
    // Tearing it down here would mean a fresh login, and a fresh login on an
    // unverified network is another email — punishing a typo with a new code.
    test('a rejected code keeps the session pending for another try', () async {
      final pending = await startLoginNeedingOtp();

      await expectLater(
        service.submitLoginOtp('000000'),
        throwsA(isA<VtopError_LoginOtpIncorrect>()),
      );
      expect(service.isOtpPending, isTrue);
      expect(harness.loginCalls, 1);

      await service.submitLoginOtp(_Harness.validOtp);
      expect(await pending, isA<_FakeVtopClient>());
      expect(harness.loginCalls, 1);
    });

    test('cancelling fails the blocked caller instead of hanging it', () async {
      final pending = await startLoginNeedingOtp();

      service.cancelOtp();

      await expectLater(pending, throwsA(isA<Exception>()));
      expect(service.isOtpPending, isFalse);
      expect(service.isInitialized, isFalse);
    });

    test('a cancelled login leaves the next call free to start a fresh one',
        () async {
      final pending = await startLoginNeedingOtp();
      service.cancelOtp();
      await expectLater(pending, throwsA(isA<Exception>()));

      await service.getClient(username: 'A', password: 'p');

      expect(harness.loginCalls, 2);
    });

    test('resend goes to the pending session without a new login', () async {
      await startLoginNeedingOtp();

      await service.resendLoginOtp();

      expect(harness.resendCalls, 1);
      expect(harness.loginCalls, 1);
      expect(service.isOtpPending, isTrue);
    });

    test('submit and resend refuse when no OTP is pending', () async {
      expect(
        () => service.submitLoginOtp(_Harness.validOtp),
        throwsStateError,
      );
      expect(() => service.resendLoginOtp(), throwsStateError);
    });

    test('cancelOtp with nothing pending is a no-op', () {
      expect(service.cancelOtp, returnsNormally);
      expect(service.isOtpPending, isFalse);
    });

    test('resetClient cancels a pending OTP and clears the session', () async {
      final pending = await startLoginNeedingOtp();

      service.resetClient();

      await expectLater(pending, throwsA(isA<Exception>()));
      expect(service.isOtpPending, isFalse);
      expect(service.isInitialized, isFalse);
      expect(service.currentClient, isNull);
    });

    // The service is a singleton in the app, so a second instance would mean
    // two clients and two logins — the same bug by another route.
    test('the service the app runs on is a singleton', () {
      expect(identical(VtopClientService(), VtopClientService()), isTrue);
      expect(
        identical(VtopClientService.instance, VtopClientService()),
        isTrue,
      );
    });
  });

  group('authentication failures', () {
    test('an auth failure is announced and clears the session', () async {
      harness.onLogin = (_) async =>
          throw const VtopError_AuthenticationFailed('Max attempts exceeded');

      await expectLater(
        service.getClient(username: 'A', password: 'p'),
        throwsA(isA<VtopError_AuthenticationFailed>()),
      );
      await pumpEventQueue();

      expect(harness.authFailureMessages, <String>['Max attempts exceeded']);
      expect(service.isInitialized, isFalse);
      expect(service.currentClient, isNull);
    });

    test('invalid credentials are announced in plain language', () async {
      harness.onLogin = (_) async => throw const VtopError_InvalidCredentials();

      await expectLater(
        service.getClient(username: 'A', password: 'p'),
        throwsA(isA<VtopError_InvalidCredentials>()),
      );
      await pumpEventQueue();

      expect(
        harness.authFailureMessages,
        <String>['Invalid username or password.'],
      );
    });
  });

  group('executeWithRetry', () {
    test('a successful operation runs once', () async {
      var attempts = 0;

      final result = await service.executeWithRetry<String>(
        credentials: _credentials,
        operation: (_) async {
          attempts++;
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 1);
      expect(harness.loginCalls, 1);
    });

    test('an expired session is retried once', () async {
      var attempts = 0;

      final result = await service.executeWithRetry<String>(
        credentials: _credentials,
        operation: (_) async {
          attempts++;
          if (attempts == 1) throw const VtopError_SessionExpired();
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 2);
      expect(harness.loginCalls, 2, reason: 'the retry re-establishes it');
    });

    // The login flow's own calls hold the credentials in pieces, so they cannot
    // use executeWithRetry. They still have to go through the service: a
    // dropped session there is exactly the case that needs the single-flighted
    // re-login, and calling Rust directly left the user looking at a failure
    // that retrying could not clear, because the cached client still looked
    // fresh to the service.
    test('an expired session on a loose-credentials call is retried', () async {
      var attempts = 0;

      final result = await service.executeWithCredentials<String>(
        username: '22BCE7001',
        password: 'hunter2',
        operation: (_) async {
          attempts++;
          if (attempts == 1) throw const VtopError_SessionExpired();
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 2);
      expect(harness.loginCalls, 2, reason: 'the retry re-establishes it');
    });

    // Two requests can expire a moment apart: the first one's retry is already
    // logging in when the second one fails. Tearing the session down with
    // resetClient() cleared the single-flight claim along with it, so the
    // second retry started a login of its own — two credentials POSTs, and
    // VTOP mails an OTP for each of those it sees from an IP it has not
    // verified. The second retry now joins the login already running.
    test('a second expiry joins the login the first retry started', () async {
      // The shared session, established once.
      await service.getClient(username: 'A', password: 'p');
      expect(harness.loginCalls, 1);

      final secondLoginStarted = Completer<void>();
      final releaseSecondLogin = Completer<void>();
      harness.onLogin = (int call) async {
        if (call == 2) {
          secondLoginStarted.complete();
          await releaseSecondLogin.future;
        }
      };

      // Two requests are in flight on that one session when VTOP drops it. A
      // notices first and its retry is logging in by the time B notices; both
      // run the second attempt on the session that login produces.
      Future<String> run(String label, Duration failureDelay) async {
        var attempts = 0;
        return service.executeWithCredentials<String>(
          username: 'A',
          password: 'p',
          operation: (_) async {
            attempts++;
            if (attempts == 1) {
              await Future<void>.delayed(failureDelay);
              throw const VtopError_SessionExpired();
            }
            return label;
          },
        );
      }

      final a = run('a', const Duration(milliseconds: 10));
      // Started before A's failure invalidates the cached client, so B's first
      // attempt reuses the session A's attempt is on. It fails late enough that
      // A's retry has already started its login — which is the state the second
      // expiry used to break.
      final b = run('b', const Duration(milliseconds: 600));

      // A's retry is now inside the login, and it is held open long enough for
      // B to fail and ask for a client too.
      await secondLoginStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      releaseSecondLogin.complete();

      expect(await a, 'a');
      expect(await b, 'b');
      expect(
        harness.loginCalls,
        2,
        reason: 'the two retries share the login, rather than one each',
      );
    });

    // The retry classifier used to match on the error *message*, and
    // LoginOtpExpired reads "OTP for login has expired" — so it matched
    // "expired" and got retried. The retry is a fresh credentials POST, i.e.
    // another OTP email, fired at the exact moment the user is already holding
    // a code. Matched on type now, so this must not retry.
    test('an expired OTP is not retried', () async {
      var attempts = 0;

      await expectLater(
        service.executeWithRetry<String>(
          credentials: _credentials,
          operation: (_) async {
            attempts++;
            throw const VtopError_LoginOtpExpired();
          },
        ),
        throwsA(isA<VtopError_LoginOtpExpired>()),
      );

      expect(attempts, 1);
      expect(harness.loginCalls, 1);
    });

    test('a network error is not retried', () async {
      var attempts = 0;

      await expectLater(
        service.executeWithRetry<String>(
          credentials: _credentials,
          operation: (_) async {
            attempts++;
            throw const VtopError_NetworkError();
          },
        ),
        throwsA(isA<VtopError_NetworkError>()),
      );

      expect(attempts, 1);
    });

    test('the last attempt rethrows rather than looping forever', () async {
      var attempts = 0;

      await expectLater(
        service.executeWithRetry<String>(
          credentials: _credentials,
          operation: (_) async {
            attempts++;
            throw const VtopError_SessionExpired();
          },
        ),
        throwsA(isA<VtopError_SessionExpired>()),
      );

      expect(attempts, 2, reason: 'maxRetries defaults to 2 attempts');
    });

    // An operation that arrives while the prompt is up must wait for the code
    // rather than reset the session: resetting cancels the prompt under the
    // user (and wastes the code), and the retry it triggers is a fresh
    // credentials POST, i.e. a second email.
    test('an operation arriving during the OTP prompt joins it', () async {
      harness.onLogin = (int call) async {
        if (call == 1) throw const VtopError_LoginOtpRequired();
      };
      final sameAccount = Credentials(
        registrationNumber: 'A',
        password: 'p',
        semSubId: 'AP2024255',
      );

      final pending = service.getClient(username: 'A', password: 'p');
      await pumpEventQueue();
      expect(service.isOtpPending, isTrue);

      var ran = false;
      final retried = service.executeWithRetry<String>(
        credentials: sameAccount,
        operation: (_) async {
          ran = true;
          return 'ok';
        },
      );
      await pumpEventQueue();

      expect(ran, isFalse, reason: 'it waits for the code instead');
      expect(service.isOtpPending, isTrue);
      expect(harness.loginCalls, 1, reason: 'no second credentials POST');

      await service.submitLoginOtp(_Harness.validOtp);

      expect(await retried, 'ok');
      expect(harness.loginCalls, 1);
      expect(await pending, isA<_FakeVtopClient>());
    });
  });

  group('demo mode', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await DemoService.instance.setDemoMode(true);
    });

    tearDown(() async => DemoService.instance.setDemoMode(false));

    // The demo account has no VTOP credentials to log in with. Reaching the
    // bridge at all would mean posting placeholder credentials at VTOP.
    test('never reaches the bridge', () async {
      await expectLater(
        service.getClient(username: 'A', password: 'p'),
        throwsA(isA<DemoModeException>()),
      );

      expect(harness.loginCalls, 0);
      expect(harness.clientsCreated, 0);
    });
  });
}
