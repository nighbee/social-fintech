import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  final String countryCode;

  PhoneNumberFormatter(this.countryCode);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;

    if (newText.length < countryCode.length) {
      return TextEditingValue(
        text: countryCode,
        selection: TextSelection.collapsed(offset: countryCode.length),
      );
    }

    if (!newText.startsWith(countryCode)) {
      final phoneNumber = newText.replaceAll(RegExp(r'^\+?\d+\s*'), '');
      return TextEditingValue(
        text: countryCode + phoneNumber,
        selection: TextSelection.collapsed(
          offset: countryCode.length + phoneNumber.length,
        ),
      );
    }

    final selection = newValue.selection;
    if (selection.start < countryCode.length) {
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: countryCode.length),
      );
    }

    return newValue;
  }
}
