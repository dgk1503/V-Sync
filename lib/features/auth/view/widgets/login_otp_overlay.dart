import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';
import 'package:vit_ap_student_app/features/thumb_dock/viewmodel/thumb_dock_active.dart';
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

/// Chooses between the expanded card and the collapsed capsule, and owns the
/// digits typed into the boxes.
class _Prompt extends ConsumerStatefulWidget {
  const _Prompt();

  @override
  ConsumerState<_Prompt> createState() => _PromptState();
}

class _PromptState extends ConsumerState<_Prompt> {
  /// The code typed so far. Held here, above the card/capsule switch, because
  /// [_Expanded] is unmounted every time the prompt collapses: the digits must
  /// survive the user minimising it to get on with something else.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(loginOtpChallengeProvider);
    // With the Thumb Dock on, the collapsed prompt lives on the dock's handle
    // (a countdown; tap to reopen), so the floating capsule would only sit on
    // top of it. Without the dock the capsule is unchanged.
    final dockCarriesIt = ref.watch(thumbDockActiveProvider);

    return Stack(
      children: [
        if (challenge.isMinimized) ...[
          if (!dockCarriesIt) _DraggableCapsule(),
        ] else
          Positioned.fill(child: _Expanded(controller: _controller)),
      ],
    );
  }
}

/// The capsule: it follows the finger while it is dragged and, on release,
/// settles against the nearer side of the screen.
///
/// Only the side is chosen for the user; the height is wherever they let go, so
/// it can be parked clear of whatever they are reading. It never rests in the
/// middle of the screen, where it would cover the content.
///
/// The position lives here rather than inside the capsule so it survives the
/// card-to-capsule switch: minimising and restoring must not send the capsule
/// back to its corner, because the user put it somewhere on purpose.
///
/// It is clamped to the screen and lifted clear of the keyboard, so it can never
/// end up somewhere it cannot be reached from again.
class _DraggableCapsule extends StatefulWidget {
  @override
  State<_DraggableCapsule> createState() => _DraggableCapsuleState();
}

class _DraggableCapsuleState extends State<_DraggableCapsule> {
  /// Where the capsule was last left, or null while it is still home.
  Offset? _offset;

  /// While the finger is down the capsule must track it exactly; the glide to
  /// the side only runs once it is let go.
  bool _dragging = false;

  static const double _edge = 16;
  static const double _capsuleHeight = 44;

  /// The capsule's real width. Its text changes ("OTP 02:59", "Enter OTP"), so
  /// it is measured after layout rather than guessed: a guess that is too small
  /// lets the capsule hang off the edge it docks against.
  double _capsuleWidth = 150;
  final _capsuleKey = GlobalKey();

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _capsuleKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      if ((box.size.width - _capsuleWidth).abs() > 0.5) {
        setState(() => _capsuleWidth = box.size.width);
      }
    });
  }

  /// The capsule's home: bottom-right, above the floating navbar, so it is
  /// visible without covering the back button or the page header.
  static const double _navbarClearance = 96;

  @override
  Widget build(BuildContext context) {
    _measure();
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final maxLeft = (size.width - _capsuleWidth - _edge).clamp(0.0, size.width);
    final maxTop = (size.height - _capsuleHeight - _edge - keyboard).clamp(
      0.0,
      size.height,
    );
    final home = Offset(
      maxLeft,
      (size.height - _capsuleHeight - _navbarClearance - bottomInset - keyboard)
          .clamp(0.0, maxTop),
    );
    final at = _offset ?? home;
    final left = at.dx.clamp(_edge, maxLeft);
    final top = at.dy.clamp(0.0, maxTop);

    void settle() {
      // Nearer side wins, judged by where the capsule's middle is.
      final middle = left + _capsuleWidth / 2;
      setState(() {
        _dragging = false;
        _offset = Offset(middle < size.width / 2 ? _edge : maxLeft, top);
      });
    }

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: GestureDetector(
        // A drag moves it and a tap reopens. Opaque so a tap on the transparent
        // gutter around the capsule still counts as a tap on it.
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (details) => setState(
          () =>
              _offset = Offset(left + details.delta.dx, top + details.delta.dy),
        ),
        onPanEnd: (_) => settle(),
        onPanCancel: settle,
        child: _Capsule(key: _capsuleKey),
      ),
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
  const _Capsule({super.key});

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
  const _Expanded({required this.controller});

  /// Owned by [_Prompt] so the digits survive the user minimising the prompt.
  final TextEditingController controller;

  @override
  ConsumerState<_Expanded> createState() => _ExpandedState();
}

