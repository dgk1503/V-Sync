import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vit_ap_student_app/core/error/failure.dart';
import 'package:vit_ap_student_app/features/auth/repository/auth_remote_repository.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';
import 'package:vit_ap_student_app/features/auth/services/otp_auto_fill.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';

/// VTOP, as far as the prompt can tell: it accepts the codes in [accepts].
class _FakeAuth implements AuthRemoteRepository {
  _FakeAuth({this.accepts = const {}});

  final Set<String> accepts;
  final submitted = <String>[];
  int resends = 0;

  @override
  Future<Either<Failure, void>> submitLoginOtp(String otpCode) async {
    submitted.add(otpCode);
    return accepts.contains(otpCode)
        ? const Right(null)
        : Left(Failure('Invalid OTP'));
  }

  @override
  Future<Either<Failure, void>> resendLoginOtp() async {
    resends++;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A reader that blows up before it can even say whether it is set up.
class _BrokenAutoFill implements OtpAutoFill {
  @override
  Future<bool> isReady() async => throw StateError('storage unreadable');

  @override
  Future<OtpFound?> find({
    required DateTime issuedAfter,
    Set<int> ignoreUids = const {},
    required OtpCancel cancel,
  }) async => throw StateError('never reached');
}

/// Gmail, as the prompt sees it: each call to [find] takes the next answer.
class _FakeAutoFill implements OtpAutoFill {
  _FakeAutoFill(this.script, {this.ready = true});

  final List<FutureOr<OtpFound?> Function()> script;
  final bool ready;
  final seenIgnore = <Set<int>>[];
  final seenIssued = <DateTime>[];
  OtpCancel? lastCancel;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<OtpFound?> find({
    required DateTime issuedAfter,
    Set<int> ignoreUids = const {},
    required OtpCancel cancel,
  }) async {
    seenIssued.add(issuedAfter);
    seenIgnore.add({...ignoreUids});
    lastCancel = cancel;
    final i = seenIssued.length - 1;
    return script[i < script.length ? i : script.length - 1]();
  }
}

OtpFound found(String code, int uid) => OtpFound(code: code, uid: uid);

ProviderContainer container(_FakeAuth auth, _FakeAutoFill autoFill) {
  final c = ProviderContainer(
    overrides: [
      authRemoteRepositoryProvider.overrideWithValue(auth),
      otpAutoFillProvider.overrideWithValue(autoFill),
    ],
  );
  addTearDown(() {
    c.read(loginOtpChallengeProvider.notifier).dismiss();
    c.dispose();
  });
  c.listen(loginOtpChallengeProvider, (_, _) {});
  return c;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

/// Waits for the tick that follows a code from Gmail to finish and the prompt to
/// close itself.
Future<void> waitOutTick() =>
    Future<void>.delayed(kOtpSuccessHold + const Duration(milliseconds: 120));

void main() {
  test(
    'with Gmail not set up, the prompt waits for a typed code and says nothing',
    () async {
      final c = container(
        _FakeAuth(),
        _FakeAutoFill([() => null], ready: false),
      );

      c.read(loginOtpChallengeProvider.notifier).requestOtp();
      await settle();

      final s = c.read(loginOtpChallengeProvider);
      expect(s.isActive, isTrue);
      expect(s.autoPhase, OtpAutoPhase.notEnabled);
      expect(s.autoStatus, isNull);
    },
  );

  test(
    'a code found in Gmail is entered, shown as a success, then the prompt closes',
    () async {
      final auth = _FakeAuth(accepts: {'488245'});
      final c = container(auth, _FakeAutoFill([() => found('488245', 7)]));

      c.read(loginOtpChallengeProvider.notifier).requestOtp();
      await settle();

      expect(auth.submitted, ['488245']);
      final s = c.read(loginOtpChallengeProvider);
      expect(s.isActive, isTrue, reason: 'still up, showing the tick');
      expect(s.isSucceeded, isTrue);

      await waitOutTick();
      expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
    },
  );

  test(
    'a code typed by hand closes the prompt at once, with no tick',
    () async {
      final auth = _FakeAuth(accepts: {'123456'});
      final c = container(auth, _FakeAutoFill([() => null], ready: false));
      final notifier = c.read(loginOtpChallengeProvider.notifier);

      notifier.requestOtp();
      await settle();
      await notifier.submitOtp('123456');

      expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
    },
  );

  test('closing the prompt during the tick closes it at once', () async {
    final auth = _FakeAuth(accepts: {'488245'});
    final c = container(auth, _FakeAutoFill([() => found('488245', 7)]));
    final notifier = c.read(loginOtpChallengeProvider.notifier);

    notifier.requestOtp();
    await settle();
    expect(c.read(loginOtpChallengeProvider).isSucceeded, isTrue);

    notifier.minimize();
    expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
  });

  test(
    'a minimised prompt that succeeds just closes, without the tick',
    () async {
      final wait = Completer<OtpFound?>();
      final auth = _FakeAuth(accepts: {'488245'});
      final c = container(auth, _FakeAutoFill([() => wait.future]));
      final notifier = c.read(loginOtpChallengeProvider.notifier);

      notifier.requestOtp();
      await settle();
      notifier.minimize();
      wait.complete(found('488245', 7));
      await settle();

      expect(auth.submitted, ['488245']);
      expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
    },
  );

  test('says what it is doing while it waits', () async {
    final wait = Completer<OtpFound?>();
    final c = container(_FakeAuth(), _FakeAutoFill([() => wait.future]));

    c.read(loginOtpChallengeProvider.notifier).requestOtp();
    await settle();

    expect(c.read(loginOtpChallengeProvider).autoPhase, OtpAutoPhase.fetching);
    wait.complete(null);
  });

  test('a refused code is skipped for a newer one', () async {
    // The first mail is an older code VTOP no longer accepts.
    final auth = _FakeAuth(accepts: {'222222'});
    final autoFill = _FakeAutoFill([
      () => found('111111', 1),
      () => found('222222', 2),
    ]);
    final c = container(auth, autoFill);

    c.read(loginOtpChallengeProvider.notifier).requestOtp();
    await settle();

    expect(auth.submitted, ['111111', '222222']);
    expect(autoFill.seenIgnore.last, {
      1,
    }, reason: 'the refused mail is skipped');
    expect(c.read(loginOtpChallengeProvider).isSucceeded, isTrue);
    await waitOutTick();
    expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
  });

  test('when no code arrives it says so, and typing still works', () async {
    final auth = _FakeAuth(accepts: {'654321'});
    final c = container(
      auth,
      _FakeAutoFill([
        () => throw const OtpReaderException(OtpReaderProblem.timedOut),
      ]),
    );
    final notifier = c.read(loginOtpChallengeProvider.notifier);

    notifier.requestOtp();
    await settle();

    final s = c.read(loginOtpChallengeProvider);
    expect(s.isActive, isTrue);
    expect(s.autoPhase, OtpAutoPhase.failed);
    expect(s.autoStatus, contains('No code arrived'));
    expect(auth.submitted, isEmpty);

    await notifier.submitOtp('654321');
    expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
  });

  test('a refused Gmail password is explained, not retried', () async {
    final autoFill = _FakeAutoFill([
      () => throw const OtpReaderException(OtpReaderProblem.invalidCredentials),
    ]);
    final c = container(_FakeAuth(), autoFill);

    c.read(loginOtpChallengeProvider.notifier).requestOtp();
    await settle();

    expect(
      c.read(loginOtpChallengeProvider).autoStatus,
      contains('did not accept'),
    );
    expect(autoFill.seenIssued, hasLength(1));
  });

  test('closing the prompt stops the read', () async {
    final wait = Completer<OtpFound?>();
    final auth = _FakeAuth(accepts: {'333333'});
    final autoFill = _FakeAutoFill([() => wait.future]);
    final c = container(auth, autoFill);
    final notifier = c.read(loginOtpChallengeProvider.notifier);

    notifier.requestOtp();
    await settle();
    notifier.dismiss();
    expect(autoFill.lastCancel!.isCancelled, isTrue);

    // A code that turns up afterwards is not entered.
    wait.complete(found('333333', 9));
    await settle();
    expect(auth.submitted, isEmpty);
  });

  test('a code typed by hand while Gmail is being read wins', () async {
    final wait = Completer<OtpFound?>();
    final auth = _FakeAuth(accepts: {'123456', '999999'});
    final c = container(auth, _FakeAutoFill([() => wait.future]));
    final notifier = c.read(loginOtpChallengeProvider.notifier);

    notifier.requestOtp();
    await settle();
    await notifier.submitOtp('123456');
    expect(c.read(loginOtpChallengeProvider).isActive, isFalse);

    wait.complete(found('999999', 4));
    await settle();
    expect(auth.submitted, ['123456'], reason: 'the late code is not entered');
  });

  test('Resend starts a fresh read for the new code', () async {
    final autoFill = _FakeAutoFill([
      () => throw const OtpReaderException(OtpReaderProblem.timedOut),
      () => found('777777', 12),
    ]);
    final auth = _FakeAuth(accepts: {'777777'});
    final c = container(auth, autoFill);
    final notifier = c.read(loginOtpChallengeProvider.notifier);

    notifier.requestOtp();
    await settle();
    expect(autoFill.seenIssued, hasLength(1));

    // Resend is only offered once the window has run out.
    c.read(loginOtpChallengeProvider.notifier).state = c
        .read(loginOtpChallengeProvider)
        .copyWith(remainingSeconds: 0);
    await notifier.resendOtp();
    await settle();

    expect(auth.resends, 1);
    expect(autoFill.seenIssued, hasLength(2));
    expect(
      autoFill.seenIssued.last.isAfter(autoFill.seenIssued.first) ||
          autoFill.seenIssued.last == autoFill.seenIssued.first,
      isTrue,
    );
    expect(auth.submitted, ['777777']);
    await waitOutTick();
    expect(c.read(loginOtpChallengeProvider).isActive, isFalse);
  });

  test('a reader that breaks leaves the prompt exactly as it was', () async {
    final c = ProviderContainer(
      overrides: [
        authRemoteRepositoryProvider.overrideWithValue(_FakeAuth()),
        otpAutoFillProvider.overrideWithValue(_BrokenAutoFill()),
      ],
    );
    addTearDown(() {
      c.read(loginOtpChallengeProvider.notifier).dismiss();
      c.dispose();
    });
    c.listen(loginOtpChallengeProvider, (_, _) {});

    c.read(loginOtpChallengeProvider.notifier).requestOtp();
    await settle();

    final s = c.read(loginOtpChallengeProvider);
    expect(s.isActive, isTrue);
    expect(s.autoStatus, isNull);
    expect(s.autoPhase, isNull);
  });
}
