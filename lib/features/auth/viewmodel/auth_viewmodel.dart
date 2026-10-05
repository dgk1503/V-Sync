import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/calendar/viewmodel/calendar_viewmodel.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/features/auth/repository/auth_remote_repository.dart';

part 'auth_viewmodel.g.dart';

@riverpod
class AuthViewModel extends _$AuthViewModel {
  late AuthRemoteRepository _authRemoteRepository;
  late CurrentUserNotifier _currentUserNotifier;

  @override
  AsyncValue<User>? build() {
    _authRemoteRepository = ref.watch(authRemoteRepositoryProvider);
    _currentUserNotifier = ref.watch(currentUserProvider.notifier);
    return null;
  }

  /// Logs in the bundled demo account for App Store review / demos.
  ///
  /// Bypasses the entire VTOP flow (no credential check, no semester fetch, no
  /// OTP) and seeds local storage from [DemoService]'s sanitized dataset.
  Future<void> loginDemoUser() async {
    state = const AsyncValue.loading();

    try {
      final user = await DemoService.instance.loadDemoUser();
      final credentials = DemoService.instance.credentials;

      await DemoService.instance.setDemoMode(true);
      await _currentUserNotifier.loginUser(user, credentials);

      state = AsyncValue.data(user);
    } catch (e) {
      // Roll back the flag so the app doesn't get stuck in a broken demo state.
      await DemoService.instance.setDemoMode(false);
      state = AsyncValue.error(
        'Failed to start the demo. Please try again.',
        StackTrace.current,
      );
    }
  }

  Future<void> loginUser({
    required String semSubId,
    String? registrationNumber,
    String? password,
  }) async {
    state = const AsyncValue.loading();

    Credentials? credentials;

    // If credentials are provided as parameters, use them (first-time login)
    if (registrationNumber != null && password != null) {
      credentials = Credentials(
        registrationNumber: registrationNumber,
        password: password,
        semSubId: semSubId,
      );
    } else {
      // Otherwise, try to get saved credentials (re-authentication)
      credentials = await ref
          .read(currentUserProvider.notifier)
          .getSavedCredentials();
      if (credentials == null) {
        state = AsyncValue.error(
            'No saved credentials found. Please log in again.',
            StackTrace.current);
        return;
      }
    }

    final res = await _authRemoteRepository.login(
      registrationNumber: credentials.registrationNumber,
      password: credentials.password,
      semSubId: semSubId,
    );

    final Credentials newCredentials = Credentials(
      registrationNumber: credentials.registrationNumber,
      password: credentials.password,
      semSubId: semSubId,
    );

    if (res case Left(value: final failure)) {
      state = AsyncValue.error(failure.message, StackTrace.current);
    } else if (res case Right(value: final user)) {
      _getDataSuccess(user, newCredentials);
    }
  }

  AsyncValue<User> _getDataSuccess(User user, Credentials credentials) {
    _currentUserNotifier.loginUser(user, credentials);
    // Warm the semester calendar while the user is still on the login screen
    // completing the flow. It is the slowest thing the app fetches - a request
    // for the month list plus one per month - and nothing else needs it until
    // the calendar page, so fetching it here means that page is already warm.
    //
    // Deliberately not awaited: login must not wait on the calendar, and a
    // failure here is reported by the page that actually needs it.
    Future.microtask(
      () => ref.read(calendarViewmodelProvider.notifier).ensureLoaded(
        includeCountdowns: false,
      ),
    );
    return state = AsyncValue.data(user);
  }

}
