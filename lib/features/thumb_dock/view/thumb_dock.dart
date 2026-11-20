import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_layout.dart';
import 'package:vit_ap_student_app/features/thumb_dock/model/dock_shortcut.dart';
import 'package:vit_ap_student_app/features/thumb_dock/view/dock_glass.dart';

/// One of the fixed destinations in the dock's main column.
class _Main {
  const _Main(this.id, this.label, this.icon, [this.tab]);
  final String id;
  final String label;
  final IconData icon;

  /// Index in the bottom navigation, for the four tabs.
  final int? tab;
}

const _otp = _Main('otp', 'Enter OTP', LucideIcons.keyRound);
const _home = _Main('home', 'For You', LucideIcons.house, 0);
const _timetable = _Main('timetable', 'Timetable', LucideIcons.calendarDays, 1);
const _academics = _Main('academics', 'Academics', LucideIcons.bookOpen, 2);
// The same glyph and name as the navbar's last tab.
const _settings = _Main('account', 'Account', LucideIcons.userRound, 3);

/// The dock's own mark, on its resting handle.
const IconData _dockMark = LucideIcons.layoutGrid;

/// The Thumb Dock: a handle on one edge of the screen that fans out into the
/// app's main pages, so the thumb never has to travel to the navbar.
///
/// Three ways to use it:
///  * **Hold and slide.** Press the handle, keep the finger down and slide onto
///    a page; let go to open it. Sliding onto Academics unfolds its shortcuts
///    sideways, and the finger carries on across to one of them.
///  * **Tap.** A tap opens the same menu and leaves it open, so each choice is a
///    plain tap. Tapping Academics goes there and keeps the shortcuts showing.
///  * **Drag.** Pulling the handle itself moves it; it settles on the nearer
///    side at the height it was left.
///
/// It only draws and reports: where a tap leads is up to the host (see
/// `ThumbDockHost`).
class ThumbDock extends StatefulWidget {
  const ThumbDock({
    super.key,
    required this.rightSide,
    required this.yFraction,
    required this.shortcuts,
    required this.otpPending,
    this.otpLabel,
    this.glass = false,
    this.glassProgram,
    required this.onTab,
    required this.onShortcut,
    required this.onOtp,
    required this.onMoved,
  });

  final bool rightSide;

  /// Handle height, 0 (top) to 1 (bottom) of the usable screen height.
  final double yFraction;
  final List<DockShortcut> shortcuts;

  /// An OTP prompt is waiting, so the menu gains a key that opens it.
  final bool otpPending;

  /// The OTP countdown ("02:41"), shown on the handle while a code is waiting.
  /// A plain tap on the handle then goes straight to the OTP prompt instead of
  /// opening the menu (hold still opens the menu).
  final String? otpLabel;

  /// Draw the handle and panels as Liquid Glass (the navbar's material). Off
  /// for plain solid panels, which are much lighter on a slow phone.
  final bool glass;

  /// The shader behind the glass; null falls back to a frosted blur.
  final ui.FragmentProgram? glassProgram;
  final ValueChanged<int> onTab;
  final ValueChanged<DockShortcut> onShortcut;
  final VoidCallback onOtp;
  final void Function(bool rightSide, double yFraction) onMoved;

  @override
  State<ThumbDock> createState() => _ThumbDockState();
}

