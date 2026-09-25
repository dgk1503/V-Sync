import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/app_route_transition_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/liquid_glass_navigation_bar.dart';
import 'package:vit_ap_student_app/core/providers/bottom_nav_provider.dart';
import 'package:vit_ap_student_app/core/providers/liquid_glass_provider.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/features/account/view/pages/account_page.dart';
import 'package:vit_ap_student_app/features/attendance/view/pages/academics_hub_page.dart';
import 'package:vit_ap_student_app/features/home/view/pages/home_page.dart';
import 'package:vit_ap_student_app/features/timetable/view/pages/timetable_page.dart';

const liquidGlassDestinations = <LiquidGlassNavigationDestination>[
  LiquidGlassNavigationDestination(icon: LucideIcons.house, label: 'For You'),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.calendarDays,
    label: 'Timetable',
  ),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.bookOpen,
    label: 'Academics',
  ),
  LiquidGlassNavigationDestination(
    icon: LucideIcons.userRound,
    label: 'Account',
  ),
];

class BottomNavBar extends ConsumerStatefulWidget {
  const BottomNavBar({super.key});

  @override
  BottomNavBarState createState() => BottomNavBarState();
}

class BottomNavBarState extends ConsumerState<BottomNavBar> {
  List<Widget> _buildPages() => const [
    HomePage(),
    TimetablePage(),
    AcademicsHubPage(),
    AccountPage(),
  ];

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
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(currentIndex),
                  child: _buildPages()[currentIndex],
                ),
              ),
            ),
            // Keep the navigation surface in the body layer rather than in
            // Scaffold's bottomNavigationBar slot. That makes the capsule
            // genuinely float over the content instead of appearing attached
            // to the bottom layout edge.
            const Positioned.fill(child: _FloatingCapsuleNavBar()),
          ],
        ),
      ),
    );
  }
}

class _FloatingCapsuleNavBar extends ConsumerWidget {
  const _FloatingCapsuleNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);
    final enabled = ref.watch(
      userPreferencesProvider.select((prefs) => prefs.liquidGlassNavbar),
    );
    final shader = enabled ? ref.watch(liquidGlassProgramProvider).value : null;
    return ValueListenableBuilder<bool>(
      valueListenable: AppRouteTransitionState.isActive,
      builder: (context, isRouteTransitioning, child) {
        return LiquidGlassNavigationBar(
          destinations: liquidGlassDestinations,
          selectedIndex: selectedIndex,
          shaderProgram: isRouteTransitioning ? null : shader,
          onSelected: (index) {
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
        );
      },
    );
  }
}
