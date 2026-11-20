import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:vit_ap_student_app/features/auth/model/otp_email.dart';

/// Why the code could not be read from Gmail.
enum OtpReaderProblem {
  /// No Gmail address and app password have been saved.
  notConfigured,

  /// Google refused the address / app password.
  invalidCredentials,

  /// The account does not allow IMAP or app passwords (a college admin setting,
  /// or 2-Step Verification is off).
  accessBlocked,

  /// Could not reach Gmail.
  network,

  /// No VTOP code arrived in time.
  timedOut,

  /// The read was stopped (the prompt was closed, or a code was entered by hand).
  cancelled,

  unexpected,
}

class OtpReaderException implements Exception {
  const OtpReaderException(this.problem, [this.detail]);

  final OtpReaderProblem problem;

  /// What the server said, for a log; never shown as it is.
  final String? detail;

  /// Plain words for the person using the app.
  String get message => switch (problem) {
    OtpReaderProblem.notConfigured => 'Gmail is not connected.',
    OtpReaderProblem.invalidCredentials =>
      'Gmail did not accept the address or app password.',
    OtpReaderProblem.accessBlocked =>
      'This Google account does not allow app passwords or IMAP. Your college '
          'may have turned them off.',
    OtpReaderProblem.network => 'Could not reach Gmail. Check your connection.',
    OtpReaderProblem.timedOut =>
      'No code arrived in Gmail. Type it in, or tap Resend.',
    OtpReaderProblem.cancelled => 'Stopped.',
    OtpReaderProblem.unexpected => 'Could not read your Gmail.',
  };

  @override
  String toString() =>
      'OtpReaderException($problem${detail == null ? '' : ': $detail'})';
}

/// One email, as the reader needs it.
class MailMessage {
  const MailMessage({
    required this.uid,
    required this.received,
    required this.from,
    required this.subject,
    required this.body,
  });

  /// The mailbox's own number for it; only ever goes up.
  final int uid;

  /// When Gmail received it; null if neither it nor the Date header said.
  final DateTime? received;
  final String? from;
  final String subject;

  /// The text and HTML parts, one after the other.
  final String body;
}

/// How much of VTOP's mail a mailbox holds: for the "Test connection" button.
class MailboxSummary {
  const MailboxSummary({required this.count, this.latest});

  /// VTOP mails received in the period asked about.
  final int count;

  /// When the newest of them arrived; null when there are none.
  final DateTime? latest;
}

/// A code found in Gmail.
class OtpFound {
  const OtpFound({required this.code, required this.uid, this.received});

  final String code;

  /// The mail it came from, so a rejected code is not tried twice.
  final int uid;
  final DateTime? received;
}

/// A way to cancel a read that is waiting.
class OtpCancel {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// A mailbox the reader can ask for VTOP's mail. Gmail over IMAP in the app; a
/// fake in tests.
abstract class OtpMailbox {
  /// Connects, signs in and opens the inbox for reading only.
  Future<void> open();

  /// VTOP's mail received on or after [since], newest first. Reading never
  /// marks anything as read.
  Future<List<MailMessage>> fromVtop({required DateTime since});

  /// How many VTOP mails arrived on or after [since], and when the newest did.
  /// Counts them all, unlike [fromVtop], which only fetches the newest few to read
  /// a code from.
  Future<MailboxSummary> summary({required DateTime since});

