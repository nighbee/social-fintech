class PasswordPolicy {
  const PasswordPolicy._();

  static const int minimumLength = 8;

  static bool hasMinimumLength(String value) => value.length >= minimumLength;

  static bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);

  static bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);

  static bool hasDigit(String value) => RegExp(r'\d').hasMatch(value);

  static bool hasSpecialCharacter(String value) => value.runes.any((rune) {
        final character = String.fromCharCode(rune);
        return !RegExp(r'[A-Za-z0-9\s]').hasMatch(character);
      });

  static bool isValid(String value) =>
      hasMinimumLength(value) &&
      hasUppercase(value) &&
      hasLowercase(value) &&
      hasDigit(value) &&
      hasSpecialCharacter(value);

  static String? validationMessage(String value) {
    if (value.isEmpty) return 'Please enter a password';
    if (!hasMinimumLength(value)) {
      return 'Use at least $minimumLength characters';
    }
    if (!hasUppercase(value)) return 'Add an uppercase letter';
    if (!hasLowercase(value)) return 'Add a lowercase letter';
    if (!hasDigit(value)) return 'Add a number';
    if (!hasSpecialCharacter(value)) return 'Add a special character';
    return null;
  }
}
