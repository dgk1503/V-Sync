import 'package:flutter/material.dart';

/// A capsule segmented control whose selection pill SLIDES continuously
/// with the [TabController]'s animation value.
///
/// The pill's position is driven by the raw fractional animation value, so
/// taps start moving the pill the instant they land and swipes track the
/// finger — the same fluid feel as the Material TabBar indicator.
class SegmentedTabSwitcher extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final EdgeInsetsGeometry padding;

  const SegmentedTabSwitcher({
    super.key,
    required this.controller,
    required this.labels,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // NOTE: listen to `controller.animation`, NOT the controller itself.
    // TabController only notifies its listeners twice per animateTo (at
    // animation start and completion), while the underlying
    // AnimationController notifies every frame — that per-frame value is
    // what makes the pill slide.
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final animationValue =
            controller.animation?.value ?? controller.index.toDouble();
        final selectedIndex = animationValue.round().clamp(
          0,
          labels.length - 1,
        );

        return Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = (constraints.maxWidth - 10) / labels.length;
              return Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Stack(
                  children: [
                    // Sliding selection pill, positioned by the raw
                    // animation value so it moves continuously.
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: animationValue * segmentWidth,
                      width: segmentWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => controller.animateTo(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                child: Center(
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14.5,
                                      fontWeight: selectedIndex == i
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selectedIndex == i
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
