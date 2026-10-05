import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/auth/view/widgets/login_otp_overlay.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';

/// Starts idle so each test can drive the notifier itself.
class _IdleChallenge extends LoginOtpChallenge {
  @override
  OtpChallenge build() => const OtpChallenge.idle();
}

/// Mounts the app with the prompt permanently installed, exactly as
/// `MaterialApp.builder` does in production.
Future<ProviderContainer> mountApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loginOtpChallengeProvider.overrideWith(_IdleChallenge.new)],
      child: MaterialApp(
        theme: getThemeData(isDarkMode: false),
        home: const Scaffold(body: SizedBox.expand()),
        builder: (context, child) =>
            LoginOtpOverlay(child: SizedBox.expand(child: child!)),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(LoginOtpOverlay)),
  );
}

/// Every prompt test ends by dismissing the challenge and unmounting.
///
/// The countdown runs on a real periodic timer and the framework's "no pending
/// timers" check runs before `addTearDown`, so it has to be cancelled inside
/// the test body. Dismissing is the honest way to do that: it is the same path
/// the Cancel button takes.
Future<void> unmount(WidgetTester tester, ProviderContainer container) async {
  container.read(loginOtpChallengeProvider.notifier).dismiss();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  group('OtpChallenge state', () {
    test('idle renders nothing', () {
      const state = OtpChallenge.idle();
      expect(state.isActive, isFalse);
      expect(state.canResend, isFalse);
    });

    test('an idle challenge cannot be updated', () {
      expect(
        () => const OtpChallenge.idle().copyWith(message: 'x'),
        throwsStateError,
      );
    });

    test('one activity makes competing operations unrepresentable', () {
      final submitting = OtpChallenge.active(
        message: 'm',
      ).copyWith(activity: OtpActivity.submitting);

      expect(submitting.isSubmitting, isTrue);
      expect(submitting.isResending, isFalse);
      expect(submitting.canResend, isFalse);
    });

    test('negative remaining seconds is rejected at construction', () {
      expect(
        () => OtpChallenge.active(message: 'm', remainingSeconds: -1),
        throwsArgumentError,
      );
    });

    test('resend is locked out until the window elapses', () {
      final fresh = OtpChallenge.active(message: 'm');
      expect(
        fresh.canResend,
        isFalse,
        reason: 'the code just sent is still valid',
      );
      expect(fresh.copyWith(remainingSeconds: 0).canResend, isTrue);
    });

    test('an error clears only via clearError, never by passing null', () {
      // `errorMessage ?? this.errorMessage` means null silently keeps the old
      // error, so a caller meaning "forget it" would do nothing.
      final withError = OtpChallenge.active(
        message: 'm',
      ).copyWith(errorMessage: 'Invalid OTP');

      expect(withError.copyWith(errorMessage: null).errorMessage, 'Invalid OTP');
      expect(withError.copyWith(clearError: true).errorMessage, isNull);
    });

    test('formats the countdown as mm:ss', () {
      expect(OtpChallenge.formatSeconds(180), '03:00');
      expect(OtpChallenge.formatSeconds(65), '01:05');
      expect(OtpChallenge.formatSeconds(9), '00:09');
    });
  });

  group('LoginOtpOverlay', () {
    testWidgets('renders only the app while no challenge is active', (
      tester,
    ) async {
      final container = await mountApp(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginOtpOverlay), findsOneWidget);
      expect(find.text('Verification'), findsNothing);
      expect(find.text('Verify'), findsNothing);
      await unmount(tester, container);
    });

    testWidgets('raising a challenge shows the prompt', (tester) async {
      final container = await mountApp(tester);

      // No navigator key, no overlay entry to find: state is the only input.
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.textContaining('Resend ('), findsOneWidget);
      await unmount(tester, container);
    });

    testWidgets('minimise collapses to the capsule and back', (tester) async {
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      await tester.tap(find.byKey(const Key('otp-minimise')));
      await tester.pump();
      expect(find.text('Verification'), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();
      expect(find.text('Verification'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester, container);
    });

    testWidgets('a second challenge re-surfaces the prompt', (tester) async {
      // Ignoring the second request, which the old "already showing" flag did,
      // left whichever operation asked for it waiting on a completer that
      // nothing would ever complete.
      final container = await mountApp(tester);
      final notifier = container.read(loginOtpChallengeProvider.notifier);

      notifier.requestOtp();
      await tester.pump();
      notifier.minimize();
      await tester.pump();
      expect(find.text('Verification'), findsNothing);

      notifier.requestOtp();
      await tester.pump();

      expect(find.text('Verification'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester, container);
    });

    testWidgets('the prompt survives the subtree rebuilding', (tester) async {
      final container = await mountApp(tester);
      final notifier = container.read(loginOtpChallengeProvider.notifier);

      notifier.requestOtp();
      await tester.pump();
      notifier.minimize();
      await tester.pump();

      tester.element(find.byType(LoginOtpOverlay)).markNeedsBuild();
      await tester.pump();

      // It lives above the Navigator precisely so a rebuild of the app beneath
      // cannot lose it.
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      await unmount(tester, container);
    });

    testWidgets('the OTP boxes focus without an Overlay under the app', (
      tester,
    ) async {
      // Both `EditableText` and `Tooltip` require an Overlay ancestor, and the
      // Navigator's Overlay is a sibling below this point. The prompt supplies
      // its own; without it the field throws on focus.
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '123456',
      );
      await unmount(tester, container);
    });

    testWidgets('the card lifts above the keyboard', (tester) async {
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      final before = tester.getRect(find.byType(TextField)).bottom;

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.reset);
      await tester.pump();

      expect(find.text('Verification'), findsOneWidget);
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThan(before),
        reason: 'the boxes must not end up under the IME',
      );
      await unmount(tester, container);
    });
  });
}
