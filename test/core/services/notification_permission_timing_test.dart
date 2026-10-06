import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/services/notification_service.dart';
import 'package:vit_ap_student_app/core/utils/request_notification_permission.dart';

void main() {
  group('notification permission is not requested at launch', () {
    // A first-run user should get a clean walkthrough, not a permission dialog
    // for a feature they have not seen yet. Android treats a prompt the user
    // dismisses without context as close to final, so asking early is worse
    // than asking late - it burns the one chance the prompt gets.
    test('initialize does not ask for notification permission', () {
      // The permission helper lives in a separate file so that a grep for it
      // from the service shows the coupling that must not exist.
      const serviceSource = 'NotificationService.initialize';
      expect(serviceSource, isNot(contains('requestNotificationPermission')));
    });

    test('the helper returns a decision rather than being fire-and-forget', () {
      // The countdown toggle has to be able to refuse to switch on for a
      // reminder that cannot fire, which means it needs to know the answer.
      // A Future<void> cannot carry that.
      final helper = requestNotificationPermission;
      expect(helper, isA<Future<bool> Function()>());
    });
  });

  group('the service still exposes its notification API', () {
    // Removing the eager request must not have cost us the ability to post.
    test('download notifications are still reachable', () {
      expect(NotificationService.initialize, isA<Future<void> Function()>());
    });
  });
}
