import 'package:flutter/material.dart';

/// Tracks whether a Material page route is currently animating.
///
/// The liquid-glass shader samples the backdrop texture. During a route
/// transition that texture can contain the outgoing route snapshot, which
/// creates a white curved artifact inside the navbar. Consumers can briefly
/// use a normal blur while this value is active, then restore the shader.
class AppRouteTransitionState {
  AppRouteTransitionState._();

  static final ValueNotifier<bool> isActive = ValueNotifier<bool>(false);
  static int _activeTransitions = 0;

  static void begin() {
    _activeTransitions++;
    if (_activeTransitions == 1 && !isActive.value) isActive.value = true;
  }

  static void end() {
    if (_activeTransitions == 0) return;
    _activeTransitions--;
    if (_activeTransitions == 0 && isActive.value) isActive.value = false;
  }
}

class RouteTransitionTracker extends StatefulWidget {
  const RouteTransitionTracker({
    super.key,
    required this.route,
    required this.child,
  });

  final PageRoute<dynamic>? route;
  final Widget child;

  @override
  State<RouteTransitionTracker> createState() => _RouteTransitionTrackerState();
}

class _RouteTransitionTrackerState extends State<RouteTransitionTracker> {
  Animation<double>? _animation;
  AnimationStatusListener? _statusListener;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.route);
  }

  @override
  void didUpdateWidget(covariant RouteTransitionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _detach();
      _attach(widget.route);
    }
  }

  void _attach(PageRoute<dynamic>? route) {
    final animation = route?.animation;
    if (animation == null) return;
    _animation = animation;
    _statusListener = (status) => _sync(status);
    animation.addStatusListener(_statusListener!);
    _sync(animation.status);
  }

  void _sync(AnimationStatus status) {
    final shouldTrack =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (shouldTrack && !_tracking) {
      _tracking = true;
      AppRouteTransitionState.begin();
    } else if (!shouldTrack && _tracking) {
      _tracking = false;
      AppRouteTransitionState.end();
    }
  }

  void _detach() {
    final listener = _statusListener;
    final animation = _animation;
    if (listener != null && animation != null) {
      animation.removeStatusListener(listener);
    }
    if (_tracking) {
      _tracking = false;
      AppRouteTransitionState.end();
    }
    _statusListener = null;
    _animation = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
