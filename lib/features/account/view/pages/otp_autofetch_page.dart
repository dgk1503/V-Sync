import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/services/gmail_otp_store.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/core/utils/launch_web.dart';
import 'package:vit_ap_student_app/features/auth/model/otp_email.dart';
import 'package:vit_ap_student_app/features/auth/services/gmail_otp_reader.dart';
import 'package:vit_ap_student_app/features/auth/services/otp_auto_fill.dart';

const String _securityUrl = 'https://myaccount.google.com/security';
const String _appPasswordsUrl = 'https://myaccount.google.com/apppasswords';

/// Sets up reading the VTOP code from the student's own Gmail.
///
/// Everything happens on the phone: the app signs in to Gmail with a Google app
/// password the student makes for it, looks only at mail from VTOP's sender, and
/// only while a code is being waited for. Nothing goes to any server of ours.
class OtpAutofetchPage extends ConsumerStatefulWidget {
  const OtpAutofetchPage({super.key});

  @override
  ConsumerState<OtpAutofetchPage> createState() => _OtpAutofetchPageState();
}

class _OtpAutofetchPageState extends ConsumerState<OtpAutofetchPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;

  /// The student has read the disclosure and agreed. Asked afresh each time the
  /// setup is opened, before any field for the Gmail address or app password is
  /// shown.
  bool _agreed = false;

  /// What the last attempt did, in words; [_isError] says how to colour it.
  String? _result;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _say(String text, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _result = text;
      _isError = error;
    });
  }

  /// Signs in with [account] and counts VTOP's mail, to prove it works.
  Future<MailboxSummary> _check(GmailOtpAccount account) {
    final build = ref.read(otpMailboxBuilderProvider);
    return GmailOtpReader(openMailbox: build(account)).check();
  }

  Future<void> _connect() async {
    final email = _email.text.trim();
    final password = GmailOtpStore.normalisePassword(_password.text);

    if (!GmailOtpStore.isValidEmail(email)) {
      _say('Enter the Gmail address your VTOP codes are sent to.', error: true);
      return;
    }
    if (password == null) {
      _say(
        'An app password is 16 letters, shown by Google in four groups of '
        'four. Paste it exactly as Google shows it.',
        error: true,
      );
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
    });
    final account = GmailOtpAccount(email: email, appPassword: password);
    try {
      final seen = await _check(account);
      await ref.read(gmailOtpSettingsProvider.notifier).connect(account);
      _password.clear();
      _say('Connected. ${_seenIn(seen)}', error: false);
    } on OtpReaderException catch (e) {
      _say(e.message, error: true);
    } catch (_) {
      _say('Could not connect to Gmail.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final account = await ref.read(gmailOtpStoreProvider).read();
    if (account == null) {
      _say('Gmail is not connected.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final seen = await _check(account);
      _say('Gmail works. ${_seenIn(seen)}', error: false);
    } on OtpReaderException catch (e) {
      _say(e.message, error: true);
    } catch (_) {
      _say('Could not connect to Gmail.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What the test found, in words: how many VTOP emails Gmail holds from the
  /// last 30 days and when the newest arrived.
  String _seenIn(MailboxSummary seen) {
    if (seen.count == 0) {
      return 'No email from VTOP in your Inbox in the last 30 days. The next '
          'code will be picked up when it arrives.';
    }
    final latest = seen.latest;
    final count =
        '${seen.count} VTOP email${seen.count == 1 ? '' : 's'} in your Inbox '
        'in the last 30 days';
    if (latest == null) return 'Found $count.';
    return 'Found $count. The newest arrived ${_when(latest)}.';
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    final time = DateFormat('h:mm a').format(at);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'today at $time';
    if (days == 1) return 'yesterday at $time';
    return 'on ${DateFormat('d MMM').format(at)} at $time';
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Gmail?'),
        content: const Text(
          'VSync forgets the app password and stops reading your mail. You can '
          'also revoke the app password in your Google account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(gmailOtpSettingsProvider.notifier).disconnect();
    _say('Removed. VSync no longer reads your Gmail.', error: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(gmailOtpSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Automatic OTP',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Text(
              'VSync can read the code VTOP emails you and enter it for you. '
              'It happens on this phone, through your own Gmail.',
              style: _body(context),
            ),
            const SizedBox(height: 14),
            if (!settings.loaded)
              const SizedBox.shrink()
            else if (settings.isConnected)
              _connected(context, settings)
            else
              _setup(context),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                key: const ValueKey('otp-result'),
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: _isError
                      ? AppStatusColors.of(context).danger
                      : AppStatusColors.of(context).success,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _disclosure(context),
          ],
        ),
      ),
    );
  }

  Widget _connected(BuildContext context, GmailOtpSettings settings) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.circleCheck,
                size: 15,
                color: AppStatusColors.of(context).success,
              ),
              const SizedBox(width: 6),
              Text(
                'Connected',
                key: const ValueKey('otp-connected'),
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppStatusColors.of(context).success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Addresses vary a lot in length. One line, shrunk to fit: a wrapped
          // address leaves a lone letter on the second line.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              settings.email!,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Read codes automatically', style: _body(context)),
              ),
              Switch.adaptive(
                value: settings.enabled,
                onChanged: _busy
                    ? null
                    : (value) => ref
                          .read(gmailOtpSettingsProvider.notifier)
                          .setEnabled(value),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _test,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : const Text(
                        'Test connection',
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 13.5,
                        ),
                      ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _remove,
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13.5,
                    color: AppStatusColors.of(context).danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The prominent disclosure Google Play asks for: what is accessed, what is
  /// stored, where it goes, and how to undo it. Shown before the setup fields.
  Future<void> _askConsent() async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Widget point(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(text)),
            ],
          ),
        );

        return AlertDialog(
          key: const ValueKey('otp-consent'),
          title: const Text('Read your VTOP code from Gmail?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To do this, VSync signs in to your Gmail account on this '
                  'phone with an app password that you create, and reads the '
                  'login code that VTOP emails you.',
                ),
                const SizedBox(height: 12),
                point(
                  'It only looks at email from ${VtopOtpEmail.sender}, and only '
                  'while VSync is waiting for a login code.',
                ),
                point(
                  'It only reads. It never changes, marks, moves, deletes or '
                  'sends any email.',
                ),
                point(
                  'Your Gmail address and app password are stored encrypted on '
                  'this phone (Android Keystore). They are used only to sign in '
                  'to Gmail, and are never sent to VSync or to anyone else.',
                ),
                point(
                  'Nothing from your mailbox leaves this phone, except the code '
                  'VSync enters into VTOP for you.',
                ),
                point(
                  'You can remove it here at any time, and revoke the app '
                  'password in your Google account.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I agree'),
            ),
          ],
        );
      },
    );
    if (agreed == true && mounted) setState(() => _agreed = true);
  }

  Widget _consentCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not set up',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is optional. It needs a Google app password, and VSync will '
            'ask you to review exactly what it can see before you enter '
            'anything.',
            style: _body(context),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _askConsent,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Review and set up',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setup(BuildContext context) {
    if (!_agreed) return _consentCard(context);

    final colors = Theme.of(context).colorScheme;

    Widget step(int n, String text, {String? action, String? url}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$n.',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: _body(context)),
                if (action != null && url != null)
                  InkWell(
                    onTap: () => directToWeb(url),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        action,
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: colors.tertiary,
                          decoration: TextDecoration.underline,
                          decorationColor: colors.tertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set up, once',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          step(
            1,
            'Turn on 2-Step Verification for the Google account that gets '
            'your VTOP emails.',
            action: 'Open Google security',
            url: _securityUrl,
          ),
          step(
            2,
            'Create an app password and name it VSync.',
            action: 'Open app passwords',
            url: _appPasswordsUrl,
          ),
          step(3, 'Paste your Gmail address and the app password here.'),
          Text(
            'If Google says app passwords are not available for your account, '
            'your college has turned them off and this cannot be used.',
            style: _caption(context),
          ),
          const SizedBox(height: 16),
          _field(
            context,
            controller: _email,
            label: 'Gmail address',
            keyboard: TextInputType.emailAddress,
            enabled: !_busy,
            hints: const [AutofillHints.email],
          ),
          const SizedBox(height: 10),
          _field(
            context,
            controller: _password,
            label: 'App password',
            enabled: !_busy,
            obscure: !_showPassword,
            suffix: IconButton(
              tooltip: _showPassword ? 'Hide' : 'Show',
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19,
                color: colors.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Connect Gmail',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool enabled,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    List<String>? hints,
  }) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: hints,
      style: TextStyle(
        fontFamily: 'Instrument Sans',
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 14,
          color: colors.onSurfaceVariant,
        ),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Said plainly, before anything is connected and after: what is read, what
  /// is kept, and how to take it back.
  Widget _disclosure(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: _caption(context))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this does',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        line(
          'Looks only at mail from ${VtopOtpEmail.sender}, and only while '
          'VSync is waiting for a login code.',
        ),
        line(
          'Reads, never changes: nothing is marked as read, moved or deleted.',
        ),
        line(
          'The app password is kept encrypted on this phone and used only to '
          'sign in to Gmail. It is never sent to VSync or anyone else.',
        ),
        line(
          'Remove it here any time, and revoke it in your Google account to be '
          'sure.',
        ),
      ],
    );
  }

  TextStyle _body(BuildContext context) => TextStyle(
    fontFamily: 'Instrument Sans',
    fontSize: 13.5,
    height: 1.45,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  TextStyle _caption(BuildContext context) => TextStyle(
    fontFamily: 'Instrument Sans',
    fontSize: 12,
    height: 1.4,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
