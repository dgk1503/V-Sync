import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/auth_field.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/network/connection_checker.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/semester_selection_page.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/terms_preview_page.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/semester_viewmodel.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _termsRecognizer.onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const TermsPreviewPage(),
        ),
      );
    };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginDemo() async {
    await ref.read(authViewModelProvider.notifier).loginDemoUser();
    if (!mounted) return;

    ref.read(authViewModelProvider)?.when(
          data: (_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const BottomNavBar(),
              ),
              (_) => false,
            );
          },
          error: (error, _) {
            showSnackBar(context, error.toString(), SnackBarType.error);
          },
          loading: () {},
        );
  }

  Future<void> _fetchSemestersAndNavigate() async {
    // Demo account: bypass VTOP entirely (no network, no OTP, no semester
    // selection) and seed the app from the bundled sample dataset.
    if (DemoService.instance.isDemoCredentials(
      usernameController.text,
      passwordController.text,
    )) {
      await _loginDemo();
      return;
    }

    final connectivityResult = await ConnectionCheckerImpl(
      InternetConnection(),
    ).isConnected;
    if (!mounted) return;
    if (!connectivityResult) {
      showSnackBar(
        context,
        'Please check your internet connection',
        SnackBarType.error,
      );
      return;
    }

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(semesterViewModelProvider.notifier)
        .fetchSemestersForLogin(
          registrationNumber: usernameController.text.trim().toUpperCase(),
          password: passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(
          semesterViewModelProvider.select((val) => val?.isLoading == true),
        ) ||
        ref.watch(
          authViewModelProvider.select((val) => val?.isLoading == true),
        );

    ref.listen(semesterViewModelProvider, (previous, next) {
      // Only navigate if this is the initial fetch (previous was null or loading)
      // This prevents re-navigation when SemesterSelectionPage fetches semesters
      if (previous?.hasValue == true) return;

      next?.when(
        data: (semesters) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => SemesterSelectionPage(
                registrationNumber: usernameController.text.toUpperCase(),
                password: passwordController.text,
              ),
            ),
          );
        },
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
        loading: () {},
      );
    });

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        const AccentGradientText(
                          'welcome back',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'connect your college portal once and vsync '
                          'takes it from there.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 40),
                        AuthField(
                          title: 'Username',
                          hintText: 'VTOP Username',
                          controller: usernameController,
                        ),
                        const SizedBox(height: 14),
                        AuthField(
                          title: 'Password',
                          hintText: 'VTOP Password',
                          controller: passwordController,
                          isObscureText: true,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed:
                                isLoading ? null : _fetchSemestersAndNavigate,
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              disabledBackgroundColor:
                                  colorScheme.surfaceContainerHigh,
                              disabledForegroundColor:
                                  colorScheme.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Loader(),
                                  )
                                : const Text(
                                    'continue',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              text: 'by continuing, you agree to our ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                                height: 1.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: 'terms & privacy policy',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: colorScheme.onSurface,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colorScheme.onSurface,
                                  ),
                                  recognizer: _termsRecognizer,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
