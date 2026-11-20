import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/services/gmail_otp_store.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';

/// Finds the VTOP code for the OTP prompt, if the student has set that up.
abstract class OtpAutoFill {
  /// Whether automatic reading is set up and switched on.
  Future<bool> isReady();

  /// The code of the OTP requested at [issuedAfter], or null when automatic
  /// reading is not set up or is switched off (the prompt then just waits for a
  /// code typed by hand).
  ///
  /// Throws [OtpReaderException] when it is set up but could not read the code.
  Future<OtpFound?> find({
    required DateTime issuedAfter,
    Set<int> ignoreUids = const {},
    required OtpCancel cancel,
  });
}

/// Reads the code from the student's own Gmail over IMAP.
class GmailOtpAutoFill implements OtpAutoFill {
  GmailOtpAutoFill(
    this._store, {
    MailboxFactory Function(GmailOtpAccount)? mailbox,
  }) : _mailbox =
           mailbox ??
           ((account) =>
               () => ImapOtpMailbox(
                 email: account.email,
                 appPassword: account.appPassword,
               ));

  final GmailOtpStore _store;
  final MailboxFactory Function(GmailOtpAccount) _mailbox;

  @override
  Future<bool> isReady() async =>
      await _store.read() != null && await _store.isEnabled();

  @override
  Future<OtpFound?> find({
    required DateTime issuedAfter,
    Set<int> ignoreUids = const {},
    required OtpCancel cancel,
  }) async {
    final account = await _store.read();
    if (account == null || !await _store.isEnabled()) return null;

    return GmailOtpReader(openMailbox: _mailbox(account)).waitForCode(
      issuedAfter: issuedAfter,
      ignoreUids: ignoreUids,
      cancel: cancel,
    );
  }
}

/// How to open a mailbox for an account: Gmail over IMAP in the app, a fake in
/// tests.
final otpMailboxBuilderProvider =
    Provider<MailboxFactory Function(GmailOtpAccount)>(
      (ref) =>
          (account) =>
              () => ImapOtpMailbox(
                email: account.email,
                appPassword: account.appPassword,
              ),
    );

final otpAutoFillProvider = Provider<OtpAutoFill>(
  (ref) => GmailOtpAutoFill(
    ref.watch(gmailOtpStoreProvider),
    mailbox: ref.watch(otpMailboxBuilderProvider),
  ),
);
