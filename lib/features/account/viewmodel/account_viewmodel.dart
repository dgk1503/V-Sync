import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/features/account/repository/account_remote_repository.dart';

part 'account_viewmodel.g.dart';

@riverpod
class AccountViewModel extends _$AccountViewModel {
  late AccountRemoteRepository _accountRemoteRepository;

  @override
  AsyncValue<User>? build() {
    _accountRemoteRepository = ref.watch(accountRemoteRepositoryProvider);
    return null;
  }

  Future<void> sync() async {
    state = const AsyncValue.loading();

    // Demo mode: re-affirm the seeded demo user without contacting VTOP.
    if (DemoService.isDemoMode) {
      final demoUser = ref.read(currentUserProvider);
      state = demoUser != null
          ? AsyncValue.data(demoUser)
          : AsyncValue.data(await DemoService.instance.loadDemoUser());
      return;
    }

    final User? user = ref.read(currentUserProvider);
    final userNotifier = ref.read(currentUserProvider.notifier);
    final Credentials? credentials = await userNotifier.getSavedCredentials();
    if (credentials == null) {
      state = AsyncValue<User>.error(
        'Your saved login could not be read. Please log out and log in again.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();
    final res = await _accountRemoteRepository.syncUser(
      registrationNumber: credentials.registrationNumber,
      password: credentials.password,
      semSubId: credentials.semSubId,
    );

    if (res case Left(value: final failure)) {
      state = AsyncValue.error(failure.message, StackTrace.current);
    } else if (res case Right(value: final newUser)) {
      debugPrint(newUser.toString());
      state = AsyncValue.data(newUser);
      if (user != null) {
        final updatedUser = newUser.copyWith(id: user.id);
        await userNotifier.updateUser(updatedUser);
        debugPrint(updatedUser.toString());
      }
    }
  }
}
