import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';
import 'package:vit_ap_student_app/features/whats_new/view/whats_new_card.dart';

/// An OTP prompt that is never up, without the real one's network wiring.
class _NoOtp extends LoginOtpChallenge {
  @override
  OtpChallenge build() => const OtpChallenge.idle();
}

void main() {
  group('when the card is due', () {
    test('a fresh install has not seen it', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WhatsNew.shouldShow(), isTrue);
    });

    test('once seen, it is not due again', () async {
      SharedPreferences.setMockInitialValues({});
      await WhatsNew.markSeen();
      expect(await WhatsNew.shouldShow(), isFalse);
    });

    test('an older version having been seen does not count', () async {
      SharedPreferences.setMockInitialValues({
        'whats_new_acknowledged_version': '1.3.2',
      });
      expect(await WhatsNew.shouldShow(), isTrue);
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WhatsNewCard())),
      );
    }

    testWidgets('carries the title and a thank-you', (tester) async {
      await pump(tester);
      expect(find.text("What's new in VSync 1.4.0"), findsOneWidget);
      expect(find.textContaining('thank you'), findsOneWidget);
      expect(find.textContaining('launch'), findsOneWidget);
    });

    testWidgets('lists six numbered points, the dock first', (tester) async {
      await pump(tester);
      for (var i = 1; i <= 6; i++) {
        expect(find.text('$i.'), findsOneWidget);
      }
      expect(kWhatsNewPoints.length, 6);
      expect(kWhatsNewPoints.first.title, 'Thumb Dock');
      expect(kWhatsNewPoints.first.tag, 'beta');
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('New tools'), findsOneWidget);
      expect(find.text('A better mess menu'), findsOneWidget);
    });

    testWidgets('is closed with "got it"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const WhatsNewCard(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsNewCard), findsOneWidget);

      await tester.tap(find.text('got it'));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsNewCard), findsNothing);
    });

    testWidgets('a tap beside the card does not close it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const WhatsNewCard(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsNewCard), findsOneWidget);
    });

    testWidgets('stays black and white whatever accent the theme has', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      for (final brightness in [Brightness.dark, Brightness.light]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              colorSchemeSeed: const Color(0xFFE53935), // a loud red accent
            ),
            home: const Scaffold(body: WhatsNewCard()),
          ),
        );

        bool isGrey(Color c) {
          final r = (c.r * 255).round(), g = (c.g * 255).round();
          final b = (c.b * 255).round();
          return r == g && g == b;
        }

        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          final color = text.style?.color;
          if (color != null) expect(isGrey(color), isTrue, reason: text.data);
        }
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(isGrey(dialog.backgroundColor!), isTrue);
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final style = button.style!;
        expect(isGrey(style.backgroundColor!.resolve({})!), isTrue);
        expect(isGrey(style.foregroundColor!.resolve({})!), isTrue);
      }
    });

    testWidgets('fits a small phone without overflowing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WhatsNewCard())),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('showIfNeeded shows the card once, then never again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(412, 915));

    late WidgetRef captured;
    Future<void>? shown;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loginOtpChallengeProvider.overrideWith(_NoOtp.new)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return Scaffold(
                body: TextButton(
                  onPressed: () => shown = WhatsNew.showIfNeeded(context, ref),
                  child: const Text('go'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WhatsNewCard), findsOneWidget);

    // Not acknowledged yet: a card that was only shown is still due.
    expect(await WhatsNew.shouldShow(), isTrue);

    await tester.tap(find.text('got it'));
    await tester.pumpAndSettle();
    await shown;
    expect(await WhatsNew.shouldShow(), isFalse);

    await tester.tap(find.text('go'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WhatsNewCard), findsNothing);
    expect(captured, isNotNull);
  });
}
