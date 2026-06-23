import 'package:deliverex/models/driver_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('treats missing role metadata as driver access', () {
    final user = DriverUser.fromJson({
      'id': 7,
      'name': 'Alex Driver',
      'email': 'alex@example.com',
    });

    expect(user.isDriver, isTrue);
  });

  test('recognizes common driver role labels', () {
    final user = DriverUser.fromJson({
      'id': 9,
      'name': 'Taylor Driver',
      'email': 'taylor@example.com',
      'role': {'name': 'Delivery Driver'},
    });

    expect(user.isDriver, isTrue);
  });

  test('still blocks obvious customer accounts', () {
    final user = DriverUser.fromJson({
      'id': 11,
      'name': 'Casey Customer',
      'email': 'casey@example.com',
      'role_name': 'customer',
    });

    expect(user.isDriver, isFalse);
  });
}
