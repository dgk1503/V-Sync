import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/features/auth/repository/auth_remote_repository.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';
import 'package:vit_ap_student_app/features/auth/services/otp_auto_fill.dart';

part 'login_otp_challenge.g.dart';

/// How long a freshly issued OTP stays valid, and therefore how long Resend is
/// locked out for.
const int kOtpChallengeWindowSeconds = 180;

/// What the prompt is currently doing.
///
/// One enum rather than a set of booleans, so "submitting and resending at the
/// same time" is not a state the type system allows.
enum OtpActivity { idle, waiting, submitting, resending }

/// What the automatic Gmail reader is doing, as the prompt shows it.
enum OtpAutoPhase {
  /// Not set up, or switched off: the code has to be typed.
  notEnabled,

  /// Looking in Gmail for the code.
  fetching,

  /// A code was found and is being checked with VTOP.
  verifying,

  /// VTOP accepted it: the prompt shows a tick, then closes by itself.
  succeeded,

  /// The reader stopped ([OtpChallenge.autoStatus] says why).
  failed,
}

/// How long the success tick is shown before the prompt closes.
const Duration kOtpSuccessHold = Duration(milliseconds: 1700);

/// Whether the prompt covers the app or has collapsed to the floating capsule.
enum OtpPresentation { expanded, minimized }

/// The prompt's whole state.
///
/// Presentation, countdown and the error all live here rather than in the
/// widget, so none of it can be lost when the tree rebuilds underneath it.
class OtpChallenge {
  const OtpChallenge({
    required this.isActive,
    this.activity = OtpActivity.idle,
    this.presentation = OtpPresentation.expanded,
    this.remainingSeconds = 0,
    this.message = '',
    this.errorMessage,
    this.autoStatus,
    this.autoPhase,
  });

  /// No challenge. Nothing is rendered.
  const OtpChallenge.idle()
    : isActive = false,
      activity = OtpActivity.idle,
      presentation = OtpPresentation.expanded,
      remainingSeconds = 0,
      message = '',
      errorMessage = null,
      autoStatus = null,
      autoPhase = null;

  factory OtpChallenge.active({
    required String message,
    OtpActivity activity = OtpActivity.waiting,
    OtpPresentation presentation = OtpPresentation.expanded,
    int remainingSeconds = kOtpChallengeWindowSeconds,
    String? errorMessage,
  }) {
    if (remainingSeconds < 0) {
      throw ArgumentError.value(
        remainingSeconds,
        'remainingSeconds',
        'must not be negative',
      );
    }
    return OtpChallenge(
      isActive: true,
      activity: activity,
      presentation: presentation,
      remainingSeconds: remainingSeconds,
      message: message,
      errorMessage: errorMessage,
    );
  }

  final bool isActive;
  final OtpActivity activity;
  final OtpPresentation presentation;
  final int remainingSeconds;
  final String message;
  final String? errorMessage;

  /// What the automatic Gmail reader is doing ("Looking for the code in your
  /// Gmail..."), or why it stopped; null when it is not set up.
  final String? autoStatus;

  /// Where the automatic reader is; null until it has said (it takes a moment to
  /// find out whether it is set up).
  final OtpAutoPhase? autoPhase;

  bool get isSucceeded => autoPhase == OtpAutoPhase.succeeded;

  bool get isMinimized => presentation == OtpPresentation.minimized;
  bool get isSubmitting => activity == OtpActivity.submitting;
  bool get isResending => activity == OtpActivity.resending;
  bool get isBusy => isSubmitting || isResending;

  /// Resend is only offered once the window has elapsed. There is deliberately
  /// no "resend early": a second code invalidates the first, and VTOP does not
  /// say so.
  bool get canResend => isActive && remainingSeconds <= 0 && !isBusy;

