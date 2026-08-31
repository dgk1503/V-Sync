import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/launch_web.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/account/view/pages/manage_credentials_page.dart';
import 'package:vit_ap_student_app/features/account/view/pages/settings_page.dart';
import 'package:vit_ap_student_app/features/account/view/widgets/settings_tile.dart';
import 'package:vit_ap_student_app/features/account/viewmodel/account_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/login_page.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/semester_viewmodel.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _isNavigating = false;

  Future<void> _navigateTo(WidgetBuilder builder) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: builder),
      );
    } finally {
      if (mounted) {
        _isNavigating = false;
      }
    }
  }

  void _showSemesterPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SemesterPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    ref.listen(accountViewModelProvider, (_, next) {
      next?.when(
        data: (data) {
          showSnackBar(
            context,
            'Successfully synced with VTOP',
            SnackBarType.success,
          );
        },
        loading: () {
          showSnackBar(
            context,
            'Syncing with VTOP in the background...',
            SnackBarType.warning,
          );
        },
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Identity block: name on top, semester + change below.
              Text(
                user?.profile.target?.studentName ?? 'N/A',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: DemoService.isDemoMode ? null : _showSemesterPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<String>(
                        future: ref
                            .read(semesterViewModelProvider.notifier)
                            .getSelectedSemester()
                            .then((s) => s?.name ?? 'Select semester'),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Select semester',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Iconsax.edit_copy,
                        size: 15,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Main settings group
              _SettingsGroup(
                children: [
                  // Managing VTOP credentials is meaningless for the demo
                  // account, so the entry point is hidden in demo mode.
                  if (!DemoService.isDemoMode)
                    SettingTile(
                      isFirst: true,
                      isLast: false,
                      title: 'Manage credentials',
                      leadingIcon: const Icon(Iconsax.lock_1_copy),
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (builder) => const ManageCredentialsPage(),
                          ),
                        );
                        if (result == true) {
                          await ref
                              .read(accountViewModelProvider.notifier)
                              .sync();
                        }
                      },
                    ),
                  SettingTile(
                    isFirst: !DemoService.isDemoMode,
                    isLast: false,
                    title: 'Sync',
                    infoText:
                        'When synced, latest data will be fetched from VTOP.',
                    leadingIcon: const Icon(Iconsax.repeat),
                    onTap: () async {
                      await ref.read(accountViewModelProvider.notifier).sync();
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: true,
                    title: 'Appearance',
                    leadingIcon: const Icon(Iconsax.moon_copy),
                    onTap: () => _navigateTo(
                      (builder) => const SettingsPage(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Actions group
              _SettingsGroup(
                children: [
                  SettingTile(
                    isFirst: true,
                    isLast: false,
                    title: 'Source code',
                    leadingIcon: const Icon(Iconsax.code_copy),
                    onTap: () async {
                      await directToWeb(
                        'https://github.com/dgk1503/V-Sync',
                      );
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Terms of Use',
                    leadingIcon: const Icon(Iconsax.document_text_copy),
                    onTap: () async {
                      // TODO: Replace with your actual hosted terms URL
                      await directToWeb(
                        'https://v-sync-minimallabs.vercel.app/terms',
                      );
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Privacy Policy',
                    leadingIcon: const Icon(Iconsax.shield_tick_copy),
                    onTap: () async {
                      // TODO: Replace with your actual hosted privacy policy URL
                      await directToWeb(
                        'https://v-sync-minimallabs.vercel.app/privacypolicy',
                      );
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: true,
                    title: 'Logout',
                    leadingIcon: const Icon(Iconsax.logout),
                    leadingIconColor: Colors.red,
                    titleColor: Colors.redAccent,
                    onTap: () async {
                      await ref.read(currentUserProvider.notifier).logout();
                      if (!context.mounted) return;
                      await Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => const LoginPage(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded monochrome container that groups setting tiles.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// Bottom sheet listing the available semesters; picking one re-syncs
/// the app against VTOP for that semester.
class _SemesterPickerSheet extends ConsumerStatefulWidget {
  const _SemesterPickerSheet();

  @override
  ConsumerState<_SemesterPickerSheet> createState() =>
      _SemesterPickerSheetState();
}

class _SemesterPickerSheetState extends ConsumerState<_SemesterPickerSheet> {
  String? _currentSemesterId;
  bool _initialised = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await ref
          .read(semesterViewModelProvider.notifier)
          .getSelectedSemester();

      final credentials =
          await ref.read(currentUserProvider.notifier).getSavedCredentials();
      if (credentials == null) {
        setState(() {
          _error = 'Credentials not found';
          _initialised = true;
        });
        return;
      }

      await ref.read(semesterViewModelProvider.notifier).fetchSemesters(
            registrationNumber: credentials.registrationNumber,
            password: credentials.password,
            needsUpdate: true,
          );

      if (mounted) {
        setState(() {
          _currentSemesterId = current?.id;
          _initialised = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initialised = true;
        });
      }
    }
  }

  Future<void> _select(SemesterInfo semester) async {
    final credentials =
        await ref.read(currentUserProvider.notifier).getSavedCredentials();
    if (credentials == null) return;

    final changed = _currentSemesterId != semester.id;
    await ref
        .read(semesterViewModelProvider.notifier)
        .setSelectedSemester(semester.id);

    if (!mounted) return;

    if (!changed) {
      Navigator.pop(context);
      return;
    }

    // Re-login so all data is refetched for the chosen semester.
    await ref.read(authViewModelProvider.notifier).loginUser(
          semSubId: semester.id,
          registrationNumber: credentials.registrationNumber,
          password: credentials.password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semesterState = ref.watch(semesterViewModelProvider);
    final isAuthLoading = ref.watch(
      authViewModelProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(authViewModelProvider, (_, next) {
      next?.when(
        data: (_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<void>(
                builder: (context) => const BottomNavBar()),
            (_) => false,
          );
        },
        error: (error, _) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
        loading: () {},
      );
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change semester',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (!_initialised ||
                  semesterState == null ||
                  semesterState.isLoading ||
                  isAuthLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (semesterState.hasValue &&
                  semesterState.value!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No semesters available. Try again later.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (semesterState.hasValue)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: semesterState.value!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final semester = semesterState.value![index];
                      final isCurrent = semester.id == _currentSemesterId;

                      return GestureDetector(
                        onTap: () => _select(semester),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? colorScheme.surfaceContainerHigh
                                : colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  semester.name,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Icon(
                                  Iconsax.tick_circle_copy,
                                  size: 18,
                                  color: colorScheme.onSurface,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
