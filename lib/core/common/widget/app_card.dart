import 'package:flutter/material.dart';

/// The standard card used across the app.
///
/// Cards are intentionally neutral in every theme. The active theme is
/// reserved for headings and selected states; card surfaces do not carry a
/// green, gold, pink, or red background tint.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 18,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
