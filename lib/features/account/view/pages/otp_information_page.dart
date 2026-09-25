import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/utils/launch_web.dart';

const String _githubRepositoryUrl = 'https://github.com/dgk1503/V-Sync';

Future<void> showOtpInformationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const OtpInformationSheet(),
  );
}

class OtpInformationSheet extends StatelessWidget {
  const OtpInformationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
      fontSize: 15,
    );
    final linkStyle = bodyStyle?.copyWith(
      color: colorScheme.tertiary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.tertiary,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentGradientText(
                'Automatic OTP Fetching',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Automatic notification-based OTP fetching is not supported in the Google Play Store version of VSync due to platform policy guidelines.',
                style: bodyStyle,
              ),
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: [
                    const TextSpan(
                      text:
                          'VSync is an open-source project built for VIT-AP students. To learn more about project updates, feature documentation, or source code, visit our ',
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: InkWell(
                        onTap: () => directToWeb(_githubRepositoryUrl),
                        borderRadius: BorderRadius.circular(4),
                        child: Text('GitHub repository', style: linkStyle),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
