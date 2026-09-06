import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/mess/mess_menu_section.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/milestones/milestones_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        // bottom: false lets content scroll underneath the floating capsule
        // nav bar; the scroll padding below keeps the last section clear of
        // it when fully scrolled.
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MilestonesSection(),
              // Fading hairline separating the countdowns from the mess menu.
              Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.outlineVariant.withValues(alpha: 0),
                      colorScheme.outlineVariant,
                      colorScheme.outlineVariant,
                      colorScheme.outlineVariant.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              const MessMenuSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