class _ThumbDockState extends State<ThumbDock>
    with SingleTickerProviderStateMixin {
  static const _holdDelay = Duration(milliseconds: 260);
  static const _slop = 10.0;
  static const _stripWidth = 40.0;
  static const _stripHeight = 84.0;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  bool _open = false;
  bool _expanded = false;

  /// The menu was opened by holding, so the finger that is still down is the one
  /// choosing; releasing it picks what it is over.
  bool _holdGesture = false;
  DockHit? _hover;

  Timer? _holdTimer;
  Offset _down = Offset.zero;
  bool _moved = false;
  int? _handlePointer;

  /// Where the handle is while it is being pulled, null otherwise.
  Offset? _drag;

  DockLayout? _layout;

  List<_Main> get _mains => [
    if (widget.otpPending) _otp,
    _home,
    _timetable,
    _academics,
    _settings,
  ];

  int get _academicsIndex => widget.otpPending ? 3 : 2;

  double get _tabWidth => widget.otpPending ? 42 : 36;
  double get _tabHeight => widget.otpPending ? 58 : 54;

  @override
  void initState() {
    super.initState();
    // The menu is drawn until its closing animation has finished, so the tree
    // has to be rebuilt the moment that happens.
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  // --- opening and closing ---------------------------------------------------

  void _openByHold() {
    if (_open || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _open = true;
      _holdGesture = true;
      _expanded = false;
      _hover = null;
    });
    _anim.forward();
  }

  void _openSticky() {
    if (_open) return;
    HapticFeedback.lightImpact();
    setState(() {
      _open = true;
      _holdGesture = false;
      _expanded = false;
      _hover = null;
    });
    _anim.forward();
  }

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _holdGesture = false;
      _expanded = false;
      _hover = null;
    });
    _anim.reverse();
  }

  // --- choosing --------------------------------------------------------------

  void _updateHover(Offset p) {
    final layout = _layout;
    if (layout == null) return;
    final hit = layout.hit(p, subsOpen: _expanded);
    var expanded = _expanded;
    if (hit != null && !hit.isSub) {
      expanded = hit.index == _academicsIndex && widget.shortcuts.isNotEmpty;
    }
    if (hit != _hover || expanded != _expanded) {
      if (hit != _hover && hit != null) HapticFeedback.selectionClick();
      setState(() {
        _hover = hit;
        _expanded = expanded;
      });
    }
  }

  void _choose(DockHit hit, {required bool sticky}) {
    if (hit.isSub) {
      final shortcut = widget.shortcuts[hit.index];
      _close();
      widget.onShortcut(shortcut);
      return;
    }
    final item = _mains[hit.index];
    if (item.id == 'otp') {
      _close();
      widget.onOtp();
    } else if (item.id == 'academics') {
      widget.onTab(2);
      // Tapping (rather than sliding) means the next move is a tap too, so the
      // shortcuts stay up for it.
      if (sticky && widget.shortcuts.isNotEmpty) {
        setState(() {
          _expanded = true;
          _hover = null;
          _holdGesture = false;
        });
      } else {
        _close();
      }
    } else {
      _close();
      widget.onTab(item.tab!);
    }
  }

  // --- the handle ------------------------------------------------------------

  void _handleDown(PointerDownEvent e) {
    if (_open || _handlePointer != null) return;
    _handlePointer = e.pointer;
    _down = e.position;
    _moved = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDelay, _openByHold);
  }

  void _handleMove(PointerMoveEvent e) {
    if (e.pointer != _handlePointer) return;
    if (_open && _holdGesture) {
      _updateHover(e.position);
      return;
    }
    if (_open) return;
    if (!_moved && (e.position - _down).distance > _slop) {
      _moved = true;
      _holdTimer?.cancel();
    }
    if (_moved) setState(() => _drag = e.position);
  }

  void _handleUp(PointerUpEvent e) {
    if (e.pointer != _handlePointer) return;
    _handlePointer = null;
    _holdTimer?.cancel();

    if (_open && _holdGesture) {
      final hit = _hover ?? _layout?.hit(e.position, subsOpen: _expanded);
      if (hit != null) {
        _choose(hit, sticky: false);
      } else if ((e.position - _down).distance > 14) {
        _close();
      } else {
        // Held without moving: leave the menu open for a tap.
        setState(() => _holdGesture = false);
      }
      return;
    }

    if (_drag != null) {
      _commitDrag(e.position);
    } else if (!_open && !_moved) {
      if (widget.otpPending) {
        HapticFeedback.lightImpact();
        widget.onOtp();
      } else {
        _openSticky();
      }
    }
  }

  void _handleCancel(PointerCancelEvent e) {
    if (e.pointer != _handlePointer) return;
    _handlePointer = null;
    _holdTimer?.cancel();
    if (_open && _holdGesture) _close();
    if (_drag != null) setState(() => _drag = null);
  }

  void _commitDrag(Offset p) {
    final size = context.size ?? Size.zero;
    final pad = MediaQuery.paddingOf(context);
    final top = pad.top + 24;
    final usable = size.height - pad.top - pad.bottom - 48;
    setState(() => _drag = null);
    if (usable <= 0) return;
    widget.onMoved(
      p.dx > size.width / 2,
      ((p.dy - top) / usable).clamp(0.0, 1.0),
    );
  }

  // --- the open menu ---------------------------------------------------------

  void _scrimDown(PointerDownEvent e) => _updateHover(e.position);

  void _scrimMove(PointerMoveEvent e) => _updateHover(e.position);

  void _scrimUp(PointerUpEvent e) {
    final layout = _layout;
    final hit = _hover ?? layout?.hit(e.position, subsOpen: _expanded);
    if (hit != null) {
      _choose(hit, sticky: true);
    } else {
      _close();
    }
  }

  // --- drawing ---------------------------------------------------------------

  /// The resting handle: a small tab fixed to the screen edge, carrying the
  /// dock's mark, so it reads as something to touch rather than a stray line.
  Widget _tab(ColorScheme colorScheme) {
    const radius = Radius.circular(27);
    return Container(
      width: _tabWidth,
      height: _tabHeight,
      alignment: widget.rightSide
          ? const Alignment(-0.15, 0)
          : const Alignment(0.15, 0),
      decoration: widget.glass
          ? null
          : BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
              borderRadius: widget.rightSide
                  ? const BorderRadius.horizontal(left: radius)
                  : const BorderRadius.horizontal(right: radius),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.14),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: widget.otpPending
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.keyRound,
                  size: 17,
                  color: colorScheme.onSurface,
                ),
                if (widget.otpLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.otpLabel!,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            )
          : Icon(
              _dockMark,
              size: 19,
              color: colorScheme.onSurface.withValues(alpha: 0.88),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final pad = MediaQuery.paddingOf(context);
        final top = pad.top + 24;
        final usable = (size.height - pad.top - pad.bottom - 48).clamp(
          1.0,
          double.infinity,
        );
        final handleY = top + widget.yFraction.clamp(0.0, 1.0) * usable;

        final subs = widget.shortcuts.length.clamp(0, DockLayout.maxSubs);
        final layout = DockLayout(
          size: size,
          padding: pad,
          rightSide: widget.rightSide,
          handleY: handleY,
          mainCount: _mains.length,
          academicsIndex: _academicsIndex,
          subCount: subs,
        );
        _layout = layout;

        final showMenu = _open || _anim.status != AnimationStatus.dismissed;
        final handleOrigin = Offset(
          widget.rightSide ? size.width - 18 : 18,
          handleY,
        );

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The glass under the handle. It reaches past the screen edge so
              // only its inner end shows, rounded.
              if (widget.glass && !_open && _drag == null)
                DockGlass(
                  rect: widget.rightSide
                      ? Rect.fromLTWH(
                          size.width - _tabWidth,
                          handleY - _tabHeight / 2,
                          _tabWidth + 30,
                          _tabHeight,
                        )
                      : Rect.fromLTWH(
                          -30,
                          handleY - _tabHeight / 2,
                          _tabWidth + 30,
                          _tabHeight,
                        ),
                  radius: _tabHeight / 2,
                  program: widget.glassProgram,
                  ignorePointer: true,
                ),
              // The handle. It stays mounted while the menu is open: a hold
              // gesture's finger is still down on it, and its events must keep
              // arriving.
              Positioned(
                top: handleY - _stripHeight / 2,
                width: _stripWidth,
                height: _stripHeight,
                left: widget.rightSide ? null : 0,
                right: widget.rightSide ? 0 : null,
                child: Semantics(
                  button: true,
                  label: 'Quick menu',
                  onTap: widget.otpPending ? widget.onOtp : _openSticky,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handleDown,
                    onPointerMove: _handleMove,
                    onPointerUp: _handleUp,
                    onPointerCancel: _handleCancel,
                    child: Align(
                      alignment: widget.rightSide
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: (_open || _drag != null) ? 0 : 1,
                        child: _tab(colorScheme),
                      ),
                    ),
                  ),
                ),
              ),

              if (_drag != null)
                Positioned(
                  left: _drag!.dx - 26,
                  top: _drag!.dy - 26,
                  child: IgnorePointer(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _dockMark,
                        size: 22,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

              if (showMenu) ...[
                // Catches the pointers that start while the menu is open (the
                // tap style). The page behind it is dimmed, so the menu reads
                // as an overlay on top of the app.
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _open ? _scrimDown : null,
                    onPointerMove: _open ? _scrimMove : null,
                    onPointerUp: _open ? _scrimUp : null,
                    child: AnimatedBuilder(
                      animation: _anim,
                      // Dimmed only, never blurred: a full-screen blur is
                      // the costliest thing here on a slow phone, and the
                      // glass wants a sharp page behind it to refract.
                      builder: (context, _) => ColoredBox(
                        color: colorScheme.scrim.withValues(
                          alpha: (widget.glass ? 0.3 : 0.45) * _anim.value,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) =>
                          _menu(context, layout, handleOrigin, colorScheme),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _menu(
    BuildContext context,
    DockLayout layout,
    Offset handleOrigin,
    ColorScheme colorScheme,
  ) {
    final t = Curves.easeOutCubic.transform(_anim.value);
    final mains = _mains;
    final hover = _hover;
    final inward = widget.rightSide ? -1.0 : 1.0;

    String? label;
    if (hover != null) {
      label = hover.isSub
          ? widget.shortcuts[hover.index].label
          : mains[hover.index].label;
    }

    // One monochrome language for the whole overlay: panels in the card
    // surface, glyphs in the text colour, and the item under the finger
    // inverted. Nothing here borrows the accent.
    BoxDecoration panel(double radius) => BoxDecoration(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colorScheme.onSurface.withValues(alpha: 0.1),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );

    Widget bubble(IconData icon, double size, bool hovered) => AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: hovered ? 1.1 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hovered ? colorScheme.onSurface : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: size * 0.46,
          color: hovered ? colorScheme.surface : colorScheme.onSurface,
        ),
      ),
    );

    final children = <Widget>[];

    // The shortcut row's panel goes first so the main panel overlaps its root.
    if (_expanded && _open && layout.subCount > 0) {
      final rowY = layout.mainCenter(_academicsIndex).dy;
      final x0 = layout.columnX;
      final x1 = layout.subCenter(layout.subCount - 1).dx + inward * 32;
      children.add(
        TweenAnimationBuilder<double>(
          key: const ValueKey('sub-panel'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            // Grows out of the Academics item rather than fading in.
            final xe = x0 + (x1 - x0) * v;
            final rect = Rect.fromLTRB(
              x0 < xe ? x0 : xe,
              rowY - 30,
              x0 < xe ? xe : x0,
              rowY + 30,
            );
            if (widget.glass) {
              return DockGlass(
                rect: rect,
                radius: 30,
                program: widget.glassProgram,
                ignorePointer: true,
              );
            }
            return Positioned.fromRect(
              rect: rect,
              child: Opacity(
                opacity: v,
                child: DecoratedBox(decoration: panel(30)),
              ),
            );
          },
        ),
      );
    }

    final mainRect = Rect.fromLTWH(
      layout.columnX - 36,
      layout.columnTop - 12,
      72,
      layout.columnHeight + 24,
    );
    if (widget.glass) {
      // Grows out of the handle.
      final from = Rect.fromCenter(
        center: handleOrigin,
        width: _tabWidth,
        height: _tabHeight,
      );
      children.add(
        DockGlass(
          rect: Rect.lerp(from, mainRect, t)!,
          radius: 36,
          program: widget.glassProgram,
          ignorePointer: true,
        ),
      );
    } else {
      children.add(
        Positioned.fromRect(
          rect: mainRect,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              alignment: widget.rightSide
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: DecoratedBox(decoration: panel(36)),
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < mains.length; i++) {
      final c = Offset.lerp(handleOrigin, layout.mainCenter(i), t)!;
      children.add(
        Positioned(
          left: c.dx - DockLayout.itemSize / 2,
          top: c.dy - DockLayout.itemSize / 2,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: bubble(
              mains[i].icon,
              DockLayout.itemSize,
              hover == DockHit.main(i),
            ),
          ),
        ),
      );
    }

    if (_expanded && _open) {
      final from = layout.mainCenter(_academicsIndex);
      for (var j = 0; j < layout.subCount; j++) {
        children.add(
          TweenAnimationBuilder<double>(
            key: ValueKey('sub-${widget.shortcuts[j].id}'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 150 + j * 35),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final c = Offset.lerp(from, layout.subCenter(j), v)!;
              return Positioned(
                left: c.dx - DockLayout.subSize / 2,
                top: c.dy - DockLayout.subSize / 2,
                child: Opacity(
                  opacity: v,
                  child: bubble(
                    widget.shortcuts[j].icon,
                    DockLayout.subSize,
                    hover == DockHit.sub(j),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    if (label != null) {
      final pad = MediaQuery.paddingOf(context);
      children.add(
        Positioned(
          top: (layout.columnTop - 52).clamp(pad.top + 8, double.infinity),
          left: widget.rightSide ? null : 16,
          right: widget.rightSide ? 16 : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: panel(22),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }
}