  OtpChallenge copyWith({
    OtpActivity? activity,
    OtpPresentation? presentation,
    int? remainingSeconds,
    String? message,
    String? errorMessage,
    bool clearError = false,
    String? autoStatus,
    bool clearAutoStatus = false,
    OtpAutoPhase? autoPhase,
  }) {
    if (!isActive) {
      throw StateError('An idle OTP challenge cannot be updated.');
    }
    return OtpChallenge(
      isActive: true,
      activity: activity ?? this.activity,
      presentation: presentation ?? this.presentation,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      autoStatus: clearAutoStatus ? null : (autoStatus ?? this.autoStatus),
      autoPhase: autoPhase ?? this.autoPhase,
    );
  }

  static String formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Owns the one OTP prompt.
///
/// `keepAlive` because this outlives any single screen: a challenge raised by a
/// background fetch must still be there after the user navigates away.
@Riverpod(keepAlive: true)
class LoginOtpChallenge extends _$LoginOtpChallenge {
  late AuthRemoteRepository _repository;

  @override
  OtpChallenge build() {
    _repository = ref.watch(authRemoteRepositoryProvider);
    ref.onDispose(() {
      _stopTicker();
      _auto?.cancel();
      _successTimer?.cancel();
    });
    return const OtpChallenge.idle();
  }

  /// Raised when VTOP demands a code.
  ///
  /// If a challenge is already up this re-surfaces it rather than starting a
  /// second one. Two prompts for two requests would be ambiguous, and dropping
  /// the second request - which is what ignoring it amounts to - would leave
  /// the operation that asked for it waiting forever.
  void requestOtp() {
    if (state.isActive) {
      state = state.copyWith(
        presentation: OtpPresentation.expanded,
        activity: OtpActivity.waiting,
        message: 'Additional verification required. OTP sent to your email.',
        clearError: true,
      );
      return;
    }

    state = OtpChallenge.active(
      message: 'Additional verification required. OTP sent to your email.',
    );
    _startTicker();
    _startAutoRead(DateTime.now());
  }

  void minimize() {
    if (!state.isActive) return;
    // Nothing left to show once the code has worked: just close.
    if (state.isSucceeded) {
      _finish();
      return;
    }
    state = state.copyWith(presentation: OtpPresentation.minimized);
  }

  Timer? _successTimer;

  void _finish() {
    _successTimer?.cancel();
    _successTimer = null;
    _stopTicker();
    _auto?.cancel();
    state = const OtpChallenge.idle();
  }

  void reopen() {
    if (!state.isActive) return;
    state = state.copyWith(presentation: OtpPresentation.expanded);
  }

  /// The user gave up, or the operation was cancelled. The overlay turns this
  /// into "do not prompt again", and the pending VTOP request is abandoned so
  /// whatever was waiting on it fails instead of hanging.
  void dismiss() {
    if (!state.isActive) return;
    _finish();
  }

  /// [automatic] is true when the code came from Gmail: then a success is shown
  /// (a tick) before the prompt closes, instead of it vanishing at once.
  Future<void> submitOtp(String code, {bool automatic = false}) async {
    if (!state.isActive || state.isBusy) return;

    final sanitized = code.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length != 6) {
      state = state.copyWith(errorMessage: 'Please enter a valid 6-digit OTP.');
      return;
    }

    state = state.copyWith(activity: OtpActivity.submitting, clearError: true);

    final result = await _repository.submitLoginOtp(sanitized);
    switch (result) {
      case Left(value: final failure):
        // A rejected code always brings the prompt back into view: the user has
        // to see why it did not work, even if they had collapsed it.
        state = state.copyWith(
          activity: OtpActivity.waiting,
          presentation: OtpPresentation.expanded,
          errorMessage: failure.message,
        );
      case Right():
        _stopTicker();
        _auto?.cancel();
        if (automatic && !state.isMinimized) {
          // Show the tick, then close. The login carries on behind it.
          state = state.copyWith(
            activity: OtpActivity.waiting,
            clearError: true,
            clearAutoStatus: true,
            autoPhase: OtpAutoPhase.succeeded,
          );
          _successTimer?.cancel();
          _successTimer = Timer(kOtpSuccessHold, () {
            if (ref.mounted && state.isActive) _finish();
          });
        } else {
          state = const OtpChallenge.idle();
        }
    }
  }

