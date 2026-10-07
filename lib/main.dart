import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/bottom_navigation_bar.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/providers/schedule_home_widget_notifier.dart';
import 'package:vit_ap_student_app/core/providers/theme_mode_notifier.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/services/notification_service.dart';
import 'package:vit_ap_student_app/core/services/app_update_service.dart';
import 'package:vit_ap_student_app/core/services/vtop_service.dart';
import 'package:vit_ap_student_app/features/auth/view/widgets/auth_failure_bottom_sheet.dart';
import 'package:vit_ap_student_app/features/auth/view/widgets/login_otp_overlay.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/login_otp_challenge.dart';
import 'package:vit_ap_student_app/features/onboarding/view/pages/onboarding_page.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();

  // The local-notifications plugin must be initialized before anything can
  // be shown or scheduled (countdown reminders, download notifications).
  // Also triggers the POST_NOTIFICATIONS permission prompt.
  await NotificationService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _otpSubscription;
  StreamSubscription<String>? _authFailureSubscription;
  bool _isAuthFailureSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppUpdateService.checkForUpdate());
    _otpSubscription = serviceLocator<VtopClientService>().onOtpRequired.listen(
      (_) => _showGlobalOtpSheet(),
    );
    _authFailureSubscription = serviceLocator<VtopClientService>().onAuthFailure
        .listen((message) => _showGlobalAuthFailureSheet(message));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppUpdateService.checkForUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _otpSubscription?.cancel();
    _authFailureSubscription?.cancel();
    super.dispose();
  }

  /// An OTP challenge started. The prompt itself is mounted permanently in
  /// `build`, so this only has to raise the challenge in state.
  void _showGlobalOtpSheet() {
    ref.read(loginOtpChallengeProvider.notifier).requestOtp();
  }

  void _showGlobalAuthFailureSheet(String message) {
    if (_isAuthFailureSheetShowing) return;
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) return;
    final overlay = navigatorState.overlay;
    if (overlay == null) return;

    final isLoggedIn = ref.read(currentUserProvider.notifier).isLoggedIn;
    _isAuthFailureSheetShowing = true;
    showAuthFailureBottomSheet(
      context: overlay.context,
      errorMessage: message,
      isLoggedIn: isLoggedIn,
    ).whenComplete(() {
      _isAuthFailureSheetShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Init home widget
    ref.read(scheduleHomeWidgetProvider.notifier).initializeTimetable();
    final isLoggedIn = ref.read(currentUserProvider.notifier).isLoggedIn;
    final themeMode = ref.watch(themeModeProvider);
    final userPreferences = ref.watch(userPreferencesProvider);

    // Transparent system bars for every phone, with icon brightness that
    // follows the app theme (dark theme → light icons, light theme → dark
    // icons). The app draws edge to edge (SystemUiMode.edgeToEdge, set in
    // initDependencies), so the surface behind both bars is the app itself;
    // without this the icons would sit on whatever the platform defaults to
    // and be unreadable or invisible.
    final systemOverlayStyle =
        themeMode.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      themeAnimationCurve: Curves.easeInOut,
      debugShowCheckedModeBanner: false,
      theme: themeMode,
      title: 'V Sync',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(userPreferences.fontScale ?? 1.0),
          ),
          // The OTP prompt lives ABOVE the Navigator rather than in it.
          //
          // It used to be an `OverlayEntry` inserted on demand, which tied the
          // prompt to a navigator that might not exist yet: an OTP required
          // during startup was dropped on the floor and the pending request
          // hung forever. Being an unconditional child of the app shell means
          // it is mounted from the first frame, survives route changes and
          // rebuilds, and renders nothing while no challenge is active.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: systemOverlayStyle,
            child: LoginOtpOverlay(
              child: Stack(children: [child!]),
            ),
          ),
        );
      },
      home: isLoggedIn ? const BottomNavBar() : const OnboardingPage(),
    );
  }
}
