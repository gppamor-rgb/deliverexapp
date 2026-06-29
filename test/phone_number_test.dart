import 'package:deliverex/core/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes stored phone values to +63 plus 10 digits', () {
    expect(normalizePhilippinePhoneInput(''), '+63');
    expect(normalizePhilippinePhoneInput('+639171234567'), '+639171234567');
    expect(normalizePhilippinePhoneInput('09171234567'), '+639171234567');
    expect(normalizePhilippinePhoneInput('9171234567'), '+639171234567');
  });

  test('formats input by keeping prefix and numeric local digits only', () {
    const formatter = PhilippinePhoneInputFormatter();

    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '+63'),
      const TextEditingValue(text: '+63abc9171234567xxx'),
    );

    expect(result.text, '+639171234567');
    expect(result.selection.baseOffset, result.text.length);
  });

  test('validates required and optional phone numbers', () {
    expect(validatePhilippinePhone('+63'), 'Mobile number is required.');
    expect(
      validatePhilippinePhone('+63917'),
      'Enter exactly 10 numeric digits after +63.',
    );
    expect(validatePhilippinePhone('+639171234567'), isNull);
    expect(validatePhilippinePhone('+63', required: false), isNull);
  });

  test('payload value returns blank for empty optional prefix', () {
    expect(phonePayloadValue('+63'), '');
    expect(phonePayloadValue('+639171234567'), '+639171234567');
  });
}
