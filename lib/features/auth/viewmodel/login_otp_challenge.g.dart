// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_otp_challenge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the one OTP prompt.
///
/// `keepAlive` because this outlives any single screen: a challenge raised by a
/// background fetch must still be there after the user navigates away.

@ProviderFor(LoginOtpChallenge)
final loginOtpChallengeProvider = LoginOtpChallengeProvider._();

/// Owns the one OTP prompt.
///
/// `keepAlive` because this outlives any single screen: a challenge raised by a
/// background fetch must still be there after the user navigates away.
final class LoginOtpChallengeProvider
    extends $NotifierProvider<LoginOtpChallenge, OtpChallenge> {
  /// Owns the one OTP prompt.
  ///
  /// `keepAlive` because this outlives any single screen: a challenge raised by a
  /// background fetch must still be there after the user navigates away.
  LoginOtpChallengeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginOtpChallengeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginOtpChallengeHash();

  @$internal
  @override
  LoginOtpChallenge create() => LoginOtpChallenge();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OtpChallenge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OtpChallenge>(value),
    );
  }
}

String _$loginOtpChallengeHash() => r'90b7fb4db4a299bbe74488d7fb77802883a1016b';

/// Owns the one OTP prompt.
///
/// `keepAlive` because this outlives any single screen: a challenge raised by a
/// background fetch must still be there after the user navigates away.

abstract class _$LoginOtpChallenge extends $Notifier<OtpChallenge> {
  OtpChallenge build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<OtpChallenge, OtpChallenge>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OtpChallenge, OtpChallenge>,
              OtpChallenge,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
