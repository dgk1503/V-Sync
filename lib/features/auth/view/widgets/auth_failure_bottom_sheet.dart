import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/constants/server_constants.dart';
import 'package:vit_ap_student_app/core/utils/launch_web.dart';
import 'package:vit_ap_student_app/features/account/view/pages/manage_credentials_page.dart';

Future<void> showAuthFailureBottomSheet({
  required BuildContext context,
  required String errorMessage,
  required bool isLoggedIn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AuthFailureSheet(errorMessage: errorMessage, isLoggedIn: isLoggedIn),
  );
}

class _AuthFailureSheet extends StatelessWidget {
  final String errorMessage;
  final bool isLoggedIn;

  const _AuthFailureSheet({
    required this.errorMessage,
    required this.isLoggedIn,
  });

  bool get _isMaxAttemptsReached =>
      errorMessage.contains('Number Of Maximum Fail Attempts Reached');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMaxAttemptsReached
                    ? Icons.lock_reset_rounded
                    : Icons.key_off_rounded,
                color: colorScheme.onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              _isMaxAttemptsReached
                  ? 'Reset Password'
                  : 'Authentication Failed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              _isMaxAttemptsReached
                  ? 'You recently changed your VTOP password on the website. The app continued making requests with the old password, which locked your account. You\'ll need to reset your password on VTOP once more to unlock it.'
                  : isLoggedIn
                  ? 'The saved password in the app no longer matches your VTOP account. Please update it in Manage Credentials so the app can connect again.'
                  : 'The credentials you entered don\'t match any VTOP account. Please check your username and password and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // Steps card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to fix this',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isMaxAttemptsReached) ...[
                    const _StepItem(
                      icon: Icons.language_rounded,
                      text: 'Open VTOP and reset your password again',
                    ),
                    const SizedBox(height: 8),
                    const _StepItem(
                      icon: Icons.logout_rounded,
                      text: 'Log out from the app',
                    ),
                    const SizedBox(height: 8),
                    const _StepItem(
                      icon: Icons.login_rounded,
                      text: 'Log in again with the new password',
                    ),
                  ] else if (isLoggedIn) ...[
                    const _StepItem(
                      icon: Icons.manage_accounts_rounded,
                      text: 'Open Manage Credentials and update your password',
                    ),
                  ] else ...[
                    const _StepItem(
                      icon: Icons.language_rounded,
                      text: 'Verify your credentials on the VTOP website',
                    ),
                    const SizedBox(height: 8),
                    const _StepItem(
                      icon: Icons.login_rounded,
                      text: 'Re-enter the correct username and password',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Primary CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (isLoggedIn && !_isMaxAttemptsReached) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ManageCredentialsPage(),
                      ),
                    );
                  } else {
                    directToWeb(
                      '${ServerConstants.vtopBaseUrl}${ServerConstants.vtopLoginPage}',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondaryContainer,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: Icon(
                  isLoggedIn && !_isMaxAttemptsReached
                      ? Icons.manage_accounts_rounded
                      : Icons.open_in_new_rounded,
                  size: 18,
                ),
                label: Text(
                  isLoggedIn && !_isMaxAttemptsReached
                      ? 'Manage Credentials'
                      : 'Open VTOP Login Page',
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Dismiss
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StepItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