  Future<void> close();
}

typedef MailboxFactory = OtpMailbox Function();

/// Reads VTOP's login code from the student's own Gmail.
///
/// The mailbox is opened when a code is wanted, polled every few seconds until
/// the mail arrives (or the time is up), and closed again straight away. Only
/// mail from VTOP's sender is looked at. Nothing is kept: not the mail, not the
/// code once it has been handed over.
class GmailOtpReader {
  GmailOtpReader({
    required this.openMailbox,
    this.pollEvery = const Duration(seconds: 3),
    this.timeout = const Duration(seconds: 45),
    this.slack = const Duration(minutes: 2),
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : _now = now ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  final MailboxFactory openMailbox;
  final Duration pollEvery;

  /// How long to wait for the mail before giving up.
  final Duration timeout;

  /// How far before the request a mail may have been received and still count
  /// (clocks differ, and the mail can beat the app's own bookkeeping).
  final Duration slack;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;

  /// Waits for the code of the OTP requested at [issuedAfter].
  ///
  /// Mails already tried ([ignoreUids]) and mails older than [issuedAfter] minus
  /// the [slack] are not considered. A transient network drop is retried; a
  /// refusal of the password is not.
  Future<OtpFound> waitForCode({
    required DateTime issuedAfter,
    Set<int> ignoreUids = const {},
    OtpCancel? cancel,
  }) async {
    final deadline = _now().add(timeout);
    final since = issuedAfter.subtract(slack);
    OtpMailbox? mailbox;
    var reconnects = 0;

    // The last network trouble, until a poll goes through. If the time runs out
    // with this still set, the honest answer is "could not reach Gmail", not "no
    // code arrived".
    OtpReaderException? lastTrouble;

    try {
      while (true) {
        if (cancel?.isCancelled ?? false) {
          throw const OtpReaderException(OtpReaderProblem.cancelled);
        }
        try {
          mailbox ??= await _opened();
          final mails = await mailbox.fromVtop(since: since);
          lastTrouble = null;
          final found = _newestCode(mails, since, ignoreUids);
          if (found != null) return found;
        } on OtpReaderException catch (e) {
          // A refused password or a blocked account will not fix itself.
          if (e.problem != OtpReaderProblem.network || ++reconnects > 2)
            rethrow;
          lastTrouble = e;
          await _closeQuietly(mailbox);
          mailbox = null;
        }

        if (!_now().add(pollEvery).isBefore(deadline)) {
          throw lastTrouble ??
              const OtpReaderException(OtpReaderProblem.timedOut);
        }
        await _sleep(pollEvery);
      }
    } finally {
      await _closeQuietly(mailbox);
    }
  }

  /// Checks that the mailbox can be reached and signed in to, and what it holds
  /// from VTOP over the last [days] days. For the "Test connection" button.
  Future<MailboxSummary> check({int days = 30}) async {
    final mailbox = openMailbox();
    try {
      await mailbox.open();
      return await mailbox.summary(
        since: _now().subtract(Duration(days: days)),
      );
    } finally {
      await _closeQuietly(mailbox);
    }
  }

  Future<OtpMailbox> _opened() async {
    final mailbox = openMailbox();
    try {
      await mailbox.open();
    } catch (_) {
      await _closeQuietly(mailbox);
      rethrow;
    }
    return mailbox;
  }

  /// The code in the newest acceptable mail.
  OtpFound? _newestCode(
    List<MailMessage> mails,
    DateTime since,
    Set<int> ignoreUids,
  ) {
    final candidates = [
      for (final m in mails)
        if (VtopOtpEmail.isFromVtop(m.from) &&
            !ignoreUids.contains(m.uid) &&
            (m.received == null || !m.received!.isBefore(since)))
          m,
    ]..sort((a, b) => b.uid.compareTo(a.uid));

    for (final m in candidates) {
      final code = VtopOtpEmail.extractCode(m.body);
      if (code != null) {
        return OtpFound(code: code, uid: m.uid, received: m.received);
      }
    }
    return null;
  }

  Future<void> _closeQuietly(OtpMailbox? mailbox) async {
    if (mailbox == null) return;
    try {
      await mailbox.close();
    } catch (_) {}
  }
}

/// Gmail over IMAP, opened for reading only.
///
/// The password is a Google *app password* the student made for this, not their
/// Google password. Mail is fetched with `BODY.PEEK`, and the inbox is opened
/// with `EXAMINE`, so nothing is ever marked read, moved or deleted.
class ImapOtpMailbox implements OtpMailbox {
  ImapOtpMailbox({
    required this.email,
    required this.appPassword,
    this.host = 'imap.gmail.com',
    this.port = 993,
    this.secure = true,
    this.timeout = const Duration(seconds: 15),
  });

  final String email;
  final String appPassword;
  final String host;
  final int port;
  final bool secure;
  final Duration timeout;

  ImapClient? _client;

  @override
  Future<void> open() async {
    final client = ImapClient();
    _client = client;
    try {
      await client.connectToServer(
        host,
        port,
        isSecure: secure,
        timeout: timeout,
      );
      await client.login(email, appPassword).timeout(timeout);
      await client
          .examineMailbox(
            Mailbox(
              encodedName: 'INBOX',
              encodedPath: 'INBOX',
              flags: [MailboxFlag.inbox],
              pathSeparator: '/',
            ),
          )
          .timeout(timeout);
    } on OtpReaderException {
      rethrow;
    } catch (e) {
      throw classify(e);
    }
  }

  @override
  Future<List<MailMessage>> fromVtop({required DateTime since}) async {
    final client = _client;
    if (client == null) {
      throw const OtpReaderException(OtpReaderProblem.unexpected, 'not open');
    }
    try {
      final found = await client
          .uidSearchMessages(
            searchCriteria:
                'FROM "${VtopOtpEmail.sender}" SINCE ${imapDate(since)}',
          )
          .timeout(timeout);
      final sequence = found.matchingSequence;
      if (sequence == null || sequence.isEmpty) return const [];

      // Only the newest few: the code is in the latest one.
      final ids = sequence.toList()..sort((a, b) => b.compareTo(a));
      final newest = ids.take(5).toList();
      final fetched = await client
          .uidFetchMessages(
            MessageSequence.fromIds(newest, isUid: true),
            '(INTERNALDATE BODY.PEEK[])',
          )
          .timeout(timeout);

      return [
        for (final m in fetched.messages)
          if (m.uid != null)
            MailMessage(
              uid: m.uid!,
              received: m.decodeDate() ?? _internalDate(m.internalDate),
              from: m.fromEmail,
              subject: m.decodeSubject() ?? '',
              body:
                  '${m.decodeTextPlainPart() ?? ''}\n${m.decodeTextHtmlPart() ?? ''}',
            ),
      ];
    } catch (e) {
      throw classify(e);
    }
  }

  @override
  Future<MailboxSummary> summary({required DateTime since}) async {
    final client = _client;
    if (client == null) {
      throw const OtpReaderException(OtpReaderProblem.unexpected, 'not open');
    }
    try {
      final found = await client
          .uidSearchMessages(
            searchCriteria:
                'FROM "${VtopOtpEmail.sender}" SINCE ${imapDate(since)}',
          )
          .timeout(timeout);
      final sequence = found.matchingSequence;
      if (sequence == null || sequence.isEmpty) {
        return const MailboxSummary(count: 0);
      }

      // Only the arrival times are fetched, never a body, and at most the newest
      // few hundred: enough to count a month of codes exactly.
      final ids = sequence.toList()..sort((a, b) => b.compareTo(a));
      final newest = ids.take(300).toList();
      final fetched = await client
          .uidFetchMessages(
            MessageSequence.fromIds(newest, isUid: true),
            '(INTERNALDATE)',
          )
          .timeout(timeout);

      var count = 0;
      DateTime? latest;
      for (final m in fetched.messages) {
        final at = _internalDate(m.internalDate);
        // SINCE is a whole day, so the exact start is checked here.
        if (at != null && at.isBefore(since)) continue;
        count++;
        if (at != null && (latest == null || at.isAfter(latest))) latest = at;
      }
      return MailboxSummary(count: count, latest: latest);
    } catch (e) {
      throw classify(e);
    }
  }

  @override
  Future<void> close() async {
    final client = _client;
    _client = null;
    if (client == null) return;
    try {
      if (client.isLoggedIn) await client.logout().timeout(timeout);
    } catch (_) {
      // Closing must never get in the way.
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// IMAP's `SINCE` is a date, not a time, so ask from the day before [when] and
  /// let the reader filter by the exact time.
  static String imapDate(DateTime when) {
    final d = when.toUtc().subtract(const Duration(days: 1));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    return '${d.day}-${months[d.month - 1]}-${d.year}';
  }

  /// The reader's own words for whatever went wrong.
  static OtpReaderException classify(Object error) {
    if (error is OtpReaderException) return error;
    if (error is TimeoutException ||
        error is SocketException ||
        error is HandshakeException ||
        error is TlsException) {
      return OtpReaderException(OtpReaderProblem.network, '$error');
    }
    final text =
        '${error is ImapException ? error.message : error} '
                '${error is ImapException ? error.details : ''}'
            .toLowerCase();
    if (text.contains('authenticationfailed') ||
        text.contains('invalid credentials') ||
        text.contains('username and password not accepted') ||
        text.contains('authentication failed')) {
      return OtpReaderException(OtpReaderProblem.invalidCredentials, text);
    }
    if (text.contains('application-specific password') ||
        text.contains('imap access is disabled') ||
        text.contains('imap is disabled') ||
        text.contains('web login required') ||
        text.contains('[alert]') ||
        text.contains('not allowed') ||
        text.contains('disabled by')) {
      return OtpReaderException(OtpReaderProblem.accessBlocked, text);
    }
    if (text.contains('connection lost') ||
        text.contains('connection error') ||
        text.contains('client disconnected') ||
        text.contains('socket')) {
      return OtpReaderException(OtpReaderProblem.network, text);
    }
    return OtpReaderException(OtpReaderProblem.unexpected, text);
  }

  /// IMAP's INTERNALDATE: `13-Nov-2026 11:22:05 +0530`.
  static DateTime? _internalDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(
      r'(\d{1,2})-([A-Za-z]{3})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s*([+-])(\d{2})(\d{2})',
    ).firstMatch(raw);
    if (m != null) {
      const months = [
        'jan', 'feb', 'mar', 'apr', 'may', 'jun',
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec', //
      ];
      final month = months.indexOf(m.group(2)!.toLowerCase()) + 1;
      if (month > 0) {
        final offset = Duration(
          hours: int.parse(m.group(8)!),
          minutes: int.parse(m.group(9)!),
        );
        final local = DateTime.utc(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(1)!),
          int.parse(m.group(4)!),
          int.parse(m.group(5)!),
          int.parse(m.group(6)!),
        );
        // The time shown is local to the zone given; take it back to UTC.
        return (m.group(7) == '+' ? local.subtract(offset) : local.add(offset))
            .toLocal();
      }
    }
    try {
      return DateCodec.decodeDate(raw);
    } catch (_) {
      return null;
    }
  }
}
