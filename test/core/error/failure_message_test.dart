import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/error/exceptions.dart';

String msg(String type, {required bool online, String detail = ''}) =>
    VtopException.failureMessageFor(type, detail, online: online);

void main() {
  group('a failed connection says whose fault it is', () {
    test('internet fine, VTOP unreachable -> VTOP is the problem', () {
      final text = msg('NetworkError', online: true);
      expect(text, contains('VTOP'));
      expect(text, contains('Your internet is working'));
      expect(text, isNot(contains('No internet connection')));
    });

    test('phone offline -> tells the student to check their connection', () {
      final text = msg('NetworkError', online: false);
      expect(text, contains('No internet connection'));
      expect(text, isNot(contains("VIT-AP's servers")));
    });

    test('a timeout is VTOP being slow when the internet works', () {
      expect(msg('TimeoutError', online: true), contains('very slowly'));
      expect(
        msg('TimeoutError', online: false),
        contains('too slow or unstable'),
      );
    });

    test('a refused connection blames VTOP only when the phone is online', () {
      expect(msg('ConnectionRefused', online: true), contains('maintenance'));
      expect(
        msg('ConnectionRefused', online: false),
        contains('No internet connection'),
      );
    });

    test('a DNS failure follows the same rule as a network error', () {
      expect(msg('DnsError', online: true), contains('VTOP'));
      expect(msg('DnsError', online: false), contains('No internet'));
    });
  });

  group('errors that are about VTOP, not the phone', () {
    test('a server error says it is VTOP, and that the account is fine', () {
      final text = msg('VtopServerError', online: false);
      expect(text, contains('VTOP is having problems'));
      expect(text, contains('Nothing is wrong with your account'));
    });

    test('a switched-off menu says the saved data is still there', () {
      final text = msg('MenuUnavailable', online: true);
      expect(text, contains('not serving this page'));
      expect(text, contains('saved data'));
    });

    test('an unreadable page says the saved data is unchanged', () {
      expect(msg('ParseError', online: true), contains('unchanged'));
      expect(msg('InvalidResponse', online: true), contains('unchanged'));
    });

    test('a lockout message from VTOP is passed through untouched', () {
      const lockout = 'Number Of Maximum Fail Attempts Reached. Try later.';
      expect(
        msg('AuthenticationFailed', online: true, detail: lockout),
        lockout,
      );
    });

    test('an unknown type falls back to the message from Rust', () {
      expect(
        msg('SomethingNew', online: true, detail: 'plain words'),
        'plain words',
      );
    });
  });
}
