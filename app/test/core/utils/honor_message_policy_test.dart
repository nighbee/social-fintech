import 'package:app/src/core/utils/honor_message_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HonorMessagePolicy', () {
    test('accepts server boundary lengths', () {
      expect(HonorMessagePolicy.isValid('1234567890'), isTrue);
      expect(
        HonorMessagePolicy.isValid(List.filled(200, 'a').join()),
        isTrue,
      );
    });

    test('rejects messages outside server boundaries', () {
      expect(HonorMessagePolicy.isValid('123456789'), isFalse);
      expect(
        HonorMessagePolicy.isValid(List.filled(201, 'a').join()),
        isFalse,
      );
    });

    test('counts trimmed Unicode characters', () {
      expect(HonorMessagePolicy.length('  Honor ×××  '), 9);
    });
  });
}
