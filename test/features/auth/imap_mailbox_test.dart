import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';

/// A tiny IMAP server on localhost, just enough of the protocol for the reader:
/// login, read-only inbox, search, fetch. Not TLS: the mailbox is told to connect
/// without it, which is the only thing that differs from Gmail.
///
/// This exercises the real network code (the connection, the commands the app
/// sends, and reading the replies), which a fake [OtpMailbox] cannot.
class FakeImapServer {
  FakeImapServer._(this._server, this.password, this.mails);

  final ServerSocket _server;
  final String password;
  final Map<int, _Mail> mails;
  final commands = <String>[];

  int get port => _server.port;

  static Future<FakeImapServer> start({
    String password = 'secret',
    required Map<int, _Mail> mails,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeImapServer._(server, password, mails);
    server.listen(fake._serve);
    return fake;
  }

  Future<void> stop() => _server.close();

  void _serve(Socket socket) {
    void send(String text) => socket.write('$text\r\n');
    send('* OK IMAP4rev1 fake ready');

    var buffer = '';
    socket.listen((data) {
      buffer += latin1.decode(data);
      while (buffer.contains('\r\n')) {
        final i = buffer.indexOf('\r\n');
        final line = buffer.substring(0, i);
        buffer = buffer.substring(i + 2);
        _handle(line, send, socket);
      }
    });
  }

  void _handle(String line, void Function(String) send, Socket socket) {
    commands.add(line);
    final space = line.indexOf(' ');
    if (space < 0) return;
    final tag = line.substring(0, space);
    final rest = line.substring(space + 1);
    final upper = rest.toUpperCase();

    if (upper.startsWith('CAPABILITY')) {
      send('* CAPABILITY IMAP4rev1 AUTH=PLAIN');
      send('$tag OK CAPABILITY completed');
    } else if (upper.startsWith('LOGIN')) {
      if (rest.contains(password)) {
        send('$tag OK LOGIN completed');
      } else {
        send('$tag NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)');
      }
    } else if (upper.startsWith('EXAMINE')) {
      send('* ${mails.length} EXISTS');
      send('* 0 RECENT');
      send('* OK [UIDVALIDITY 1] ok');
      send(
        '* OK [UIDNEXT ${mails.keys.fold<int>(0, (a, b) => a > b ? a : b) + 1}] ok',
      );
      send(r'* FLAGS (\Seen \Answered)');
      send('$tag OK [READ-ONLY] EXAMINE completed');
    } else if (upper.startsWith('UID SEARCH')) {
      final ids = mails.keys.toList()..sort();
      send('* SEARCH ${ids.join(' ')}');
      send('$tag OK SEARCH completed');
    } else if (upper.startsWith('UID FETCH')) {
      final parts = rest.split(' ');
      final wanted = _expand(parts[2]);
      final wantsBody = upper.contains('BODY.PEEK[]');
      var n = 0;
      for (final uid in wanted) {
        final mail = mails[uid];
        if (mail == null) continue;
        n++;
        if (wantsBody) {
          final raw = mail.raw();
          send(
            '* $n FETCH (UID $uid INTERNALDATE "${mail.internalDate}" '
            'BODY[] {${raw.length}}',
          );
          socket.write(raw);
          send(')');
        } else {
          send('* $n FETCH (UID $uid INTERNALDATE "${mail.internalDate}")');
        }
      }
      send('$tag OK FETCH completed');
    } else if (upper.startsWith('LOGOUT')) {
      send('* BYE bye');
      send('$tag OK LOGOUT completed');
      socket.close();
    } else {
      send('$tag OK done');
    }
  }

  /// "31,35,38" or "31:38" as ids.
  List<int> _expand(String set) {
    final ids = <int>[];
    for (final piece in set.split(',')) {
      if (piece.contains(':')) {
        final r = piece.split(':');
        final a = int.parse(r[0]);
        final b = int.parse(r[1]);
        for (var i = a; i <= b; i++) {
          ids.add(i);
        }
      } else {
        ids.add(int.parse(piece));
      }
    }
    return ids;
  }
}

class _Mail {
  _Mail({
    required this.internalDate,
    required this.html,
    this.from = 'VTOP <noreply.sdc@vitap.ac.in>',
  });

  /// IMAP's own format: "13-Nov-2026 11:22:05 +0530".
  final String internalDate;
  final String html;
  final String from;

