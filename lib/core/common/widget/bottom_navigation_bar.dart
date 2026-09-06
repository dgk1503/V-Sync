import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/providers/bottom_nav_provider.dart';
import 'package:vit_ap_student_app/core/providers/liquid_glass_provider.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/account/view/pages/account_page.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/academics_hub_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/home_page.dart';
import 'package:vit_ap_student_app/features/timetable/view/pages/timetable_page.dart';

class BottomNavBar extends ConsumerStatefulWidget {
  const BottomNavBar({super.key});

  @override
  BottomNavBarState createState() => BottomNavBarState();
}

class BottomNavBarState extends ConsumerState<BottomNavBar> {
  List<Widget> _buildPages() {
    return const [
      HomePage(),
      TimetablePage(),
      AcademicsHubPage(),
      AccountPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentIndex != 0) {
          ref.read(bottomNavIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(currentIndex),
            child: _buildPages()[currentIndex],
          ),
        ),
        // The Scaffold hands this slot the full screen width and loose,
        // screen-sized height constraints. Align with heightFactor: 1
        // shrink-wraps the slot to the capsule's real height instead of
        // letting it expand, and pins it to the bottom.
        bottomNavigationBar: const _FloatingCapsuleNavBar(),
      ),
    );
  }
}

class _FloatingCapsuleNavBar extends ConsumerStatefulWidget {
  const _FloatingCapsuleNavBar();

  @override
  _FloatingCapsuleNavBarState createState() => _FloatingCapsuleNavBarState();
}

class _FloatingCapsuleNavBarState extends ConsumerState<_FloatingCapsuleNavBar> {
  final GlobalKey _capsuleKey = GlobalKey();

  // The Liquid Glass shader needs the capsule's real bounds AND position in
  // screen pixels (physical): the engine's BackdropFilter texture covers the
  // whole screen, so the shader locates the capsule via uniforms. Defaults
  // are only placeholders until the first post-layout measurement lands.
  Offset _capsuleOrigin = Offset.zero;
  Size _capsuleSize = const Size(274, 74);

  void _measureCapsule() {
    final context = _capsuleKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final origin = box.localToGlobal(Offset.zero) * dpr;
    final size = box.size * dpr;
    if (origin != _capsuleOrigin || size != _capsuleSize) {
      setState(() {
        _capsuleOrigin = origin;
        _capsuleSize = size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Liquid Glass is opt-in (Settings > Customization) and only renders
    // when the shader loads on an Impeller backend; otherwise the navbar
    // falls back to the classic frosted blur.
    final liquidGlassEnabled = ref.watch(
      userPreferencesProvider.select((prefs) => prefs.liquidGlassNavbar),
    );
    // .value is null while loading or on error (Riverpod 3 semantics).
    final shaderProgram =
        liquidGlassEnabled ? ref.watch(liquidGlassProgramProvider).value : null;
    final glassActive =
        shaderProgram != null && ImageFilter.isShaderFilterSupported;

    // Measure after layout so the shader gets the real capsule bounds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureCapsule());

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 24, right: 24),
          child: Container(
            key: _capsuleKey,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              // Blurs whatever scrolls behind the capsule.
              child: BackdropFilter(
                // IMPORTANT: the engine owns uniform indices 0-1 (it stamps
                // the backdrop texture size there) and FlutterFragCoord()
                // is in SCREEN physical pixels — so the shader is told where
                // the capsule sits on screen. All lengths are physical px.
                // The Y-flip is handled INSIDE the shader with
                // #ifdef IMPELLER_TARGET_OPENGLES (the shader ships as raw
                // GLSL and is compiled on-device per backend): GLES needs
                // the inversion, Vulkan does not. Never hard-code the flip
                // per platform — this device runs GLES while many Play
                // testers' devices run Vulkan.
                filter: glassActive
                    ? ImageFilter.shader(
                        () {
                          final dpr =
                              MediaQuery.devicePixelRatioOf(context);
                          final shader = shaderProgram.fragmentShader();
                          // 0-1: engine-owned backdrop texture size.
                          shader.setFloat(2, _capsuleOrigin.dx);
                          shader.setFloat(3, _capsuleOrigin.dy);
                          shader.setFloat(4, _capsuleSize.width);
                          shader.setFloat(5, _capsuleSize.height);
                          shader.setFloat(6, 34.0 * dpr); // corner radius
                          shader.setFloat(7, 14.0 * dpr); // refraction band
                          shader.setFloat(8, 3.0 * dpr); // blur (see-through)
                          return shader;
                        }(),
                      )
                    : ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    // A thinner fill than the frosted look so the glass
                    // refraction stays visible through the capsule.
                    color: isDark
                        ? Colors.black
                            .withValues(alpha: glassActive ? 0.35 : 0.5)
                        : Colors.white
                            .withValues(alpha: glassActive ? 0.35 : 0.6),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavItem(
                        icon: Iconsax.home,
                        isActive: currentIndex == 0,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .state = 0,
                      ),
                      const SizedBox(width: 12),
                      _NavItem(
                        icon: Iconsax.calendar,
                        isActive: currentIndex == 1,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .state = 1,
                      ),
                      const SizedBox(width: 12),
                      _NavItem(
                        icon: Iconsax.document,
                        isActive: currentIndex == 2,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .state = 2,
                      ),
                      const SizedBox(width: 12),
                      _NavItem(
                        icon: Iconsax.setting_2,
                        isActive: currentIndex == 3,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .state = 3,
                      ),
                    ],
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? colorScheme.primary : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
