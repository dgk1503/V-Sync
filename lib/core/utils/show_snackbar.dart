import 'package:flutter/material.dart';

enum SnackBarType { success, warning, error }

void showSnackBar(BuildContext context, String content, SnackBarType type) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.brightness == Brightness.dark;

  // Monochrome: dark capsule on light theme, light capsule on dark theme.
  final background = isDark ? Colors.white : const Color(0xFF1A1A1A);
  final foreground = isDark ? Colors.black : Colors.white;

  IconData prefixIcon;
  switch (type) {
    case SnackBarType.success:
      prefixIcon = Icons.check_circle_rounded;
      break;
    case SnackBarType.warning:
      prefixIcon = Icons.warning_amber_rounded;
      break;
    case SnackBarType.error:
      prefixIcon = Icons.error_outline_rounded;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        showCloseIcon: true,
        closeIconColor: foreground.withValues(alpha: 0.7),
        content: Row(
          children: [
            Icon(prefixIcon, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