  Future<void> resendOtp() async {
    if (!state.canResend) return;

    state = state.copyWith(activity: OtpActivity.resending, clearError: true);

    final result = await _repository.resendLoginOtp();
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(
          activity: OtpActivity.waiting,
          errorMessage: failure.message,
        );
      case Right():
        state = state.copyWith(
          activity: OtpActivity.waiting,
          remainingSeconds: kOtpChallengeWindowSeconds,
          message: 'A new OTP has been sent to your registered email.',
          clearError: true,
        );
        _startTicker();
        // A new code means the old one is dead: look for the new mail.
        _startAutoRead(DateTime.now());
    }
  }

  // --- automatic reading from Gmail ----------------------------------------

  OtpCancel? _auto;

  void _startAutoRead(DateTime issuedAfter) {
    _auto?.cancel();
    final cancel = _auto = OtpCancel();
    unawaited(_autoRead(issuedAfter, cancel));
  }

  /// Looks for the code in the student's Gmail and enters it, if they have set
  /// that up. Typing the code by hand always still works, and a code that is
  /// refused (an older mail) is skipped in favour of a newer one.
  Future<void> _autoRead(DateTime issuedAfter, OtpCancel cancel) async {
    try {
      await _autoReadLoop(issuedAfter, cancel);
    } catch (_) {
      // The automatic reader is a convenience on top of typing the code. Whatever
      // goes wrong inside it (storage that cannot be read, say) must leave the
      // prompt exactly as it is, never crash it.
    }
  }

  Future<void> _autoReadLoop(DateTime issuedAfter, OtpCancel cancel) async {
    final autoFill = ref.read(otpAutoFillProvider);
    final tried = <int>{};

    bool stopped() => cancel.isCancelled || !ref.mounted || !state.isActive;

    if (!await autoFill.isReady()) {
      if (!stopped()) {
        state = state.copyWith(autoPhase: OtpAutoPhase.notEnabled);
      }
      return;
    }
    if (stopped()) return;

    while (!stopped()) {
      OtpFound? found;
      try {
        state = state.copyWith(
          autoPhase: OtpAutoPhase.fetching,
          clearAutoStatus: true,
        );
        found = await autoFill.find(
          issuedAfter: issuedAfter,
          ignoreUids: tried,
          cancel: cancel,
        );
      } on OtpReaderException catch (e) {
        if (stopped()) return;
        if (e.problem == OtpReaderProblem.cancelled) return;
        state = state.copyWith(
          autoPhase: OtpAutoPhase.failed,
          autoStatus: e.message,
        );
        return;
      } catch (_) {
        if (stopped()) return;
        state = state.copyWith(
          autoPhase: OtpAutoPhase.failed,
          autoStatus: 'Could not read your Gmail.',
        );
        return;
      }
      if (stopped()) return;
      if (found == null) {
        state = state.copyWith(autoPhase: OtpAutoPhase.notEnabled);
        return;
      }

      state = state.copyWith(autoPhase: OtpAutoPhase.verifying);
      await submitOtp(found.code, automatic: true);
      if (stopped()) return; // it worked, or the prompt was closed

      // Refused: that mail was an older code. Look for a newer one.
      tried.add(found.uid);
    }
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isActive) {
        timer.cancel();
        return;
      }
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        _ticker = null;
        state = state.copyWith(
          remainingSeconds: 0,
          message: 'OTP expired. Tap resend to get a new one.',
          errorMessage: 'OTP expired. Please resend OTP.',
        );
        return;
      }
      state = state.copyWith(remainingSeconds: next);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Timer? _ticker;
}
