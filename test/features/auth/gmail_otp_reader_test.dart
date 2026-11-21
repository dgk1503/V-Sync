import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/auth/model/otp_email.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';

/// A trimmed copy of VTOP's login mail: the header, "your one-time password" and
/// the six digits in a box, "expires in 3 minutes", and the styles around it.
String vtopMail(String codeMarkup) =>
    '''
<html><head><style>.box{width:100000px;letter-spacing:8px}</style>
<script>var tracking = 999999;</script></head>
<body><div class="hdr">VTOP Login Verification</div>
<p>Dear VITian,</p>
<p>Use the OTP below to complete your login. This code is valid for a limited time only.</p>
<div>YOUR ONE-TIME PASSWORD</div>
<div class="box">$codeMarkup</div>
<div>Expires in 3 minutes</div>
<p>Security Alert: If you did not initiate this login request, please change your VTOP password immediately.</p>
</body></html>
''';

void main() {
  group('reading the code out of the mail', () {
    test('six digits standing together', () {
      expect(VtopOtpEmail.extractCode(vtopMail('488245')), '488245');
    });

    test('the same digits spaced out in the text', () {
      expect(VtopOtpEmail.extractCode(vtopMail('4 8 8 2 4 5')), '488245');
    });

    test('each digit in a tag of its own', () {
      final markup = [
        for (final d in '488245'.split('')) '<span>$d</span>',
      ].join();
      expect(VtopOtpEmail.extractCode(vtopMail(markup)), '488245');
    });

    test('digits separated by non-breaking spaces', () {
      expect(
        VtopOtpEmail.extractCode(
          vtopMail('4&nbsp;8&nbsp;8&nbsp;2&nbsp;4&nbsp;5'),
        ),
        '488245',
      );
    });

    test('plain text works as well', () {
      expect(
        VtopOtpEmail.extractCode('Your OTP is 401295. Valid 5 min'),
        '401295',
      );
    });

    test('styles and scripts are not read (they hold six-digit numbers)', () {
      // The sample has a 6-digit number in a script and a 100000px width.
      expect(VtopOtpEmail.extractCode(vtopMail('112233')), '112233');
    });

    test('a longer number is not a code', () {
      expect(VtopOtpEmail.extractCode('ref 12345678 then 654321'), '654321');
      expect(VtopOtpEmail.extractCode('call 9876543210'), isNull);
    });

    test('five digits, or none, is no code', () {
      expect(VtopOtpEmail.extractCode('no code 12345'), isNull);
      expect(VtopOtpEmail.extractCode('Dear VITian, nothing here'), isNull);
    });

    test('only VTOP\'s own address counts, however it is capitalised', () {
      expect(VtopOtpEmail.isFromVtop('noreply.sdc@vitap.ac.in'), isTrue);
      expect(VtopOtpEmail.isFromVtop(' NoReply.SDC@VITAP.ac.in '), isTrue);
      expect(VtopOtpEmail.isFromVtop('spam@example.com'), isFalse);
      expect(
        VtopOtpEmail.isFromVtop('noreply.sdc@vitap.ac.in.evil.com'),
        isFalse,
      );
      expect(VtopOtpEmail.isFromVtop(null), isFalse);
    });
  });

  group('waiting for the code', () {
    final t0 = DateTime(2026, 11, 13, 11, 22);

    MailMessage mail(
      int uid, {
      String code = '488245',
      DateTime? at,
      String from = VtopOtpEmail.sender,
    }) => MailMessage(
      uid: uid,
      received: at ?? t0.add(const Duration(seconds: 5)),
      from: from,
      subject: 'VTOP Login OTP',
      body: vtopMail(code),
    );

    /// A reader on a clock that only moves when it sleeps.
    ({GmailOtpReader reader, _FakeMailbox box, List<int> polls}) setup(
      List<List<MailMessage>> replies, {
      Object? openError,
      Duration? timeout,
    }) {
      var now = t0;
      final box = _FakeMailbox(replies, openError: openError);
      final polls = <int>[];
      final reader = GmailOtpReader(
        openMailbox: () => box,
        timeout: timeout ?? const Duration(seconds: 45),
        now: () => now,
        sleep: (d) async {
          polls.add(d.inSeconds);
          now = now.add(d);
        },
      );
      return (reader: reader, box: box, polls: polls);
    }

    test('finds a code that is already there', () async {
      final s = setup([
        [mail(10)],
      ]);

      final found = await s.reader.waitForCode(issuedAfter: t0);

      expect(found.code, '488245');
      expect(found.uid, 10);
      expect(s.polls, isEmpty, reason: 'no waiting needed');
      expect(s.box.closed, 1, reason: 'the mailbox is closed straight away');
    });

    test('keeps polling every three seconds until the mail arrives', () async {
      final s = setup([
        const [],
        const [],
        [mail(11, code: '112233')],
      ]);

      final found = await s.reader.waitForCode(issuedAfter: t0);

      expect(found.code, '112233');
      expect(s.polls, [3, 3]);
      expect(s.box.opened, 1, reason: 'one connection for the whole wait');
      expect(s.box.closed, 1);
    });

    test('gives up after the time is up, having polled all along', () async {
      final s = setup([const []]);

      await expectLater(
        s.reader.waitForCode(issuedAfter: t0),
        throwsA(
          isA<OtpReaderException>().having(
            (e) => e.problem,
            'problem',
            OtpReaderProblem.timedOut,
          ),
        ),
      );
      expect(s.polls.length, inInclusiveRange(13, 15));
      expect(s.box.closed, 1);
    });

    test('ignores mail from anyone but VTOP', () async {
      final s = setup([
        [mail(12, from: 'friend@gmail.com', code: '999999')],
        [mail(13, code: '123456')],
      ]);

      expect((await s.reader.waitForCode(issuedAfter: t0)).code, '123456');
    });

    test('ignores a code that is older than this request', () async {
      final old = mail(
        5,
        code: '111111',
        at: t0.subtract(const Duration(minutes: 30)),
      );
      final s = setup([
        [old],
        [old, mail(14, code: '222222')],
      ]);

      expect((await s.reader.waitForCode(issuedAfter: t0)).code, '222222');
    });

    test('a code a few seconds before the request still counts', () async {
      // Clocks differ, and the mail can beat the app's own timestamp.
      final s = setup([
        [
          mail(
            15,
            code: '333333',
            at: t0.subtract(const Duration(seconds: 40)),
          ),
        ],
      ]);

      expect((await s.reader.waitForCode(issuedAfter: t0)).code, '333333');
    });

    test('takes the newest of several mails', () async {
      final s = setup([
        [
          mail(20, code: '111111'),
          mail(22, code: '333333'),
          mail(21, code: '222222'),
        ],
      ]);

      expect((await s.reader.waitForCode(issuedAfter: t0)).code, '333333');
    });

    test('a code already tried and refused is not offered again', () async {
      final s = setup([
        [mail(30, code: '444444')],
        [mail(30, code: '444444'), mail(31, code: '555555')],
      ]);

      final found = await s.reader.waitForCode(
        issuedAfter: t0,
        ignoreUids: {30},
      );

      expect(found.code, '555555');
      expect(found.uid, 31);
    });

    test('a refused password stops at once, with no retries', () async {
      final s = setup(
        const [],
        openError: const OtpReaderException(
          OtpReaderProblem.invalidCredentials,
        ),
      );

      await expectLater(
        s.reader.waitForCode(issuedAfter: t0),
        throwsA(
          isA<OtpReaderException>().having(
            (e) => e.problem,
            'problem',
            OtpReaderProblem.invalidCredentials,
          ),
        ),
      );
      expect(s.box.openAttempts, 1);
      expect(s.polls, isEmpty);
    });

    test('a dropped connection is retried, and the wait carries on', () async {
      final s = setup([const []]);
      s.box.failNextFetch = const OtpReaderException(OtpReaderProblem.network);
      s.box.replies
        ..clear()
        ..add([mail(40, code: '666666')]);

      final found = await s.reader.waitForCode(issuedAfter: t0);

      expect(found.code, '666666');
      expect(s.box.opened, 2, reason: 'reconnected once');
    });

    test('a network that stays down is given up on', () async {
      final s = setup(const []);
      s.box.alwaysFail = const OtpReaderException(OtpReaderProblem.network);

      await expectLater(
        s.reader.waitForCode(issuedAfter: t0),
        throwsA(
          isA<OtpReaderException>().having(
            (e) => e.problem,
            'problem',
            OtpReaderProblem.network,
          ),
        ),
      );
    });

    test('can be cancelled while it waits', () async {
      final s = setup([const []]);
      final cancel = OtpCancel();
      // Cancel after the first sleep.
      final reader = GmailOtpReader(
        openMailbox: () => s.box,
        now: () => t0,
        sleep: (_) async => cancel.cancel(),
      );

      await expectLater(
        reader.waitForCode(issuedAfter: t0, cancel: cancel),
        throwsA(
          isA<OtpReaderException>().having(
            (e) => e.problem,
            'problem',
            OtpReaderProblem.cancelled,
          ),
        ),
      );
      expect(s.box.closed, 1);
    });

    test('the connection test opens, counts and closes', () async {
      final s = setup([
        [mail(50), mail(51)],
      ]);

      expect((await s.reader.check()).count, 2);
      expect(s.box.closed, 1);
    });

    test('the connection test reports a refusal', () async {
      final s = setup(
        const [],
        openError: const OtpReaderException(OtpReaderProblem.accessBlocked),
      );

      await expectLater(s.reader.check(), throwsA(isA<OtpReaderException>()));
      expect(s.box.closed, 1);
    });
  });

  group('what the server says', () {
    ImapException imap(String text) => ImapException(ImapClient(), text);

    test('a refused password', () {
      expect(
        ImapOtpMailbox.classify(
          imap('NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)'),
        ).problem,
        OtpReaderProblem.invalidCredentials,
      );
    });

    test('an account that does not allow app passwords or IMAP', () {
      expect(
        ImapOtpMailbox.classify(
          imap('NO [ALERT] Application-specific password required'),
        ).problem,
        OtpReaderProblem.accessBlocked,
      );
      expect(
        ImapOtpMailbox.classify(
          imap('NO IMAP access is disabled for your domain'),
        ).problem,
        OtpReaderProblem.accessBlocked,
      );
    });

    test('a dead network', () {
      expect(
        ImapOtpMailbox.classify(const SocketException('no route')).problem,
        OtpReaderProblem.network,
      );
      expect(
        ImapOtpMailbox.classify(TimeoutException('slow')).problem,
        OtpReaderProblem.network,
      );
    });

    test('anything else is unexpected, not a guess', () {
      expect(
        ImapOtpMailbox.classify(StateError('odd')).problem,
        OtpReaderProblem.unexpected,
      );
    });

    test('IMAP dates are a day early and in Gmail\'s spelling', () {
      // SINCE is a date, so ask from the day before and filter by time.
      expect(
        ImapOtpMailbox.imapDate(DateTime.utc(2026, 11, 13, 1)),
        '12-Nov-2026',
      );
      expect(
        ImapOtpMailbox.imapDate(DateTime.utc(2026, 1, 1, 0)),
        '31-Dec-2025',
      );
    });
  });
}

/// A mailbox that answers from a script and counts what was done to it.
class _FakeMailbox implements OtpMailbox {
  _FakeMailbox(this.replies, {this.openError});

  final List<List<MailMessage>> replies;
  final Object? openError;
  Object? failNextFetch;
  Object? alwaysFail;

  int openAttempts = 0;
  int opened = 0;
  int closed = 0;
  int _polls = 0;

  @override
  Future<void> open() async {
    openAttempts++;
    if (openError != null) throw openError!;
    opened++;
  }

  @override
  Future<List<MailMessage>> fromVtop({required DateTime since}) async {
    if (alwaysFail != null) throw alwaysFail!;
    if (failNextFetch != null) {
      final e = failNextFetch!;
      failNextFetch = null;
      throw e;
    }
    if (replies.isEmpty) return const [];
    final i = _polls++ < replies.length ? _polls - 1 : replies.length - 1;
    return replies[i];
  }

  @override
  Future<MailboxSummary> summary({required DateTime since}) async {
    final all = replies.expand((r) => r).toList();
    return MailboxSummary(
      count: all.length,
      latest: DateTime(2026, 11, 13, 11, 22),
    );
  }

  @override
  Future<void> close() async => closed++;
}
