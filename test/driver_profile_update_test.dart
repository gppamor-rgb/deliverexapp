import 'package:deliverex/services/driver_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver profile update payload sends phone only', () {
    final body = driverProfileUpdateBody(phone: '  +639171234567  ');

    expect(body, {'phone': '+639171234567'});
    expect(body.containsKey('name'), isFalse);
  });
}
