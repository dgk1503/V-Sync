import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';

/// A heading rendered with the active accent theme's gradient instead of
/// a flat color. All accent themes share the same gradient treatment and
/// only change their palette.
class AccentGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AccentGradientText(this.text, {super.key, this.style});

  static List<Color> gradientFor(ThemeData theme) {
    final accent = AppThemeAccent.resolve(theme);
    if (accent != null) return accent.gradient;

    final colorScheme = theme.colorScheme;
    return [colorScheme.primary, colorScheme.onSurfaceVariant];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = gradientFor(theme);

    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(colors: colors).createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
