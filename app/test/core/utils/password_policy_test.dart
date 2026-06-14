import 'package:app/src/core/utils/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts a password matching the backend policy', () {
      expect(PasswordPolicy.isValid('StrongPass1!'), isTrue);
    });

    test('accepts non-ASCII special characters', () {
      expect(PasswordPolicy.isValid('StrongPass1×'), isTrue);
    });

    test('rejects each missing requirement', () {
      expect(PasswordPolicy.isValid('Short1!'), isFalse);
      expect(PasswordPolicy.isValid('lowercase1!'), isFalse);
      expect(PasswordPolicy.isValid('UPPERCASE1!'), isFalse);
      expect(PasswordPolicy.isValid('NoDigits!'), isFalse);
      expect(PasswordPolicy.isValid('NoSpecial1'), isFalse);
    });
  });
}
