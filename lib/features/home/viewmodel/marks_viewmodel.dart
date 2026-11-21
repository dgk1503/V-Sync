import 'package:fpdart/fpdart.dart';
import 'package:objectbox/objectbox.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/models/mark.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/keep_saved.dart';
import 'package:vit_ap_student_app/features/home/repository/home_remote_repository.dart';

part 'marks_viewmodel.g.dart';

@riverpod
class MarksViewModel extends _$MarksViewModel {
  late HomeRemoteRepository _homeRemoteRepository;

  @override
  AsyncValue<List<Mark>>? build() {
    _homeRemoteRepository = ref.watch(homeRemoteRepositoryProvider);

    return null;
  }

  Future<void> refreshMarks() async {
    // Demo mode: serve the marks seeded into the user at login.
    if (DemoService.isDemoMode) {
      final demoUser = ref.read(currentUserProvider);
      state = AsyncValue.data(demoUser?.marks.toList() ?? []);
      return;
    }

    state = const AsyncValue.loading();
    final User? user = ref.read(currentUserProvider);
    final userNotifier = ref.read(currentUserProvider.notifier);
    final Credentials? credentials = await userNotifier.getSavedCredentials();
    if (credentials == null) {
      // Assigned and returned: building the error and carrying on used to
      // dereference the null on the next line, which threw and left the page
      // on "loading" for good.
      state = AsyncValue<List<Mark>>.error(
        'Your saved login could not be read. Please log out and log in again.',
        StackTrace.current,
      );
      return;
    }
    final res = await _homeRemoteRepository.fetchMarks(
      registrationNumber: credentials.registrationNumber,
      password: credentials.password,
      semSubId: credentials.semSubId,
    );

    if (res case Left(value: final failure)) {
      state = AsyncValue.error(failure.message, StackTrace.current);
    } else if (res case Right(value: final newMarks)) {
      // VTOP answers a request it could not serve properly with a normal, empty
      // page, so an empty result is not proof the student has no marks. Never
      // let it replace marks that are already saved: that is how marks
      // vanished until the user logged in again.
      final saved = user?.marks.toList() ?? const <Mark>[];
      if (shouldKeepSaved(fresh: newMarks, saved: saved)) {
        state = AsyncValue.error(
          'VTOP sent no marks this time, so your saved marks are being shown. '
          'Try again in a little while.',
          StackTrace.current,
        );
        return;
      }

      state = AsyncValue.data(newMarks);
      if (user != null) {
        await userNotifier.updateUser(
          user.copyWith(marks: ToMany<Mark>(items: newMarks)),
        );
      }
    }
  }
}
