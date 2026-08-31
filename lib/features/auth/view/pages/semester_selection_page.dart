import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/semester_viewmodel.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

class SemesterSelectionPage extends ConsumerStatefulWidget {
  final String registrationNumber;
  final String password;

  const SemesterSelectionPage({
    super.key,
    required this.registrationNumber,
    required this.password,
  });

  @override
  ConsumerState<SemesterSelectionPage> createState() =>
      _SemesterSelectionPageState();
}

class _SemesterSelectionPageState extends ConsumerState<SemesterSelectionPage> {
  SemesterInfo? selectedSemester;
  String? inlineError;
  String? currentSemesterId;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    // Get current semester ID
    final currentSemester = await ref
        .read(semesterViewModelProvider.notifier)
        .getSelectedSemester();

    if (mounted) {
      setState(() {
        currentSemesterId = currentSemester?.id;
      });
    }

    // Only fetch if we don't already have semester data
    final currentState = ref.read(semesterViewModelProvider);
    if (currentState == null ||
        currentState.hasError ||
        !currentState.hasValue) {
      await ref
          .read(semesterViewModelProvider.notifier)
          .fetchSemesters(
            registrationNumber: widget.registrationNumber,
            password: widget.password,
            needsUpdate: true,
          );
    }
  }

  Future<void> _loginUser() async {
    setState(() => inlineError = null);

    if (selectedSemester == null) {
      setState(() {
        inlineError = 'Please select a semester to continue.';
      });
      return;
    }

    // Check if semester has changed
    final semesterChanged = currentSemesterId != selectedSemester!.id;

    // Save selected semester to cache
    await ref
        .read(semesterViewModelProvider.notifier)
        .setSelectedSemester(selectedSemester!.id);

    if (!semesterChanged) {
      // If semester hasn't changed, just navigate back or close the page
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Only call loginUser if semester has changed
    await ref
        .read(authViewModelProvider.notifier)
        .loginUser(
          semSubId: selectedSemester!.id,
          registrationNumber: widget.registrationNumber,
          password: widget.password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semesterState = ref.watch(semesterViewModelProvider);
    final isAuthLoading = ref.watch(
      authViewModelProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(semesterViewModelProvider, (_, next) {
      next?.when(
        data: (_) {},
        error: (error, _) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
        loading: () {},
      );
    });

    ref.listen(authViewModelProvider, (_, next) {
      next?.when(
        data: (_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<void>(builder: (context) => const BottomNavBar()),
            (_) => false,
          );
        },
        error: (error, _) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
        loading: () {},
      );
    });

    return Scaffold(
      body: SafeArea(
        child: semesterState == null || semesterState.isLoading
            ? const Center(child: Loader())
            : semesterState.when(
                data: (semesters) {
                  if (semesters.isEmpty) {
                    return const Center(
                      child: Text(
                        'No semesters available. Please try again later.',
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 48, 24, 0),
                        child: AccentGradientText(
                          'pick your semester',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'this helps vsync fetch the right academic data. '
                          'you can change it later anytime.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (inlineError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                          ),
                          child: Text(
                            inlineError!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          itemCount: semesters.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final semester = semesters[index];
                            final isSelected = selectedSemester == semester;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedSemester = semester;
                                  inlineError = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                    width: 0.75,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        semester.name,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (semester.id == currentSemesterId)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        child: Text(
                                          'current',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? colorScheme.onPrimary
                                                    .withValues(alpha: 0.7)
                                                : colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed:
                                isAuthLoading ? null : _loginUser,
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
                            child: isAuthLoading
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
                      ),
                    ],
                  );
                },
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Failed to load semesters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializePage,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                loading: () => const Center(child: Loader()),
              ),
      ),
    );
  }
}