  String raw() =>
      'From: $from\r\n'
      'To: me@vitapstudent.ac.in\r\n'
      'Subject: VTOP Login OTP\r\n'
      'Date: Fri, 13 Nov 2026 11:22:05 +0530\r\n'
      'MIME-Version: 1.0\r\n'
      'Content-Type: text/html; charset=UTF-8\r\n'
      '\r\n'
      '$html\r\n';
}

String page(String code) =>
    '<html><body><p>Dear VITian,</p><p>Your one-time password</p>'
    '<div style="letter-spacing:8px">$code</div><p>Expires in 3 minutes</p>'
    '</body></html>';

ImapOtpMailbox mailbox(FakeImapServer server, {String password = 'secret'}) =>
    ImapOtpMailbox(
      email: 'me@vitapstudent.ac.in',
      appPassword: password,
      host: '127.0.0.1',
      port: server.port,
      secure: false,
      timeout: const Duration(seconds: 5),
    );

void main() {
  late FakeImapServer server;

  tearDown(() => server.stop());

  test('opens read-only, and reads the code out of the newest mail', () async {
    server = await FakeImapServer.start(
      mails: {
        31: _Mail(
          internalDate: '12-Nov-2026 09:00:00 +0530',
          html: page('111111'),
        ),
        38: _Mail(
          internalDate: '13-Nov-2026 11:22:05 +0530',
          html: page('488245'),
        ),
      },
    );

    final reader = GmailOtpReader(
      openMailbox: () => mailbox(server),
      timeout: const Duration(seconds: 3),
      pollEvery: const Duration(milliseconds: 100),
    );
    final found = await reader.waitForCode(
      issuedAfter: DateTime(2026, 11, 13, 11, 20),
    );

    expect(found.code, '488245');
    expect(found.uid, 38);
    // Nothing is ever changed: the inbox is only examined, bodies only peeked.
    final sent = server.commands.join('\n').toUpperCase();
    expect(sent, contains('EXAMINE'));
    expect(sent, isNot(contains(' SELECT ')));
    expect(sent, contains('BODY.PEEK[]'));
    expect(sent, isNot(contains('STORE')));
    expect(sent, isNot(contains('EXPUNGE')));
    expect(sent, contains('FROM "NOREPLY.SDC@VITAP.AC.IN"'));
    expect(sent, contains('LOGOUT'), reason: 'closed straight away');
  });

  test(
    'a mail from anyone else is not read, even if the server returns it',
    () async {
      server = await FakeImapServer.start(
        mails: {
          40: _Mail(
            internalDate: '13-Nov-2026 11:22:05 +0530',
            html: page('999999'),
            from: 'Someone <spam@example.com>',
          ),
        },
      );

      final reader = GmailOtpReader(
        openMailbox: () => mailbox(server),
        timeout: const Duration(milliseconds: 400),
        pollEvery: const Duration(milliseconds: 100),
      );

      await expectLater(
        reader.waitForCode(issuedAfter: DateTime(2026, 11, 13, 11, 20)),
        throwsA(
          isA<OtpReaderException>().having(
            (e) => e.problem,
            'problem',
            OtpReaderProblem.timedOut,
          ),
        ),
      );
    },
  );

  test('a wrong app password is reported as such', () async {
    server = await FakeImapServer.start(mails: {});

    final reader = GmailOtpReader(
      openMailbox: () => mailbox(server, password: 'wrong'),
    );

    await expectLater(
      reader.waitForCode(issuedAfter: DateTime.now()),
      throwsA(
        isA<OtpReaderException>().having(
          (e) => e.problem,
          'problem',
          OtpReaderProblem.invalidCredentials,
        ),
      ),
    );
  });

  test('nothing listening is a network problem, not a hang', () async {
    server = await FakeImapServer.start(mails: {});
    final port = server.port;
    await server.stop();

    final reader = GmailOtpReader(
      openMailbox: () => ImapOtpMailbox(
        email: 'me@vitapstudent.ac.in',
        appPassword: 'secret',
        host: '127.0.0.1',
        port: port,
        secure: false,
        timeout: const Duration(seconds: 2),
      ),
      sleep: (_) async {},
      timeout: const Duration(seconds: 2),
    );

    server = await FakeImapServer.start(mails: {}); // for the tearDown
    await expectLater(
      reader.waitForCode(issuedAfter: DateTime.now()),
      throwsA(
        isA<OtpReaderException>().having(
          (e) => e.problem,
          'problem',
          OtpReaderProblem.network,
        ),
      ),
    );
  });

  group('the connection test', () {
    test('counts EVERY VTOP mail, not just the few it reads a code from', () async {
      // Twelve codes in the last month. Reading a code only looks at the newest
      // few, but the test has to count them all.
      final now = DateTime.now();
      String stamp(int daysAgo) {
        final d = now.subtract(Duration(days: daysAgo));
        const m = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${d.day.toString().padLeft(2, '0')}-${m[d.month - 1]}-${d.year} '
            '10:15:00 +0000';
      }

      server = await FakeImapServer.start(
        mails: {
          for (var i = 1; i <= 12; i++)
            i: _Mail(internalDate: stamp(13 - i), html: page('10000$i')),
        },
      );

      final reader = GmailOtpReader(openMailbox: () => mailbox(server));
      final summary = await reader.check();

      expect(summary.count, 12);
      expect(summary.latest, isNotNull);
      expect(
        now.difference(summary.latest!).inDays,
        lessThanOrEqualTo(2),
        reason: 'the newest is the one from a day or so ago',
      );
      // It asked for arrival times, never bodies.
      expect(server.commands.join('\n').toUpperCase(), isNot(contains('BODY')));
    });

    test('mail older than the period is not counted', () async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 90));
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final oldStamp =
          '${old.day.toString().padLeft(2, '0')}-${m[old.month - 1]}-${old.year} 10:00:00 +0000';

      server = await FakeImapServer.start(
        mails: {1: _Mail(internalDate: oldStamp, html: page('123456'))},
      );

      final summary = await GmailOtpReader(
        openMailbox: () => mailbox(server),
      ).check();
      expect(summary.count, 0);
      expect(summary.latest, isNull);
    });

    test('an empty mailbox is zero, not an error', () async {
      server = await FakeImapServer.start(mails: {});

      final summary = await GmailOtpReader(
        openMailbox: () => mailbox(server),
      ).check();
      expect(summary.count, 0);
    });
  });
}
