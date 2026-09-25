import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

const double _navCapsuleRadius = 34;
const double _navSurfacePadding = 5;

/// A destination rendered by [LiquidGlassNavigationBar].
class LiquidGlassNavigationDestination {
  final IconData icon;
  final String label;

  const LiquidGlassNavigationDestination({
    required this.icon,
    required this.label,
  });
}

/// Gesture-driven, iOS-style Liquid Glass navigation surface.
///
/// A short press commits normally. Holding activates an oval lens;
/// subsequent pointer moves place that lens between measured tab centres
/// without changing the page. The destination is committed on release, then
/// a spring settles the lens around it.
class LiquidGlassNavigationBar extends StatefulWidget {
  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final FragmentProgram? shaderProgram;

  const LiquidGlassNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.shaderProgram,
  });

  @override
  State<LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with SingleTickerProviderStateMixin {
  static const double _capsuleRadius = _navCapsuleRadius;
  static const double _capsuleHeight = 68;
  static const double _surfacePadding = _navSurfacePadding;
  static const Duration _holdDelay = Duration(milliseconds: 220);

  final GlobalKey _capsuleKey = GlobalKey();
  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _tabKeys = [];
  late final AnimationController _springController;
  Timer? _holdTimer;

  FragmentShader? _fragmentShader;
  FragmentProgram? _shaderProgram;

  List<double> _centers = const [];
  List<double> _tabWidths = const [];
  double _lensX = 0;
  Size _stackSize = const Size(284, 58);
  double _pointerVelocity = 0;
  double _lastPointerX = 0;
  Duration _lastMoveAt = Duration.zero;
  bool _hasMeasured = false;
  bool _holding = false;
  int? _pressedIndex;
  int? _activePointer;
  int _targetIndex = 0;

  @override
  void initState() {
    super.initState();
    _ensureTabKeys();
    _targetIndex = widget.selectedIndex;
    _springController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() => _lensX = _springController.value);
      });
  }

  Brightness? _lastBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastBrightness != null && _lastBrightness != brightness) {
      // A theme rebuild can leave a cached runtime shader bound to the old
      // surface while a settings route is being popped. Recreate it on the
      // next build so the navbar never samples a stale backdrop.
      _fragmentShader?.dispose();
      _fragmentShader = null;
      _shaderProgram = null;
    }
    _lastBrightness = brightness;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureTabKeys();
    if (widget.selectedIndex != _targetIndex) {
      _targetIndex = widget.selectedIndex;
      if (_activePointer == null) _scheduleSpring(widget.selectedIndex);
    }
    // Re-measure after route/theme rebuilds as well as tab changes. This
    // prevents a stale lens centre from flashing when returning from a
    // pushed Account sub-page.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
  }

  void _ensureTabKeys() {
    while (_tabKeys.length < widget.destinations.length) {
      _tabKeys.add(GlobalKey());
    }
    while (_tabKeys.length > widget.destinations.length) {
      _tabKeys.removeLast();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fragmentShader?.dispose();
    _springController.dispose();
    super.dispose();
  }

  bool _sameGeometry(List<double> centers, List<double> widths) {
    if (centers.length != _centers.length ||
        widths.length != _tabWidths.length) {
      return false;
    }
    for (var i = 0; i < centers.length; i++) {
      if ((centers[i] - _centers[i]).abs() > 0.01 ||
          (widths[i] - _tabWidths[i]).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  void _measureTabs() {
    if (!mounted || widget.destinations.isEmpty) return;
    final surfaceBox = _stackKey.currentContext?.findRenderObject();
    if (surfaceBox is! RenderBox || !surfaceBox.hasSize) return;
    final centers = <double>[];
    final widths = <double>[];
    for (final key in _tabKeys) {
      final tabBox = key.currentContext?.findRenderObject();
      if (tabBox is! RenderBox || !tabBox.hasSize) return;
      final localCenter = surfaceBox.globalToLocal(
        tabBox.localToGlobal(Offset(tabBox.size.width / 2, 0)),
      );
      centers.add(localCenter.dx);
      widths.add(tabBox.size.width);
    }
    if (_sameGeometry(centers, widths) && _stackSize == surfaceBox.size) {
      return;
    }
    setState(() {
      _centers = centers;
      _tabWidths = widths;
      _stackSize = surfaceBox.size;
      _hasMeasured = true;
      if (_activePointer == null) _lensX = centers[_safeIndex(_targetIndex)];
    });
  }

  int _safeIndex(int index) => index.clamp(0, widget.destinations.length - 1);

  double _clampLensX(double localX) {
    if (_centers.isEmpty) return localX;
    return localX.clamp(_centers.first, _centers.last);
  }

  int _indexAt(double x) {
    if (_centers.isEmpty) return _safeIndex(_targetIndex);
    if (x <= _centers.first) return 0;
    if (x >= _centers.last) return _centers.length - 1;
    for (var i = 0; i < _centers.length - 1; i++) {
      if (x <= _centers[i + 1]) {
        return x - _centers[i] < _centers[i + 1] - x ? i : i + 1;
      }
    }
    return _centers.length - 1;
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.destinations.isEmpty) return;
    _holdTimer?.cancel();
    _springController.stop();
    _activePointer = event.pointer;
    _holding = false;
    _pointerVelocity = 0;
    _lastPointerX = event.localPosition.dx - _surfacePadding;
    _lastMoveAt = Duration.zero;
    _pressedIndex = _indexAt(_lastPointerX);
    HapticFeedback.selectionClick();
    setState(() {});
    _holdTimer = Timer(_holdDelay, () {
      if (!mounted || _activePointer != event.pointer) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _holding = true;
        _pressedIndex = null;
        _lensX = _clampLensX(_lastPointerX);
      });
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || !_holding) return;
    final elapsed = (event.timeStamp - _lastMoveAt).inMicroseconds;
    if (_lastMoveAt != Duration.zero && elapsed > 0) {
      final velocity =
          (event.localPosition.dx - _lastPointerX) * 1000000 / elapsed;
      _pointerVelocity = _pointerVelocity * 0.35 + velocity * 0.65;
    }
    _lastMoveAt = event.timeStamp;
    _lastPointerX = event.localPosition.dx - _surfacePadding;
    setState(() => _lensX = _clampLensX(_lastPointerX));
  }

  void _pointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    final index = _holding
        ? _indexAt(_lensX)
        : _indexAt(event.localPosition.dx - _surfacePadding);
    final releaseVelocity = _pointerVelocity;
    // The capsule listener owns real-pointer commits. The child tap
    // recognizer is retained for semantics/accessibility, but ignores this
    // pointer's duplicate release.
    if (_activePointer != null) _commit(index, velocity: releaseVelocity);
    setState(() {
      _activePointer = null;
      _holding = false;
      _pressedIndex = null;
      _pointerVelocity = 0;
    });
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    setState(() {
      _activePointer = null;
      _holding = false;
      _pressedIndex = null;
      _pointerVelocity = 0;
    });
    _scheduleSpring(_safeIndex(widget.selectedIndex));
  }

  void _commit(int index, {double velocity = 0}) {
    if (widget.destinations.isEmpty) return;
    final safeIndex = _safeIndex(index);
    _targetIndex = safeIndex;
    if (safeIndex != widget.selectedIndex) widget.onSelected(safeIndex);
    _springTo(safeIndex, velocity: velocity * 0.18);
  }

  void _scheduleSpring(int index) => _springTo(_safeIndex(index));

  void _springTo(int index, {double velocity = 0}) {
    if (!mounted || !_hasMeasured) return;
    _targetIndex = _safeIndex(index);
    _springController.stop();
    _springController.value = _lensX;
    _springController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 31),
        _lensX,
        _centers[_targetIndex],
        velocity.clamp(-2400.0, 2400.0),
      ),
    );
  }

  ImageFilter _backdropFilter(BuildContext context) {
    final program = widget.shaderProgram;
    final capsuleBox = _capsuleKey.currentContext?.findRenderObject();
    if (!ImageFilter.isShaderFilterSupported || program == null) {
      _fragmentShader?.dispose();
      _fragmentShader = null;
      _shaderProgram = null;
      return ImageFilter.blur(sigmaX: 20, sigmaY: 20);
    }
    if (capsuleBox is! RenderBox || !capsuleBox.hasSize) {
      return ImageFilter.blur(sigmaX: 20, sigmaY: 20);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final origin = capsuleBox.localToGlobal(Offset.zero) * dpr;
    final size = capsuleBox.size * dpr;
    if (_shaderProgram != program) {
      _fragmentShader?.dispose();
      _shaderProgram = program;
      _fragmentShader = program.fragmentShader();
    }
    final shader = _fragmentShader!;
    shader.setFloat(2, origin.dx);
    shader.setFloat(3, origin.dy);
    shader.setFloat(4, size.width);
    shader.setFloat(5, size.height);
    shader.setFloat(6, _capsuleRadius * dpr);
    shader.setFloat(7, 15 * dpr);
    shader.setFloat(8, 5 * dpr);
    return ImageFilter.shader(shader);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final hasShader =
        widget.shaderProgram != null && ImageFilter.isShaderFilterSupported;
    final minTabWidth = _tabWidths.isEmpty ? 64.0 : _tabWidths.reduce(math.min);
    final lensSize = _LiquidLensGeometry.resolve(
      size: _stackSize,
      tabWidth: minTabWidth,
      velocity: _holding ? _pointerVelocity : _springController.velocity,
      interacting: _holding,
    );
    final lensCenter = _LiquidLensGeometry.centerFor(
      size: _stackSize,
      centerX: _lensX,
      lensSize: lensSize,
    );

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          10 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 284),
          child: SizedBox(
            width: double.infinity,
            height: _capsuleHeight,
            child: Container(
              key: _capsuleKey,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_capsuleRadius),
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
                borderRadius: BorderRadius.circular(_capsuleRadius),
                child: BackdropFilter(
                  filter: _backdropFilter(context),
                  child: Listener(
                    key: _surfaceKey,
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _pointerDown,
                    onPointerMove: _pointerMove,
                    onPointerUp: _pointerUp,
                    onPointerCancel: _pointerCancel,
                    child: Container(
                      padding: const EdgeInsets.all(_surfacePadding),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(
                                alpha: hasShader ? 0.26 : 0.48,
                              )
                            : Colors.white.withValues(
                                alpha: hasShader ? 0.18 : 0.48,
                              ),
                        borderRadius: BorderRadius.circular(
                          _capsuleRadius - _surfacePadding,
                        ),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(
                            alpha: isDark ? 0.72 : 0.48,
                          ),
                          width: 0.7,
                        ),
                      ),
                      child: Stack(
                        key: _stackKey,
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // A local backdrop blur gives the selected
                          // lens real glass depth while it expands on a
                          // hold. The painter below adds the tint and rim.
                          if (_hasMeasured)
                            Positioned(
                              left: lensCenter.dx - lensSize.width / 2,
                              top: lensCenter.dy - lensSize.height / 2,
                              width: lensSize.width,
                              height: lensSize.height,
                              child: IgnorePointer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    _LiquidLensGeometry.radiusFor(lensSize),
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          // Draw the lens first. Keeping the icon row
                          // above it means the selected sheen can never
                          // wash over or shift a glyph.
                          if (_hasMeasured)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  key: const ValueKey('liquid-glass-lens'),
                                  painter: _LiquidLensPainter(
                                    centerX: _lensX,
                                    tabWidth: minTabWidth,
                                    velocity: _holding
                                        ? _pointerVelocity
                                        : _springController.velocity,
                                    interacting: _holding,
                                    brightness: theme.brightness,
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < widget.destinations.length;
                                  i++
                                )
                                  Expanded(
                                    key: _tabKeys[i],
                                    child: _LiquidGlassNavItem(
                                      destination: widget.destinations[i],
                                      selected: widget.selectedIndex == i,
                                      pressed: _pressedIndex == i,
                                      lensX: _centers.isEmpty ? null : _lensX,
                                      centerX: _centers.isEmpty
                                          ? null
                                          : _centers[i],
                                      threshold: _tabWidths.isEmpty
                                          ? 44
                                          : _tabWidths[i] * 0.62,
                                      interacting: _holding,
                                      onTap: _activePointer == null
                                          ? () => _commit(i)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassNavItem extends StatelessWidget {
  final LiquidGlassNavigationDestination destination;
  final bool selected;
  final bool pressed;
  final bool interacting;
  final double? lensX;
  final double? centerX;
  final double threshold;
  final VoidCallback? onTap;

  const _LiquidGlassNavItem({
    required this.destination,
    required this.selected,
    required this.pressed,
    required this.interacting,
    required this.lensX,
    required this.centerX,
    required this.threshold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final proximity = lensX == null || centerX == null
        ? 0.0
        : (1 - (lensX! - centerX!).abs() / threshold).clamp(0.0, 1.0);
    final active = selected || proximity > 0.22;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: AnimatedScale(
            scale: pressed
                ? 0.88
                : interacting && proximity > 0.35
                ? 1.06
                : 1,
            duration: Duration(milliseconds: pressed ? 90 : 220),
            curve: pressed ? Curves.easeOut : Curves.easeOutBack,
            child: Icon(
              destination.icon,
              size: 22,
              color: active ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidLensGeometry {
  static Size resolve({
    required Size size,
    required double tabWidth,
    required double velocity,
    required bool interacting,
  }) {
    // Leave one logical pixel of breathing room inside the clipped stack.
    // This keeps the held lens expandable while its corner radius stays
    // visually matched to the outer capsule's inner radius.
    final maxRadiusY = math.max(0.0, size.height / 2 - 1);
    final restingRadiusY = math.min(
      (tabWidth * 0.34).clamp(22.0, 27.0),
      maxRadiusY,
    );
    final motionLift = (velocity.abs() / 1800).clamp(0.0, 1.0) * 1.5;
    final holdHeightScale = interacting ? 1.16 : 1.0;
    final holdWidthScale = interacting ? 1.32 : 1.0;
    final velocityWidthScale =
        1.0 + (velocity.abs() / 1800).clamp(0.0, 1.0) * 0.06;
    final radiusY = math.min(
      (restingRadiusY + motionLift) * holdHeightScale,
      maxRadiusY,
    );
    final radiusX = math.min(
      radiusY * 1.32 * holdWidthScale * velocityWidthScale,
      size.width / 2,
    );
    return Size(radiusX * 2, radiusY * 2);
  }

  static double radiusFor(Size lensSize) {
    return math.min(
      lensSize.height / 2,
      _navCapsuleRadius - _navSurfacePadding,
    );
  }

  static Offset centerFor({
    required Size size,
    required double centerX,
    required Size lensSize,
  }) {
    return Offset(
      centerX.clamp(lensSize.width / 2, size.width - lensSize.width / 2),
      size.height / 2,
    );
  }
}

class _LiquidLensPainter extends CustomPainter {
  final double centerX;
  final double tabWidth;
  final double velocity;
  final bool interacting;
  final Brightness brightness;

  const _LiquidLensPainter({
    required this.centerX,
    required this.tabWidth,
    required this.velocity,
    required this.interacting,
    required this.brightness,
  });

  Path _shape(Size size) {
    final lensSize = _LiquidLensGeometry.resolve(
      size: size,
      tabWidth: tabWidth,
      velocity: velocity,
      interacting: interacting,
    );
    final center = _LiquidLensGeometry.centerFor(
      size: size,
      centerX: centerX,
      lensSize: lensSize,
    );
    final rect = Rect.fromCenter(
      center: center,
      width: lensSize.width,
      height: lensSize.height,
    );
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(_LiquidLensGeometry.radiusFor(lensSize)),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = _shape(size);
    final dark = brightness == Brightness.dark;
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: dark ? 0.3 : 0.12),
      9,
      true,
    );
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.07),
                Colors.black.withValues(alpha: 0.12),
              ]
            : [
                Colors.white.withValues(alpha: 0.62),
                Colors.white.withValues(alpha: 0.24),
                Colors.white.withValues(alpha: 0.42),
              ],
      ).createShader(path.getBounds());
    canvas.drawPath(path, fill);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.62 : 0.98),
          Colors.white.withValues(alpha: dark ? 0.16 : 0.48),
          Colors.white.withValues(alpha: dark ? 0.34 : 0.82),
        ],
      ).createShader(path.getBounds());
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(covariant _LiquidLensPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.velocity != velocity ||
        oldDelegate.interacting != interacting ||
        oldDelegate.brightness != brightness ||
        oldDelegate.tabWidth != tabWidth;
  }
}
