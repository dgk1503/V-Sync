import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/features/home/view/pages/milestone_manage_page.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/milestones/milestone_card.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/milestones_viewmodel.dart';

class MilestonesSection extends ConsumerStatefulWidget {
  const MilestonesSection({super.key});

  @override
  ConsumerState<MilestonesSection> createState() => _MilestonesSectionState();
}

class _MilestonesSectionState extends ConsumerState<MilestonesSection> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  Timer? _refreshTimer;
  bool _userInteracting = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    // Rebuild every minute so the remaining days/hours stay accurate,
    // and clean up countdowns that finished more than 10 minutes ago.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      ref.read(milestonesProvider.notifier).removeExpired();
      setState(() {});
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _userInteracting || !_pageController.hasClients) return;

      final milestones = ref.read(milestonesProvider);
      if (milestones.length <= 1) return;

      final current = _pageController.page ?? 0;
      final next = (current.round() + 1) % milestones.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _openManagePage() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (builder) => const MilestoneManagePage(),
      ),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestones = ref.watch(milestonesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Keep the page index valid when milestones are deleted.
    if (_currentPage >= milestones.length) {
      _currentPage = milestones.isEmpty ? 0 : milestones.length - 1;
      if (_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentPage);
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
          child: Row(
            children: [
              AccentGradientText(
                'Countdowns',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 22,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openManagePage,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  'Manage',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (milestones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _EmptyHint(onTap: _openManagePage),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _userInteracting = true;
                } else if (notification is ScrollEndNotification) {
                  _userInteracting = false;
                } else if (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) {
                  _userInteracting = true;
                }
                return false;
              },
              child: SizedBox(
                height: 185,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: milestones.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) =>
                      MilestoneCard(milestone: milestones[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < milestones.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: _currentPage == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.add_circle_copy,
              size: 26,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Track your first countdown',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
