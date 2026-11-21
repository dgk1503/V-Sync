import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/services/gmail_otp_store.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/account/view/pages/otp_autofetch_page.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';
import 'package:vit_ap_student_app/features/auth/services/otp_auto_fill.dart';

/// A Gmail that signs in, or refuses to, and holds [mails] from VTOP.
class _FakeMailbox implements OtpMailbox {
  _FakeMailbox({this.error, this.mails = const [], this.total});

  final OtpReaderException? error;
  final List<MailMessage> mails;

  /// How many VTOP mails Gmail holds, when that is more than [mails].
  final int? total;

  @override
  Future<void> open() async {
    if (error != null) throw error!;
  }

  @override
  Future<List<MailMessage>> fromVtop({required DateTime since}) async => mails;

  @override
  Future<MailboxSummary> summary({required DateTime since}) async =>
      MailboxSummary(
        count: total ?? mails.length,
        latest: mails.isEmpty ? null : mails.first.received,
      );

  @override
  Future<void> close() async {}
}

MailMessage vtopMail(int uid) => MailMessage(
  uid: uid,
  received: DateTime.now(),
  from: 'noreply.sdc@vitap.ac.in',
  subject: 'VTOP Login OTP',
  body: 'Your OTP is 123456',
);

const goodPassword = 'abcd efgh ijkl mnop';

