import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_viewmodel.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';

Future<void> showLoginOtpBottomSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (context) => const _LoginOtpSheet(),
  );
}

class _LoginOtpSheet extends ConsumerStatefulWidget {
  const _LoginOtpSheet();

  @override
  ConsumerState<_LoginOtpSheet> createState() => _LoginOtpSheetState();
}

class _LoginOtpSheetState extends ConsumerState<_LoginOtpSheet>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorMessage;
  bool _resendSuccess = false;
  Timer? _cooldownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user leaves to read the OTP (e.g. Gmail) and returns, the soft
    // keyboard was dismissed and `autofocus` does not re-fire. Re-request focus
    // and force the keyboard back so they can type without tapping the field.
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_focusNode.hasFocus) {
          // Focus was retained but the keyboard is hidden — reshow it.
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        } else {
          _focusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit OTP');
      return;
    }
    setState(() => _errorMessage = null);
    await ref.read(loginOtpViewModelProvider.notifier).submitOtp(pin);
  }

  Future<void> _resend() async {
    setState(() {
      _errorMessage = null;
      _resendSuccess = false;
    });
    await ref.read(loginOtpViewModelProvider.notifier).resendOtp();
    if (mounted) {
      setState(() => _resendSuccess = true);
      _startCooldown();
    }
  }

  void _startCooldown() {
    setState(() {
      _remainingSeconds = 180;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel verification?'),
        content: const Text(
          'If you cancel, the current operation will fail '
          'and you will need to try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      serviceLocator<VtopClientService>().cancelOtp();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otpState = ref.watch(loginOtpViewModelProvider);
    final isLoading = otpState?.isLoading == true;
    final isOnCooldown = _remainingSeconds > 0;

    ref.listen(loginOtpViewModelProvider, (previous, next) {
      if (next == null) return;
      next.whenOrNull(
        data: (_) {
          // OTP verified — close sheet. The original operation resumes
          // automatically via the Completer in VtopClientService.
          Navigator.of(context).pop();
        },
        error: (error, _) {
          if (mounted) {
            _pinController.clear();
            setState(() {
              _errorMessage = error.toString();
              _resendSuccess = false;
            });
            _focusNode.requestFocus();
          }
        },
      );
    });

    final defaultPinTheme = PinTheme(
      width: 46,
      height: 56,
      textStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the OTP sent to your registered email to continue.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            if (_resendSuccess) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OTP resent to your email',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: Pinput(
                controller: _pinController,
                focusNode: _focusNode,
                length: 6,
                autofocus: true,
                enabled: !isLoading,
                forceErrorState: _errorMessage != null,
                errorText: _errorMessage,
                defaultPinTheme: defaultPinTheme,
                errorBuilder: (errorText, pin) {
                  if (errorText == null || errorText.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  );
                },
                separatorBuilder: (index) => const SizedBox(width: 6),
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  textStyle: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                errorPinTheme: defaultPinTheme.copyWith(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 1.2),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (isLoading || isOnCooldown) ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isOnCooldown
                          ? 'Resend (${_remainingSeconds}s)'
                          : 'Resend OTP',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor:
                          theme.colorScheme.surfaceContainerHigh,
                      disabledForegroundColor:
                          theme.colorScheme.onSurfaceVariant,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Loader(),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: isLoading ? null : _cancel,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
