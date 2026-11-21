import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/constants/legal_links.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/launch_web.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/account/view/pages/customization_page.dart';
import 'package:vit_ap_student_app/features/account/view/pages/manage_credentials_page.dart';
import 'package:vit_ap_student_app/core/services/gmail_otp_store.dart';
import 'package:vit_ap_student_app/features/account/view/pages/otp_autofetch_page.dart';
import 'package:vit_ap_student_app/features/account/view/pages/settings_page.dart';
import 'package:vit_ap_student_app/features/account/view/widgets/settings_tile.dart';
import 'package:vit_ap_student_app/features/account/viewmodel/account_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/login_page.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:vit_ap_student_app/features/auth/view/widgets/semester_year_list.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/semester_viewmodel.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

/// Website opened by the "Website" tile in the Actions group below.
///
/// >>> PLACE YOUR WEBSITE LINK HERE <<<
/// Replace the placeholder URL with your real site (keep the https://
/// scheme). This single constant feeds the account-page tile; the Terms
/// of Use / Privacy Policy pages still live at their own URLs, but are no longer
/// listed here.
const String kWebsiteUrl = 'https://v-sync-minimallabs.vercel.app';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _isNavigating = false;

  /// Guards the one-time background resync that repairs profiles scraped
  /// before the student-name parsing fix (their cached `studentName` is
  /// empty, so the identity block falls back to the registration number).
  bool _nameAutoHealTriggered = false;

  Future<void> _navigateTo(WidgetBuilder builder) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      await Navigator.push(context, MaterialPageRoute<void>(builder: builder));
    } finally {
      if (mounted) {
        _isNavigating = false;
      }
    }
  }

  /// The selected semester's name, resolved once and kept. It used to be read
  /// inside the build, so every rebuild started a new lookup and showed
  /// "Select semester" until it finished.
  String? _semesterName;
  bool _semesterLoaded = false;

  Future<void> _loadSemesterName() async {
    final semester = await ref
        .read(semesterViewModelProvider.notifier)
        .getSelectedSemester();
    if (!mounted) return;
    setState(() {
      _semesterName = semester?.name;
      _semesterLoaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSemesterName();
  }

  /// True while "Refresh all data" is running, so it cannot be started twice.
  bool _refreshing = false;

  /// Pulls everything the app shows from VTOP in one go: profile, attendance,
  /// timetable, exams and marks, then the academic calendar. Each part also
  /// refreshes on its own page; this is the one button for "make it all current".
  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final account = ref.read(accountViewModelProvider.notifier);
      await account.sync();
      final failed = ref.read(accountViewModelProvider)?.hasError == true;

      // The calendar is a separate request; it reports its own failure on its
      // own page, so a miss here does not undo the sync above.
      try {
        await ref.read(calendarViewmodelProvider.notifier).refresh();
      } catch (_) {}

      if (!failed && mounted) {
        final prefs = ref.read(userPreferencesProvider);
        await ref
            .read(userPreferencesProvider.notifier)
            .updatePreferences(prefs.copyWith(lastSync: DateTime.now()));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _showSemesterPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SemesterPickerSheet(),
    );
    // The choice may have changed in the sheet.
    if (mounted) await _loadSemesterName();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final showManageCredentials = !DemoService.isDemoMode;

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

    // One-time self-heal: profiles cached before the student-name parsing fix
    // carry an empty `studentName`, so the identity block below falls back to
    // the registration number. Kick off a single background sync to refill it
    // instead of forcing the user to log out and back in.
    if (!_nameAutoHealTriggered &&
        !DemoService.isDemoMode &&
        user != null &&
        (user.profile.target?.studentName.trim().isEmpty ?? true)) {
      _nameAutoHealTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(accountViewModelProvider.notifier).sync();
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        // bottom: false lets content scroll underneath the floating capsule
        // nav bar; the scroll padding below keeps the last tile clear of it
        // when fully scrolled.
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            kFloatingNavBarClearance + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Identity block: the student's name, and the selected
              // semester with its change shortcut below. The name is the one
              // field shown — no register-number fallback, so the header
              // always reads as a name or a neutral placeholder.
              Builder(
                builder: (context) {
                  final name = user?.profile.target?.studentName.trim() ?? '';
                  return Text(
                    name.isNotEmpty ? name : 'N/A',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
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
                      Text(
                        // Nothing until the lookup has finished, so the header
                        // never claims "Select semester" while it is merely
                        // still reading the answer.
                        !_semesterLoaded
                            ? ''
                            : _semesterName ?? 'Select semester',
                        style: const TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 14,
                          // Keep the interactive semester shortcut blue;
                          // it was previously changed to the monochrome
                          // primary colour and disappeared in light mode.
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.pencil,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Main settings group. ONE section: every row lives in the same
              // card, separated by the tile's own hairline, so spacing is
              // uniform and there is no gap between "settings" and
              // "actions". One unique Lucide glyph per feature.
              _SettingsGroup(
                children: [
                  // Managing VTOP credentials is meaningless for the demo
                  // account, so the entry point is hidden in demo mode.
                  if (showManageCredentials)
                    SettingTile(
                      isFirst: true,
                      isLast: false,
                      title: 'Manage credentials',
                      leadingIcon: const Icon(LucideIcons.keyRound),
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
                    isFirst: !showManageCredentials,
                    isLast: false,
                    title: 'Appearance',
                    leadingIcon: const Icon(LucideIcons.moon),
                    onTap: () => _navigateTo((builder) => const SettingsPage()),
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Customization',
                    leadingIcon: const Icon(LucideIcons.palette),
                    onTap: () =>
                        _navigateTo((builder) => const CustomizationPage()),
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Refresh all data',
                    leadingIcon: const Icon(LucideIcons.refreshCw),
                    // A command, not a link: no chevron, a spinner while it runs.
                    trailingWidget: _refreshing
                        ? const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const SizedBox.shrink(),
                    onTap: _refreshing ? null : _refreshAll,
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Automatic OTP Fetching',
                    subtitle: _otpSubtitle(ref.watch(gmailOtpSettingsProvider)),
                    leadingIcon: const Icon(LucideIcons.mailCheck),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OtpAutofetchPage(),
                      ),
                    ),
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Website',
                    leadingIcon: const Icon(LucideIcons.globe),
                    onTap: () async {
                      await directToWeb(kWebsiteUrl);
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: false,
                    title: 'Privacy Policy',
                    leadingIcon: const Icon(LucideIcons.shieldCheck),
                    onTap: () async {
                      await directToWeb(kPrivacyPolicyUrl);
                    },
                  ),
                  SettingTile(
                    isFirst: false,
                    isLast: true,
                    title: 'Logout',
                    leadingIcon: const Icon(LucideIcons.logOut),
                    leadingIconColor: Colors.red,
                    titleColor: Colors.redAccent,
                    // Logout is a command, not a link: no chevron.
                    trailingWidget: const SizedBox.shrink(),
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
/// What the tile says under its name: whether the Gmail reader is on.
String? _otpSubtitle(GmailOtpSettings settings) {
  if (!settings.loaded) return null;
  if (!settings.isConnected) return 'Read your VTOP code from Gmail';
  return settings.enabled ? 'On \u00b7 ${settings.email}' : 'Off';
}

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

      final credentials = await ref
          .read(currentUserProvider.notifier)
          .getSavedCredentials();
      if (credentials == null) {
        setState(() {
          _error = 'Credentials not found';
          _initialised = true;
        });
        return;
      }

      await ref
          .read(semesterViewModelProvider.notifier)
          .fetchSemesters(
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
    final credentials = await ref
        .read(currentUserProvider.notifier)
        .getSavedCredentials();
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
    await ref
        .read(authViewModelProvider.notifier)
        .loginUser(
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
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
                      fontFamily: 'Instrument Sans',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (semesterState.hasValue && semesterState.value!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No semesters available. Try again later.',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (semesterState.hasValue)
                Flexible(
                  child: SemesterYearList(
                    shrinkWrap: true,
                    semesters: semesterState.value!,
                    currentId: _currentSemesterId,
                    onSelect: _select,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
