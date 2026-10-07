import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
/// A short press commits normally. Holding activates an oval lens; the lens
/// target then glides to the finger while the glass itself chases that target
/// through a critically damped spring, so the material lags, flows and settles
/// softly instead of being pinned to the finger. The destination is committed
/// on release and the same spring carries the lens into place.
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

/// Quintic smootherstep: zero velocity AND zero acceleration at both ends, so
/// the lens eases away from rest and arrives without any perceptible "kick".
double _smootherstep(double t) => t * t * t * (t * (t * 6 - 15) + 10);

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with SingleTickerProviderStateMixin {
  static const double _capsuleRadius = _navCapsuleRadius;
  static const double _capsuleHeight = 68;
  static const double _surfacePadding = _navSurfacePadding;
  static const Duration _holdDelay = Duration(milliseconds: 220);

  // ── Motion model ────────────────────────────────────────────────────────
  // One critically damped spring (zeta = 1) drives the whole material, so
  // position, deformation and size all share a single clock and settle
  // together like one physical body instead of several overlapping tweens.
  //
  // omega is the undamped natural frequency in rad/s. For a critically damped
  // system the 2% settling time is roughly 5.8/omega, which sets the feel:
  //   settle 12.5 -> ~465ms  flowing move from one page to the next
  //   drag   17.0 -> ~345ms  tracks the finger closely, but still lags
  //   size   10.0 -> ~580ms  the pill grows/shrinks at its own slower tempo
  //
  // Settle and drag were trimmed from 9.0/14.0 so page-to-page movement no
  // longer drags, while the gap between them is preserved so the glass keeps
  // its lag under the finger and still settles more softly than it moves. The
  // size spring and the hold pickup glide are deliberately untouched.
  static const double _settleOmega = 12.5;
  static const double _dragOmega = 17.0;
  static const double _sizeOmega = 10.0;
  static const double _zeta = 1.0;

  // The hold pickup: the target travels from the resting tab to the finger
  // over ~520ms on a smootherstep. The target is slow to leave and slow to
  // arrive; the spring above adds the material's own inertia on top.
  static const Duration _pickupDuration = Duration(milliseconds: 520);

  // Once the finger genuinely departs from where the pickup was headed, the
  // target tracks it directly. Small jitter is absorbed by the spring.
  static const double _pickupReleaseThreshold = 8.0;

  final GlobalKey _capsuleKey = GlobalKey();
  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _tabKeys = [];
  Ticker? _ticker;
  Timer? _holdTimer;

  FragmentShader? _fragmentShader;
  FragmentProgram? _shaderProgram;

  List<double> _centers = const [];
  List<double> _tabWidths = const [];
  Size _stackSize = const Size(284, 58);
  bool _hasMeasured = false;
  bool _holding = false;
  int? _pressedIndex;
  int? _activePointer;
  int _targetIndex = 0;

  // Lens position, velocity and the point it is chasing. The gap between
  // _lensX and _targetX is the "liquid lag" that makes the glass feel like it
  // has mass.
  double _lensX = 0;
  double _lensV = 0;
  double _targetX = 0;
  double _lastPointerX = 0;

  // Held-pill size, likewise spring driven.
  double _expansion = 0;
  double _expansionV = 0;
  double _expansionTarget = 0;

  // Pickup glide bookkeeping. Timed off the scheduler's vsync timestamp rather
  // than Ticker.elapsed: restarting a Ticker from a pointer callback (i.e.
  // between frames) can report a zero first delta, which would otherwise throw
  // away the first frame of response. The frame timestamp keeps advancing
  // across a stop/restart, so the delta is always meaningful.
  double _pickupFrom = 0;
  double _pickupTo = 0;
  int? _pickupStartMicros;
  int _lastTickMicros = 0;

  @override
  void initState() {
    super.initState();
    _ensureTabKeys();
    _targetIndex = widget.selectedIndex;
    _lastTickMicros = _nowMicros;
    _ticker = createTicker(_onTick);
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
      if (_activePointer == null && _centers.isNotEmpty) {
        // Flow to the new tab instead of jumping.
        _pickupStartMicros = null;
        _targetX = _centers[_safeIndex(_targetIndex)];
        _expansionTarget = 0;
        _ensureTicker();
      }
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
    _ticker?.dispose();
    _fragmentShader?.dispose();
    super.dispose();
  }

  // ── Motion loop ──────────────────────────────────────────────────────────

  void _ensureTicker() {
    final ticker = _ticker;
    if (ticker == null || ticker.isActive) return;
    ticker.start();
  }

  static int get _nowMicros =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;

  // Explicit integration of a damped spring goes unstable once omega*dt
  // approaches 1, so a single large catch-up step (frame drop, app resume)
  // can make the lens diverge. Integrating in fixed sub-steps no larger than a
  // 120Hz frame keeps it stable for any dt while staying allocation free.
  static const double _maxSubStep = 1 / 120;

  void _onTick(Duration elapsed) {
    final micros = _nowMicros;
    var dt = (micros - _lastTickMicros) / 1000000.0;
    _lastTickMicros = micros;
    // A duplicate frame carries no new time; a long stall is clamped so the
    // spring catches up smoothly instead of exploding.
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    // 1. Advance the pickup glide on the *target*.
    final pickupStart = _pickupStartMicros;
    if (pickupStart != null) {
      final t = (micros - pickupStart) / _pickupDuration.inMicroseconds;
      if (t >= 1.0) {
        _targetX = _pickupTo;
        _pickupStartMicros = null;
      } else {
        _targetX = _pickupFrom + (_pickupTo - _pickupFrom) * _smootherstep(t);
      }
    }

    // 2. Critically damped followers for position and held-pill size, stepped
    //    in fixed sub-steps for unconditional numerical stability.
    final omega = _holding ? _dragOmega : _settleOmega;
    final kPos = omega * omega;
    final cPos = 2 * _zeta * omega;
    final kSize = _sizeOmega * _sizeOmega;
    final cSize = 2 * _zeta * _sizeOmega;
    var remaining = dt;
    while (remaining > 0) {
      final h = remaining > _maxSubStep ? _maxSubStep : remaining;
      _lensV += (-kPos * (_lensX - _targetX) - cPos * _lensV) * h;
      _lensX += _lensV * h;
      _expansionV +=
          (-kSize * (_expansion - _expansionTarget) - cSize * _expansionV) * h;
      _expansion += _expansionV * h;
      remaining -= h;
    }

    // 4. Rest only once everything has genuinely come to rest.
    final positionSettled =
        (_targetX - _lensX).abs() < 0.05 && _lensV.abs() < 0.5;
    final sizeSettled =
        (_expansionTarget - _expansion).abs() < 0.0005 && _expansionV.abs() < 0.005;
    if (positionSettled && sizeSettled && _pickupStartMicros == null) {      _lensX = _targetX;
      _lensV = 0;
      _expansion = _expansionTarget;
      _expansionV = 0;
      _ticker?.stop();
      setState(() {});
      return;
    }

    setState(() {});
  }


  void _beginPickup(double to) {
    _pickupFrom = _targetX;
    _pickupTo = to;
    _pickupStartMicros = _nowMicros;
    _ensureTicker();
  }

  // ── Geometry ─────────────────────────────────────────────────────────────

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
    final firstMeasurement = !_hasMeasured;
    setState(() {
      _centers = centers;
      _tabWidths = widths;
      _stackSize = surfaceBox.size;
      _hasMeasured = true;
      if (firstMeasurement || _activePointer == null) {
        final centre = centers[_safeIndex(_targetIndex)];
        _targetX = centre;
        if (firstMeasurement) {
          // Snap on the very first layout so the bar does not fly in.
          _lensX = centre;
          _lensV = 0;
          _expansion = 0;
          _expansionV = 0;
          _pickupStartMicros = null;
        } else {
          _ensureTicker();
        }
      }
    });
  }

  int _safeIndex(int index) => index.clamp(0, widget.destinations.length - 1);

  double _clampTargetX(double localX) {
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

  // ── Gesture ──────────────────────────────────────────────────────────────

  void _pointerDown(PointerDownEvent event) {
    if (widget.destinations.isEmpty) return;
    _holdTimer?.cancel();
    _activePointer = event.pointer;
    _holding = false;
    _lastPointerX = event.localPosition.dx - _surfacePadding;
    _pressedIndex = _indexAt(_lastPointerX);
    HapticFeedback.selectionClick();
    setState(() {});
    _holdTimer = Timer(_holdDelay, () {
      if (!mounted || _activePointer != event.pointer) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _holding = true;
        _pressedIndex = null;
      });
      // Glide the target to the finger; the spring turns that into mass.
      _beginPickup(_clampTargetX(_lastPointerX));
      _expansionTarget = 1.0;
      _ensureTicker();
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || !_holding) return;
    final target = _clampTargetX(event.localPosition.dx - _surfacePadding);
    _lastPointerX = event.localPosition.dx - _surfacePadding;
    // While the pickup glide is running the finger already sits where the
    // target is heading, so only a real departure hands control over.
    final pickup = _pickupStartMicros;
    if (pickup != null && (target - _pickupTo).abs() <= _pickupReleaseThreshold) {
      return;
    }
    _pickupStartMicros = null;
    _targetX = target;
    _ensureTicker();
  }

  void _pointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    // Commit to the tab the finger chose. If the pickup glide is still in
    // flight the finger has not moved yet, so its destination is the intent.
    final commitX = _holding
        ? (_pickupStartMicros != null ? _pickupTo : _targetX)
        : event.localPosition.dx - _surfacePadding;
    final index = _indexAt(commitX);
    _pickupStartMicros = null;
    // The capsule listener owns real-pointer commits. The child tap
    // recognizer is retained for semantics/accessibility, but ignores this
    // pointer's duplicate release.
    if (_activePointer != null) _commit(index);
    setState(() {
      _activePointer = null;
      _holding = false;
      _pressedIndex = null;
    });
  }

  void _pointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    _pickupStartMicros = null;
    setState(() {
      _activePointer = null;
      _holding = false;
      _pressedIndex = null;
    });
    if (_centers.isNotEmpty) {
      _targetX = _centers[_safeIndex(widget.selectedIndex)];
    }
    _expansionTarget = 0;
    _ensureTicker();
  }

  void _commit(int index) {
    if (widget.destinations.isEmpty) return;
    final safeIndex = _safeIndex(index);
    _targetIndex = safeIndex;
    if (_centers.isNotEmpty) _targetX = _centers[safeIndex];
    _expansionTarget = 0;
    _ensureTicker();
    if (safeIndex != widget.selectedIndex) widget.onSelected(safeIndex);
  }

  // ── Shader ───────────────────────────────────────────────────────────────

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
    // Disk radius for the frosted rim. Smaller than before because the disk is
    // now filled with 20 taps instead of 8 on a single ring, so the same
    // visual frost needs a tighter radius to stay smooth over glyphs.
    shader.setFloat(8, 4 * dpr);
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
    // The lens deforms from its OWN velocity, so the stretch is continuous
    // and decays as the material comes to rest.
    final lensSize = _LiquidLensGeometry.resolve(
      size: _stackSize,
      tabWidth: minTabWidth,
      velocity: _lensV,
      expansion: _expansion,
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
          // The keyboard does not move this bar: the shell
          // (`bottom_navigation_bar.dart`) extends the nav layer below the
          // keyboard-resized body by the IME inset, pinning the capsule to the
          // physical screen bottom. The inset cannot be read in here —
          // `Scaffold` strips the bottom viewInset from the body's MediaQuery
          // — and adding it to this padding would push the capsule UP, so the
          // compensation belongs to the shell, not to this file.
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
                                    velocity: _lensV,
                                    expansion: _expansion,
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
            // Softer and slower than the default snap: a gentle ease-out with
            // no overshoot, so the glyph settles rather than bouncing.
            duration: Duration(milliseconds: pressed ? 120 : 380),
            curve: pressed ? Curves.easeOut : Curves.easeOutCubic,
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
    required double expansion,
  }) {
    // Leave one logical pixel of breathing room inside the clipped stack.
    // This keeps the held lens expandable while its corner radius stays
    // visually matched to the outer capsule's inner radius.
    final maxRadiusY = math.max(0.0, size.height / 2 - 1);
    final restingRadiusY = math.min(
      (tabWidth * 0.34).clamp(22.0, 27.0),
      maxRadiusY,
    );
    // Normalised against the smoothed lens velocity rather than raw pointer
    // speed, so the glass stretches into a movement and relaxes out of it.
    final speed = (velocity.abs() / 900).clamp(0.0, 1.0);
    final motionLift = speed * 1.8;
    // The held pill eases between its resting and expanded size as the size
    // spring runs, instead of snapping between the two scales.
    final holdHeightScale = 1.0 + 0.16 * expansion;
    final holdWidthScale = 1.0 + 0.32 * expansion;
    final velocityWidthScale = 1.0 + speed * 0.10;
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
  final double expansion;
  final Brightness brightness;

  const _LiquidLensPainter({
    required this.centerX,
    required this.tabWidth,
    required this.velocity,
    required this.expansion,
    required this.brightness,
  });

  Path _shape(Size size) {
    final lensSize = _LiquidLensGeometry.resolve(
      size: size,
      tabWidth: tabWidth,
      velocity: velocity,
      expansion: expansion,
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
        oldDelegate.expansion != expansion ||
        oldDelegate.brightness != brightness ||
        oldDelegate.tabWidth != tabWidth;
  }
}