void main() {
  late GmailOtpStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = GmailOtpStore(const FlutterSecureStorage());
  });

  Future<void> mount(
    WidgetTester tester, {
    OtpReaderException? refuses,
    List<MailMessage> mails = const [],
    int? total,
    Size? size,
  }) async {
    tester.view.physicalSize = size ?? const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gmailOtpStoreProvider.overrideWithValue(store),
          otpMailboxBuilderProvider.overrideWithValue(
            (account) =>
                () => _FakeMailbox(error: refuses, mails: mails, total: total),
          ),
        ],
        child: MaterialApp(
          theme: getThemeData(isDarkMode: true),
          home: const OtpAutofetchPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Reads the disclosure and agrees to it: the setup fields appear only then.
  Future<void> agree(WidgetTester tester) async {
    await tester.tap(find.text('Review and set up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
  }

  group('the app password', () {
    test('is read the way Google shows it', () {
      expect(GmailOtpStore.normalisePassword(goodPassword), 'abcdefghijklmnop');
      expect(
        GmailOtpStore.normalisePassword(' ABCD EFGH IJKL MNOP '),
        'abcdefghijklmnop',
      );
    });

    test('is refused when it is not sixteen letters', () {
      expect(GmailOtpStore.normalisePassword('abcd efgh ijkl mno'), isNull);
      expect(GmailOtpStore.normalisePassword('abcd efgh ijkl mnop q'), isNull);
      expect(GmailOtpStore.normalisePassword('abcd efgh ijkl mn0p'), isNull);
      expect(GmailOtpStore.normalisePassword(''), isNull);
    });

    test('an address has to look like one', () {
      expect(GmailOtpStore.isValidEmail('a.b@vitapstudent.ac.in'), isTrue);
      expect(GmailOtpStore.isValidEmail('nope'), isFalse);
      expect(GmailOtpStore.isValidEmail('a@b'), isFalse);
    });
  });

  group('the store', () {
    test('keeps the account, and forgets it', () async {
      await store.save(
        const GmailOtpAccount(email: 'a@b.co', appPassword: 'abcdefghijklmnop'),
      );

      final saved = await store.read();
      expect(saved!.email, 'a@b.co');
      expect(saved.appPassword, 'abcdefghijklmnop');
      expect(await store.isEnabled(), isTrue);

      await store.clear();
      expect(await store.read(), isNull);
      expect(await store.isEnabled(), isFalse);
    });

    test('can be switched off without forgetting the account', () async {
      await store.save(
        const GmailOtpAccount(email: 'a@b.co', appPassword: 'abcdefghijklmnop'),
      );
      await store.setEnabled(false);

      expect(await store.isEnabled(), isFalse);
      expect(await store.read(), isNotNull);
    });
  });

  group('setting it up', () {
    testWidgets('asks for consent before any field is shown', (tester) async {
      await mount(tester);

      expect(find.text('Review and set up'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Connect Gmail'), findsNothing);

      await tester.tap(find.text('Review and set up'));
      await tester.pumpAndSettle();

      // The disclosure says what is read, what is kept and where it goes.
      expect(find.byKey(const ValueKey('otp-consent')), findsOneWidget);
      expect(
        find.textContaining('Read your VTOP code from Gmail'),
        findsOneWidget,
      );
      expect(find.textContaining('noreply.sdc@vitap.ac.in'), findsWidgets);
      expect(find.textContaining('never changes'), findsWidgets);
      expect(find.textContaining('Android Keystore'), findsWidgets);
      expect(find.textContaining('never sent to VSync'), findsWidgets);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('I agree'), findsOneWidget);
    });

    testWidgets('"Not now" shows no fields and keeps nothing', (tester) async {
      await mount(tester);

      await tester.tap(find.text('Review and set up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Review and set up'), findsOneWidget);
      expect(await store.read(), isNull);
    });

    testWidgets('the disclosure cannot be dismissed by tapping outside', (
      tester,
    ) async {
      await mount(tester);

      await tester.tap(find.text('Review and set up'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('otp-consent')), findsOneWidget);
    });

    testWidgets('explains what it does and what it needs', (tester) async {
      await mount(tester);
      await agree(tester);

      expect(find.text('Automatic OTP'), findsOneWidget);
      expect(
        find.textContaining('Turn on 2-Step Verification'),
        findsOneWidget,
      );
      expect(find.textContaining('Create an app password'), findsOneWidget);
      expect(find.textContaining('noreply.sdc@vitap.ac.in'), findsOneWidget);
      expect(find.textContaining('never sent to VSync'), findsOneWidget);
      expect(find.text('Connect Gmail'), findsOneWidget);
    });

    testWidgets('asks for a sensible address first', (tester) async {
      await mount(tester);
      await agree(tester);
      await enter(tester, 'nope', goodPassword);

      await tester.tap(find.text('Connect Gmail'));
      await tester.pump();

      expect(find.textContaining('Enter the Gmail address'), findsOneWidget);
      expect(await store.read(), isNull);
    });

    testWidgets('and an app password that is the right shape', (tester) async {
      await mount(tester);
      await agree(tester);
      await enter(tester, 'me@vitapstudent.ac.in', 'not it');

      await tester.tap(find.text('Connect Gmail'));
      await tester.pump();

      expect(find.textContaining('16 letters'), findsOneWidget);
      expect(await store.read(), isNull);
    });

    testWidgets('connects, saves, and says what it found', (tester) async {
      await mount(tester, mails: [vtopMail(1), vtopMail(2)]);
      await agree(tester);
      await enter(tester, 'me@vitapstudent.ac.in', goodPassword);

      await tester.tap(find.text('Connect Gmail'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Found 2 VTOP emails in your Inbox'),
        findsOneWidget,
      );
      final saved = await store.read();
      expect(saved!.email, 'me@vitapstudent.ac.in');
      expect(saved.appPassword, 'abcdefghijklmnop');
      expect(find.text('me@vitapstudent.ac.in'), findsOneWidget);
      expect(find.text('Read codes automatically'), findsOneWidget);
    });

    testWidgets('a refused password is explained and nothing is saved', (
      tester,
    ) async {
      await mount(
        tester,
        refuses: const OtpReaderException(OtpReaderProblem.invalidCredentials),
      );
      await agree(tester);
      await enter(tester, 'me@vitapstudent.ac.in', goodPassword);

      await tester.tap(find.text('Connect Gmail'));
      await tester.pumpAndSettle();

      expect(find.textContaining('did not accept'), findsOneWidget);
      expect(await store.read(), isNull);
      expect(find.text('Connect Gmail'), findsOneWidget);
    });

    testWidgets('a college that blocks app passwords is told so', (
      tester,
    ) async {
      await mount(
        tester,
        refuses: const OtpReaderException(OtpReaderProblem.accessBlocked),
      );
      await agree(tester);
      await enter(tester, 'me@vitapstudent.ac.in', goodPassword);

      await tester.tap(find.text('Connect Gmail'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('college may have turned them off'),
        findsWidgets,
      );
    });
  });

  group('once connected', () {
    Future<void> connected(WidgetTester tester) async {
      await store.save(
        const GmailOtpAccount(
          email: 'me@vitapstudent.ac.in',
          appPassword: 'abcdefghijklmnop',
        ),
      );
      await mount(tester, mails: [vtopMail(1)]);
      await tester.pumpAndSettle();
    }

    testWidgets('shows the account and the switch', (tester) async {
      await connected(tester);

      expect(find.text('me@vitapstudent.ac.in'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Connect Gmail'), findsNothing);
    });

    testWidgets('the switch turns reading off without forgetting the account', (
      tester,
    ) async {
      await connected(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(await store.isEnabled(), isFalse);
      expect(await store.read(), isNotNull);
    });

    testWidgets(
      'Test connection counts every mail, not just the few it reads',
      (tester) async {
        await store.save(
          const GmailOtpAccount(
            email: 'me@vitapstudent.ac.in',
            appPassword: 'abcdefghijklmnop',
          ),
        );
        await mount(tester, mails: [vtopMail(1)], total: 23);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test connection'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Found 23 VTOP emails'), findsOneWidget);
        expect(find.textContaining('in the last 30 days'), findsOneWidget);
        expect(
          find.textContaining('The newest arrived today at'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Connected is green, with a tick', (tester) async {
      await connected(tester);

      final label = tester.widget<Text>(
        find.byKey(const ValueKey('otp-connected')),
      );
      final green = AppStatusColors.of(
        tester.element(find.byType(OtpAutofetchPage)),
      ).success;
      expect(label.style!.color, green);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    });

    testWidgets('a very long address stays inside the card', (tester) async {
      await store.save(
        const GmailOtpAccount(
          email:
              'a.very.long.student.name.with.many.parts2025@vitapstudent.ac.in',
          appPassword: 'abcdefghijklmnop',
        ),
      );
      // A 320 dp wide phone.
      await mount(tester, size: const Size(640, 2400));
      await tester.pumpAndSettle();

      // The test font is a wide placeholder, so another row can overflow at this
      // width; what matters here is the address itself.
      tester.takeException();
      final text = tester.widget<Text>(
        find.textContaining('a.very.long.student'),
      );
      // One line, scaled down to fit: never wrapped, never cut off.
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      final fitted = find.ancestor(
        of: find.textContaining('a.very.long.student'),
        matching: find.byType(FittedBox),
      );
      expect(fitted, findsOneWidget);
      final box = tester.getRect(fitted);
      expect(box.right, lessThanOrEqualTo(320));
      expect(box.left, greaterThanOrEqualTo(0));
    });

    testWidgets('Test connection reports what it can see', (tester) async {
      await connected(tester);

      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gmail works'), findsOneWidget);
      expect(
        find.textContaining('Found 1 VTOP email in your Inbox'),
        findsOneWidget,
      );
    });

    testWidgets('Remove forgets the account after a confirmation', (
      tester,
    ) async {
      await connected(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Gmail?'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(await store.read(), isNull);
      // Back to the start: consent is asked for again before any field.
      expect(find.text('Review and set up'), findsOneWidget);
    });

    testWidgets('Remove can be cancelled', (tester) async {
      await connected(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await store.read(), isNotNull);
    });
  });
}
