class HonorMessagePolicy {
  const HonorMessagePolicy._();

  static const int minimumLength = 10;
  static const int maximumLength = 200;

  static int length(String value) => value.trim().runes.length;

  static bool isValid(String value) {
    final messageLength = length(value);
    return messageLength >= minimumLength && messageLength <= maximumLength;
  }

  static String? validationMessage(String value) {
    final messageLength = length(value);
    if (messageLength == 0) return null;
    if (messageLength < minimumLength) {
      return 'Write at least $minimumLength characters.';
    }
    if (messageLength > maximumLength) {
      return 'Keep the message under $maximumLength characters.';
    }
    return null;
  }
}
