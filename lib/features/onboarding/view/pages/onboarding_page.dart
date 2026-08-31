import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/vsync_logo.dart';
import 'package:vit_ap_student_app/core/utils/theme_switch_button.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/login_page.dart';

/// First-launch flow: a welcome screen and a quick "how it works",
/// pushr-style, then straight into login.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == 0) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (builder) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: ThemeSwitchButton(),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  _WelcomeScreen(),
                  _HowItWorksScreen(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage == 0 ? "let's go" : 'got it',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${_currentPage + 1} of 2',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'welcome to',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          const VSyncLogo(
            label: 'vsync',
            fontSize: 34,
            letterSpacing: 0.5,
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: 'vsync is your new academic companion.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                  text:
                      ' it helps you track your marks, attendance, and grades '
                  'all in one place — all in a beautiful and focused '
                  'interface.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksScreen extends StatelessWidget {
  const _HowItWorksScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'how it works',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 34,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: 'to keep everything up to date,',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                  text:
                      ' just connect your college portal once and vsync takes '
                  'it from there.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'vsync checks your attendance and grades in the background and '
            'turns them into a simple, clear dashboard — so you always know '
            'exactly where you stand.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