class _ExpandedState extends ConsumerState<_Expanded>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Focus after the first frame: requesting focus during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The controller belongs to [_Prompt]: it outlives this card on purpose.
    _focusNode.dispose();
    super.dispose();
  }

  /// Puts the keyboard back after the user returns from reading the code.
  ///
  /// Android drops the IME connection while the app is in the background (the
  /// user reading the OTP in Gmail is the case this exists for), and a field
  /// that never lost *focus* is no longer enough for Flutter to re-open it:
  /// requesting focus on an already-focused node is a no-op, so the keyboard
  /// had to be asked for explicitly. Measured: without this, returning from the
  /// background emits no `TextInput.show` at all. Same helper as the tap path.
  ///
  /// The card stays up across the trip, so it has to get its keyboard back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(loginOtpChallengeProvider).isBusy) return;
      _requestOtpKeyboard(_focusNode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(loginOtpChallengeProvider);
    final notifier = ref.read(loginOtpChallengeProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // The moment VTOP accepts a code that came from Gmail: drop the keyboard and
    // give a small tap of feedback, as the tick appears.
    ref.listen<OtpChallenge>(loginOtpChallengeProvider, (previous, next) {
      if (next.isSucceeded && !(previous?.isSucceeded ?? false)) {
        _focusNode.unfocus();
        HapticFeedback.mediumImpact();
      }
    });

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
                // On success the card shows a tick, then shrinks away. `t` runs
                // 0 to 1 over [kOtpSuccessHold], the same time the prompt stays.
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: challenge.isSucceeded ? 1 : 0,
                  ),
                  duration: kOtpSuccessHold,
                  builder: (context, t, _) {
                    final exit = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - exit,
                      child: Transform.scale(
                        scale: 1 - 0.06 * exit,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.outlineVariant,
                              width: 0.75,
                            ),
                          ),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (challenge.isSucceeded)
                                  _OtpSuccess(progress: t),
                                // Kept mounted (just not shown) so the code box and its
                                // focus survive; only the tick takes its place.
                                Offstage(
                                  offstage: challenge.isSucceeded,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Verification',
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                          // `container` and `excludeSemantics` matter here:
                                          // IconButton emits its own semantics node, so a plain
                                          // wrapper's label is discarded and the control reads
                                          // as an unlabelled button to a screen reader.
                                          Semantics(
                                            container: true,
                                            excludeSemantics: true,
                                            label: 'Minimise',
                                            button: true,
                                            child: IconButton(
                                              key: const Key('otp-minimise'),
                                              onPressed: notifier.minimize,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              // Sized up from the neighbouring 15px body text
                                              // so the collapse control reads as a control and
                                              // not as punctuation.
                                              icon: Icon(
                                                Icons
                                                    .keyboard_double_arrow_down_rounded,
                                                size: 26,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        challenge.message.isEmpty
                                            ? 'Enter the OTP sent to your registered email.'
                                            : challenge.message,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(fontSize: 13.5),
                                      ),
                                      // The automatic Gmail reader: not enabled, fetching, checking
                                      // the code, or why it stopped. Typing the code always works.
                                      if (challenge.autoPhase != null) ...[
                                        const SizedBox(height: 10),
                                        _AutoLine(challenge: challenge),
                                      ],
                                      const SizedBox(height: 20),
                                      _OtpField(
                                        controller: widget.controller,
                                        focusNode: _focusNode,
                                        enabled: !challenge.isBusy,
                                        hasError:
                                            challenge.errorMessage != null,
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
                                                foregroundColor:
                                                    colors.onSurface,
                                                minimumSize:
                                                    const Size.fromHeight(48),
                                                side: BorderSide(
                                                  color: colors.outlineVariant,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
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
                                                  : () => notifier.submitOtp(
                                                      widget.controller.text,
                                                    ),
                                              style: FilledButton.styleFrom(
                                                elevation: 0,
                                                backgroundColor: colors.primary,
                                                foregroundColor:
                                                    colors.onPrimary,
                                                disabledBackgroundColor:
                                                    colors.surfaceContainerHigh,
                                                disabledForegroundColor:
                                                    colors.onSurfaceVariant,
                                                minimumSize:
                                                    const Size.fromHeight(48),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: challenge.isSubmitting
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Verify',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Instrument Sans',
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

/// Focuses the OTP field and makes sure the keyboard is actually attached.
///
/// `requestFocus()` alone is not enough when the field already has focus: the
/// OS drops the IME while the app is in the background, and a node that is
/// already focused is not re-opened by asking for focus again. `TextInput.show`
/// asks the platform for the keyboard for the field that is attached, which is
/// what brings it back after a trip to Gmail (or after the user dismissed it by
/// hand).
void _requestOtpKeyboard(FocusNode focusNode) {
  final alreadyFocused = focusNode.hasFocus;
  focusNode.requestFocus();
  if (alreadyFocused) {
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }
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

        return GestureDetector(
          // Taps on the boxes are handled here, and the field itself is kept out
          // of the hit-test path (`IgnorePointer` below) so no recognizer of its
          // own can claim the tap first.
          //
          // This is the state the user is in after reading the code in Gmail:
          // the field still holds focus while the OS has dismissed the
          // keyboard, and focusing a focused node does nothing. Asking for the
          // keyboard has to happen on every tap, unconditionally, rather than
          // depending on what `EditableText` decides to do with the tap.
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _requestOtpKeyboard(focusNode) : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
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
              ),
              // The boxes share whatever width is available rather than sitting
              // at a fixed 46 each: six fixed boxes plus gaps need 306px, which
              // does not fit inside the card on a 360dp screen, and the row
              // overflowed it. Centred and capped so it does not stretch across
              // a tablet either.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Row(
                    children: [
                      for (var i = 0; i < _length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        // Width flexes, height is fixed. An AspectRatio here
                        // is not an option: this Row is a non-positioned child
                        // of a Stack, which hands it loose constraints, and
                        // AspectRatio cannot size itself against unbounded
                        // width.
                        Expanded(
                          child: _Box(
                            digit: i < digits.length ? digits[i] : '',
                            active: focused && i == digits.length,
                            error: hasError,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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

/// What the automatic reader is doing, as one quiet line above the code boxes.
class _AutoLine extends StatelessWidget {
  const _AutoLine({required this.challenge});

  final OtpChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'Instrument Sans',
      fontSize: 12.5,
      height: 1.35,
      color: colors.onSurfaceVariant,
    );

    Widget spinner() => SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 1.8,
        color: colors.onSurfaceVariant,
      ),
    );

    Widget row(Widget lead, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: lead),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: const ValueKey('otp-auto-status'),
            style: style,
          ),
        ),
      ],
    );

    switch (challenge.autoPhase) {
      case OtpAutoPhase.fetching:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(spinner(), 'Fetching OTP automatically...'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: colors.surfaceContainerHigh,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );
      case OtpAutoPhase.verifying:
        return row(spinner(), 'OTP fetched. Verifying...');
      case OtpAutoPhase.failed:
        return row(
          Icon(
            LucideIcons.mailWarning,
            size: 14,
            color: colors.onSurfaceVariant,
          ),
          challenge.autoStatus ?? 'Could not fetch the code automatically.',
        );
      case OtpAutoPhase.notEnabled:
        return row(
          Icon(LucideIcons.mailX, size: 14, color: colors.onSurfaceVariant),
          'Automatic OTP fetching is not enabled.',
        );
      case OtpAutoPhase.succeeded:
      case null:
        return const SizedBox.shrink();
    }
  }
}

/// The success state: a green circle that pops in, a tick that draws itself, and
/// "OTP fetched successfully" under it, as a payment confirmation does.
///
/// [progress] runs 0 to 1 over the time the prompt stays up.
class _OtpSuccess extends StatelessWidget {
  const _OtpSuccess({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final green = AppStatusColors.of(context).success;

    final pop = Curves.easeOutBack.transform((progress / 0.22).clamp(0.0, 1.0));
    final tick = Curves.easeInOut.transform(
      ((progress - 0.14) / 0.22).clamp(0.0, 1.0),
    );
    final words = ((progress - 0.34) / 0.16).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: pop,
            child: SizedBox(
              width: 84,
              height: 84,
              child: CustomPaint(
                key: const ValueKey('otp-success-tick'),
                painter: _TickPainter(color: green, tick: tick),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Opacity(
            opacity: words,
            child: Text(
              'OTP fetched successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Opacity(
            opacity: words,
            child: Text(
              'Signing you in',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 12.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft green disc, a ring, and a tick drawn stroke by stroke ([tick] 0 to 1).
class _TickPainter extends CustomPainter {
  _TickPainter({required this.color, required this.tick});

  final Color color;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tick),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.tick != tick || old.color != color;
}
