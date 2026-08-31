import 'package:flutter/material.dart';

/// In-app preview of the VSync Terms of Use & Privacy Policy.
///
/// This page is intentionally self-contained (no network, no dependencies)
/// and follows the app's monochrome design language: Outfit for headings
/// and body, Inter for fine-print labels.
///
/// The same text should be mirrored on a public URL (e.g. GitHub Pages)
/// because Google Play Console requires a hosted privacy policy link.
class TermsPreviewPage extends StatelessWidget {
  const TermsPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'terms & privacy',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'last updated: august 2026',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'vsync is a local client for your college portal. we do not '
                'collect, store, or transmit any of your data to our '
                'servers — everything happens on your device.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 28),
              _Section(
                heading: '1. no data collection',
                colorScheme: colorScheme,
                body: const [
                  'vsync has no backend servers. we do not collect, '
                  'transmit, sell, or share any personal information, '
                  'analytics, or usage data of any kind.',
                  'your VTOP credentials (registration number and password) '
                  'are entered by you, stay on your device, and are used '
                  'solely to log in to the official VTOP portal. they are '
                  'never sent anywhere else.',
                ],
              ),
              _Section(
                heading: '2. local scraping',
                colorScheme: colorScheme,
                body: const [
                  'all data shown in the app — timetable, attendance, '
                  'marks, and more — is fetched by a scraper that runs '
                  'entirely on your device. the app requests pages from '
                  'the VTOP portal directly, on your behalf, exactly as '
                  'your browser would.',
                  'fetched data is stored only in your device\'s local '
                  'database and is never uploaded to us or any third '
                  'party.',
                ],
              ),
              _Section(
                heading: '3. permissions & storage',
                colorScheme: colorScheme,
                body: const [
                  'internet: required to reach the VTOP portal.',
                  'notifications: used for local class reminders generated '
                  'on your device.',
                  'storage: used only when you explicitly export or share '
                  'a file (e.g. a timetable or document).',
                ],
              ),
              _Section(
                heading: '4. third parties',
                colorScheme: colorScheme,
                body: const [
                  'vsync contains no advertising SDKs, trackers, or '
                  'third-party analytics. the only network traffic the '
                  'app makes is to the VTOP portal itself.',
                ],
              ),
              _Section(
                heading: '5. terms of use',
                colorScheme: colorScheme,
                body: const [
                  'vsync is an independent, unofficial app and is not '
                  'affiliated with, endorsed by, or connected to VIT or '
                  'the VTOP portal in any way.',
                  'the app is provided "as is", without warranties of any '
                  'kind. you are responsible for using it in accordance '
                  'with your institution\'s policies and for keeping your '
                  'credentials safe.',
                ],
              ),
              _Section(
                heading: '6. data deletion',
                colorScheme: colorScheme,
                body: const [
                  'since all data lives on your device, uninstalling the '
                  'app (or using its sign-out / clear-data options) '
                  'permanently removes everything. there is nothing to '
                  'request a deletion of on our side.',
                ],
              ),
              _Section(
                heading: '7. contact',
                colorScheme: colorScheme,
                body: const [
                  'questions about this policy? reach out to us on the '
                  'project\'s GitHub repository.',
                ],
                isLast: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.heading,
    required this.body,
    required this.colorScheme,
    this.isLast = false,
  });

  final String heading;
  final List<String> body;
  final ColorScheme colorScheme;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 32.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.25,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < body.length; i++) ...[
            Text(
              body[i],
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.55,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (i != body.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
