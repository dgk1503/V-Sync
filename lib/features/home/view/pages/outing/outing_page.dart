import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/segmented_tab_switcher.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/general_outing_tab.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/weekend_outing_tab.dart';

class OutingPage extends ConsumerStatefulWidget {
  const OutingPage({super.key});

  @override
  ConsumerState<OutingPage> createState() => _OutingPageState();
}

class _OutingPageState extends ConsumerState<OutingPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const AccentGradientText(
          'Outing',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedTabSwitcher(
            controller: _tabController,
            labels: const ['Weekend', 'General'],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TabBarView(
                controller: _tabController,
                children: const [WeekendOutingTab(), GeneralOutingTab()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
