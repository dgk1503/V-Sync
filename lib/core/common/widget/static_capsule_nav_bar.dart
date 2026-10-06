import 'dart:ui';

import 'package:flutter/material.dart';

import 'liquid_glass_navigation_bar.dart';

const double _staticCapsuleRadius = 34;
const double _staticItemSize = 50;
const double _staticItemGap = 12;

/// The plain frosted capsule that is used when Liquid Glass is switched off in
/// Settings > Customization.
///
/// It deliberately shares nothing visual with [LiquidGlassNavigationBar]: no
/// shader, no lens blob, no hold-and-slide gesture and no velocity stretch —
/// just a static blurred pill with a circular active indicator, which is how
/// the navbar looked before the glass effect existed.
class StaticCapsuleNavBar extends StatelessWidget {
  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const StaticCapsuleNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          // Known bug: this navbar rides up with the keyboard.
          //
          // The navbar lives in the body Stack and `extendBody: true` means the
          // Scaffold still resizes that body for the IME, so the capsule ends up
          // at the bottom of the *resized* area - roughly the keyboard height
          // above the real screen bottom - while any keyboard is open.
          //
          // It cannot be fixed from in here. `Scaffold` wraps a resizing body in
          // `MediaQuery.removeViewInsets`, so `MediaQuery.viewInsetsOf(context)`
          // is 0 at this point, and `View.of(context)` does not reach the root
          // view from this subtree either. The inset has to be captured above
          // the Scaffold - in `bottom_navigation_bar.dart`, where
          // `MaterialApp.builder` still sees the real value - and passed down.
14 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_staticCapsuleRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_staticCapsuleRadius),
            // Blurs whatever scrolls behind the capsule.
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(_staticCapsuleRadius),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (i > 0) const SizedBox(width: _staticItemGap),
                      _StaticNavItem(
                        icon: destinations[i].icon,
                        isActive: selectedIndex == i,
                        // The labels are decorative here; the icon carries the
                        // meaning and matches the glass bar's icon set.
                        semanticLabel: destinations[i].label,
                        onTap: () => onSelected(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticNavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String semanticLabel;
  final VoidCallback onTap;

  const _StaticNavItem({
    required this.icon,
    required this.isActive,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isActive,
      label: semanticLabel,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _staticItemSize,
          height: _staticItemSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? colors.primary : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 24,
            color: isActive ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
