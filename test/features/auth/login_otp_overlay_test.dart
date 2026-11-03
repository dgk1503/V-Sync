import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The lifecycle ordering Android reports when the user switches to another
/// app (Gmail, to read the code) ...
void leaveApp(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

/// ... and when they come back.
void returnToApp(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

    testWidgets('the OTP boxes stay inside the card on a narrow phone', (
      tester,
    ) async {
      // Six fixed 46dp boxes plus gaps need 306dp, which does not fit inside the
      // card on a 360dp screen: the row overflowed it. Guards the width.
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no overflow on 360dp');

      // Every box must sit within the card's own horizontal bounds.
      final card = tester.getRect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Container),
        ).first,
      );
      final field = tester.getRect(find.byType(TextField));
      expect(
        field.left,
        greaterThanOrEqualTo(card.left),
        reason: 'the boxes must not start left of the card',
      );
      expect(
        field.right,
        lessThanOrEqualTo(card.right),
        reason: 'the boxes must not run past the card edge',
      );
      await unmount(tester, container);
    });

    testWidgets('the minimise control is present and collapses the prompt', (
      tester,
    ) async {
      // The user should not have to guess at a bare dash.
      final handle = tester.ensureSemantics();
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_double_arrow_down_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Minimise'), findsOneWidget);

      await tester.tap(find.byKey(const Key('otp-minimise')));
      await tester.pump();
      expect(find.text('Verification'), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      await unmount(tester, container);
      handle.dispose();
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

    testWidgets('tapping the boxes brings the keyboard back', (tester) async {
      // The boxes sit over the field and their empty `Text` hit-tests as text,
      // so a tap on a box was swallowed instead of reaching the field. The only
      // time the keyboard ever appeared was the prompt's own initial
      // requestFocus: tapping to type again did nothing.
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      final focusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      expect(focusNode.hasFocus, isTrue, reason: 'the prompt focuses itself');

      // What the OS does to focus when the app is backgrounded — or when the
      // user dismisses the keyboard by hand.
      focusNode.unfocus();
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);

      // By position, not by widget: the field itself is deliberately out of the
      // hit-test path, so `tap(find.byType(TextField))` would only warn that it
      // was never hit. Where the boxes are is what a finger touches.
      await tester.tapAt(tester.getCenter(find.byType(TextField)));
      await tester.pump();

      expect(
        focusNode.hasFocus,
        isTrue,
        reason: 'tapping a box must focus the field, and so open the keyboard',
      );
      await unmount(tester, container);
    });

    testWidgets('tapping the boxes re-asks for the keyboard', (tester) async {
      // The state the user is actually in after reading the code in Gmail:
      // the field still holds focus, but the OS dropped the keyboard. Asking
      // for focus is a no-op in that state, so the platform has to be asked
      // for the keyboard explicitly.
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(tester.testTextInput.register);

      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      final focusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      expect(focusNode.hasFocus, isTrue);

      calls.clear();
      await tester.tapAt(tester.getCenter(find.byType(TextField)));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      expect(
        calls.where((call) => call.method == 'TextInput.show'),
        isNotEmpty,
        reason: 'tapping must ask for the keyboard even when focused',
      );
      await unmount(tester, container);
    });

    testWidgets('leaving the app collapses the prompt to the capsule',
        (tester) async {
      // The card cannot keep its keyboard while the app is away, and coming
      // back to a card with no keyboard reads as "the prompt disappeared". The
      // capsule is the state that survives the trip: no keyboard needed, the
      // countdown still visible, one tap back to the boxes.
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();
      expect(find.text('Verification'), findsOneWidget);

      leaveApp(tester);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Verification'), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // And it is still there on the way back, ready to be reopened.
      returnToApp(tester);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(
        find.textContaining('OTP '),
        findsOneWidget,
        reason: 'the capsule carries the countdown',
      );
      await unmount(tester, container);
    });

    testWidgets('tapping the capsule brings the card and the keyboard back',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(tester.testTextInput.register);

      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      leaveApp(tester);
      returnToApp(tester);
      await tester.pump();
      calls.clear();

      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Verification'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
        reason: 'reopening must focus the boxes',
      );
      expect(
        calls.where((call) => call.method == 'TextInput.show'),
        isNotEmpty,
        reason: 'and must ask the platform for the keyboard',
      );
      await unmount(tester, container);
    });

    testWidgets('a transient interruption keeps the prompt expanded and focused',
        (tester) async {
      // Android reports `inactive` for the notification shade, a permission
      // dialog, the app switcher. Only a real trip away collapses the prompt —
      // and for the interruptions that do not, the card stays up and has to
      // keep its keyboard.
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(tester.testTextInput.register);

      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Verification'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(
        calls.where((call) => call.method == 'TextInput.show'),
        isNotEmpty,
        reason: 'the card that stayed up must keep its keyboard',
      );
      await unmount(tester, container);
    });

    testWidgets('the code typed so far survives the collapse', (tester) async {
      // Collapsing must not cost the user the digits they already entered:
      // the card is unmounted when the prompt minimizes, so the controller
      // lives above it.
      final container = await mountApp(tester);
      container.read(loginOtpChallengeProvider.notifier).requestOtp();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      leaveApp(tester);
      returnToApp(tester);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await unmount(tester, container);
    });
  });
}
