import 'dart:async';

import 'package:flutter/material.dart';

/// The "V Sync" wordmark with a subtle glitch flicker.
class VSyncLogo extends StatefulWidget {
  final double fontSize;
  final String label;
  final double letterSpacing;

  const VSyncLogo({
    super.key,
    this.fontSize = 22,
    this.label = 'V Sync',
    this.letterSpacing = 1.5,
  });

  @override
  State<VSyncLogo> createState() => _VSyncLogoState();
}

class _VSyncLogoState extends State<VSyncLogo> {
  Timer? _glitchTimer;
  int _glitchFrame = 0;

  @override
  void initState() {
    super.initState();
    // Brief glitch burst every few seconds.
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return;
      final cycle = t.tick % 40;
      // Glitches on ticks 0-3 and 20-21 of every 40 (~4.8s cycle).
      if ((cycle >= 0 && cycle <= 3) || cycle == 20 || cycle == 21) {
        setState(() => _glitchFrame = cycle);
      } else if (_glitchFrame != 0) {
        setState(() => _glitchFrame = 0);
      }
    });
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    super.dispose();
  }

  Offset _offsetFor(ColorScheme colorScheme) {
    // Deterministic jitter while glitching.
    switch (_glitchFrame) {
      case 1:
        return const Offset(-1.5, 0);
      case 2:
        return const Offset(1.5, 0.5);
      case 3:
        return const Offset(-1, -0.5);
      case 20:
        return const Offset(2, 0);
      case 21:
        return const Offset(-2, 0);
      default:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glitching = _glitchFrame != 0;
    final offset = _offsetFor(colorScheme);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ghost copies, visible only while glitching.
        if (glitching) ...[
          Positioned(
            left: -offset.dx,
            child: _buildText(
              colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: _buildText(
              colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
        _buildText(colorScheme.onSurface),
      ],
    );
  }

  Widget _buildText(Color color) {
    return Text(
      widget.label,
      style: TextStyle(
        fontFamily: 'Instrument Sans',
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: widget.letterSpacing,
        color: color,
        height: 1,
      ),
    );
  }
}
