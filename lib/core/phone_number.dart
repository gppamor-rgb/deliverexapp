import 'package:flutter/services.dart';

const philippinePhonePrefix = '+63';
const philippinePhoneDigits = 10;

class PhilippinePhoneInputFormatter extends TextInputFormatter {
  const PhilippinePhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _localDigits(newValue.text);
    final text = '$philippinePhonePrefix$digits';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String normalizePhilippinePhoneInput(String value) {
  final digits = _localDigits(value);
  if (digits.isEmpty) return philippinePhonePrefix;
  return '$philippinePhonePrefix$digits';
}

String phonePayloadValue(String value) {
  final digits = _localDigits(value);
  if (digits.isEmpty) return '';
  return '$philippinePhonePrefix$digits';
}

String? validatePhilippinePhone(
  String? value, {
  bool required = true,
  String fieldName = 'Mobile number',
}) {
  final digits = _localDigits(value ?? '');
  if (digits.isEmpty) {
    return required ? '$fieldName is required.' : null;
  }
  if (digits.length != philippinePhoneDigits) {
    return 'Enter exactly 10 numeric digits after +63.';
  }
  return null;
}

String _localDigits(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('63')) {
    digits = digits.substring(2);
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length > philippinePhoneDigits) {
    digits = digits.substring(0, philippinePhoneDigits);
  }
  return digits;
}
