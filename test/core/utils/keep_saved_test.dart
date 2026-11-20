import 'package:flutter_test/flutter_test.dart';
import 'package:vit_ap_student_app/core/utils/keep_saved.dart';

void main() {
  test('an empty answer never replaces saved data', () {
    expect(shouldKeepSaved(fresh: const [], saved: const [1, 2]), isTrue);
  });

  test('a real answer replaces what was saved', () {
    expect(shouldKeepSaved(fresh: const [3], saved: const [1, 2]), isFalse);
  });

  test('nothing saved yet, so an empty answer is accepted as it is', () {
    expect(shouldKeepSaved(fresh: const [], saved: const []), isFalse);
  });
}
