import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';

/// The app-level OTP surface, mounted once in `MaterialApp.builder` so it sits
/// above the Navigator and survives every route change.
///
/// It is a pure wrapper: it renders nothing when no challenge is active, and it
/// holds no state of its own. Everything - expanded or collapsed, the countdown,
/// the error - belongs to [loginOtpChallengeProvider], so a rebuild underneath
/// it cannot reset the prompt.
class LoginOtpOverlay extends ConsumerWidget {
  final Widget child;

  const LoginOtpOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(loginOtpChallengeProvider);

    return Stack(
      children: [
        child,
        if (challenge.isActive) const Positioned.fill(child: _OtpHost()),
      ],
    );
  }
}

/// Hosts the prompt in its own `Overlay`.
///
/// Two things inside it - `EditableText` (the OTP boxes) and `Tooltip` - both
/// require an Overlay ancestor, and there is none up here: the Navigator, which
/// owns the app's real Overlay, is a sibling subtree *below* this point, not an
/// ancestor. Without this the field throws the moment it takes focus.
///
/// The entry is created once and kept. `Overlay` only reads `initialEntries` on
/// first build, so rebuilding it would freeze the prompt in whatever state it
/// started in; instead the entry builds [_Prompt], which watches the provider
/// and swaps between the card and the capsule on its own.
class _OtpHost extends ConsumerStatefulWidget {
  const _OtpHost();

  @override
  ConsumerState<_OtpHost> createState() => _OtpHostState();
}

class _OtpHostState extends ConsumerState<_OtpHost> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => const _Prompt(),
  );

  @override
  void dispose() {
    _entry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

/// Chooses between the expanded card and the collapsed capsule.
class _Prompt extends ConsumerWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(loginOtpChallengeProvider);

    return Stack(
      children: [
        if (challenge.isMinimized)
          const Positioned(right: 16, bottom: 96, child: _Capsule())
        else
          const Positioned.fill(child: _Expanded()),
      ],
    );
  }
}

/// Closes the prompt and abandons the pending VTOP request.
///
/// Without the second half, whatever operation triggered the OTP would sit
/// waiting on a completer nobody is going to complete.
void _dismissChallenge(WidgetRef ref) {
  final service = serviceLocator<VtopClientService>();
  if (service.isOtpPending) service.cancelOtp();
  ref.read(loginOtpChallengeProvider.notifier).dismiss();
}

/// The collapsed prompt: a capsule above the navbar carrying the countdown, so
/// the user can tell how long they have and carry on using the app.
class _Capsule extends ConsumerWidget {
  const _Capsule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(loginOtpChallengeProvider);
    final colors = Theme.of(context).colorScheme;

    return _Dismissible(
      onTap: () => ref.read(loginOtpChallengeProvider.notifier).reopen(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 17, color: colors.onPrimary),
            const SizedBox(width: 8),
            Text(
              challenge.remainingSeconds > 0
                  ? 'OTP ${OtpChallenge.formatSeconds(challenge.remainingSeconds)}'
                  : 'Enter OTP',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Expanded extends ConsumerStatefulWidget {
  const _Expanded();

  @override
  ConsumerState<_Expanded> createState() => _ExpandedState();
}

class _ExpandedState extends ConsumerState<_Expanded> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focus after the first frame: requesting focus during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(loginOtpChallengeProvider);
    final notifier = ref.read(loginOtpChallengeProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: colors.scrim.withValues(alpha: 0.45),
        child: GestureDetector(
          // Tapping the scrim collapses rather than dismisses, so the code can
          // never be lost by brushing the card away. Opaque behaviour is
          // required: the child is a centred card, so without it the scrim
          // would only be tappable where the card happens to be.
          behavior: HitTestBehavior.opaque,
          onTap: notifier.minimize,
          child: Center(
            // Lift the card clear of the keyboard instead of letting the IME
            // cover the boxes.
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant, width: 0.75),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Verification',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Semantics(
                            label: 'Minimise',
                            button: true,
                            child: IconButton(
                              key: const Key('otp-minimise'),
                              onPressed: notifier.minimize,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.minimize_rounded,
                                size: 20,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        challenge.message.isEmpty
                            ? 'Enter the OTP sent to your registered email.'
                            : challenge.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _OtpField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !challenge.isBusy,
                        hasError: challenge.errorMessage != null,
                      ),
                      if (challenge.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          challenge.errorMessage!,
                          style: TextStyle(
                            fontFamily: 'Instrument Sans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: colors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: challenge.canResend
                                  ? notifier.resendOtp
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.onSurface,
                                minimumSize: const Size.fromHeight(48),
                                side: BorderSide(color: colors.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                challenge.remainingSeconds > 0
                                    ? 'Resend (${challenge.remainingSeconds}s)'
                                    : 'Resend OTP',
                                style: const TextStyle(
                                  fontFamily: 'Instrument Sans',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: challenge.isBusy
                                  ? null
                                  : () => notifier.submitOtp(_controller.text),
                              style: FilledButton.styleFrom(
                                elevation: 0,
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                disabledBackgroundColor: colors.surfaceContainerHigh,
                                disabledForegroundColor: colors.onSurfaceVariant,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: challenge.isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Verify',
                                      style: TextStyle(
                                        fontFamily: 'Instrument Sans',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: challenge.isBusy
                              ? null
                              : () => _dismissChallenge(ref),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable region that reports presses reliably.
///
/// `Container` with a decoration does not take hits on its own where it is
/// transparent, and the capsule floats over content that would otherwise
/// swallow the tap.
class _Dismissible extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _Dismissible({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: child,
  );
}

/// Six boxes over a single invisible text field.
///
/// Hand-rolled rather than `Pinput`, which registers a
/// `RestorableTextEditingController` and asserts when built inside an overlay
/// rather than a route.
class _OtpField extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;

  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
  });

  static const int _length = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(loginOtpChallengeProvider.notifier);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final digits = value.text.characters.toList();
        final focused = focusNode.hasFocus && enabled;

        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: _length,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (value) => notifier.submitOtp(value),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _Box(
                    digit: i < digits.length ? digits[i] : '',
                    active: focused && i == digits.length,
                    error: hasError,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final String digit;
  final bool active;
  final bool error;

  const _Box({required this.digit, required this.active, required this.error});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filled = digit.isNotEmpty && !error;

    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? colors.primary : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? colors.error
              : filled || active
              ? colors.primary
              : colors.outlineVariant,
          width: error ? 1.2 : 1,
        ),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: filled ? colors.onPrimary : colors.onSurface,
        ),
      ),
    );
  }
}
