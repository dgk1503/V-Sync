import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// A slab of Liquid Glass for the Thumb Dock, drawn with the same fragment
/// shader (and the same tint and rim) as the navbar, so the two read as one
/// material.
///
/// It must be a direct child of the dock's `Stack`, whose origin is the screen's
/// top-left: [rect] is in screen coordinates, which is also what the shader
/// needs to find the glass on the screen.
///
/// Do not put it under an `Opacity`: a backdrop filter inside a faded layer sees
/// an empty backdrop and the glass would show nothing. Fade the panel by growing
/// it (change [rect]) instead.
///
/// With no shader (an unsupported GPU, or still loading) it falls back to a
/// plain frosted blur, exactly as the navbar does.
class DockGlass extends StatefulWidget {
  const DockGlass({
    super.key,
    required this.rect,
    required this.radius,
    required this.program,
    this.ignorePointer = false,
  });

  /// Where the glass is, in screen (logical) pixels.
  final Rect rect;
  final double radius;
  final FragmentProgram? program;

  /// Lets touches through to what lies under it.
  final bool ignorePointer;

  @override
  State<DockGlass> createState() => _DockGlassState();
}

class _DockGlassState extends State<DockGlass> {
  FragmentShader? _shader;
  FragmentProgram? _program;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  bool get _hasShader =>
      widget.program != null && ImageFilter.isShaderFilterSupported;

  ImageFilter _filter(BuildContext context, double radius) {
    final program = widget.program;
    if (!_hasShader || program == null) {
      _shader?.dispose();
      _shader = null;
      _program = null;
      return ImageFilter.blur(sigmaX: 20, sigmaY: 20);
    }
    if (_program != program) {
      _shader?.dispose();
      _program = program;
      _shader = program.fragmentShader();
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rect = widget.rect;
    final shader = _shader!;
    // Uniform layout is documented in shaders/liquid_glass.frag; index 0-1 is
    // the engine's own.
    shader.setFloat(2, rect.left * dpr);
    shader.setFloat(3, rect.top * dpr);
    shader.setFloat(4, rect.width * dpr);
    shader.setFloat(5, rect.height * dpr);
    shader.setFloat(6, radius * dpr);
    // The refracting band can't be wider than a quarter of the slab's thin side.
    shader.setFloat(
      7,
      math.min(15, math.min(rect.width, rect.height) / 4) * dpr,
    );
    shader.setFloat(8, 4 * dpr);
    return ImageFilter.shader(shader);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final rect = widget.rect;
    if (rect.width < 1 || rect.height < 1) return const SizedBox.shrink();
    final radius = math.min(
      widget.radius,
      math.min(rect.width, rect.height) / 2,
    );
    final hasShader = _hasShader;

    Widget glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.13),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: _filter(context, radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // The navbar's own tint: dark glass in dark mode, pale in light.
              color: isDark
                  ? Colors.black.withValues(alpha: hasShader ? 0.26 : 0.48)
                  : Colors.white.withValues(alpha: hasShader ? 0.18 : 0.48),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: colors.outlineVariant.withValues(
                  alpha: isDark ? 0.72 : 0.48,
                ),
                width: 0.7,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    if (widget.ignorePointer) glass = IgnorePointer(child: glass);
    return Positioned.fromRect(rect: rect, child: glass);
  }
}
