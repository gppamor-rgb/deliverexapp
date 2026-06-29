import 'package:deliverex/models/driver_user.dart';
import 'package:deliverex/screens/auth_gate.dart';
import 'package:deliverex/screens/customer_shell_screen.dart';
import 'package:deliverex/screens/driver_change_password_screen.dart';
import 'package:deliverex/screens/driver_shell_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver with mandatory password change opens password screen', () {
    final widget = authenticatedEntryFor(
      user: const DriverUser(
        id: '1',
        name: 'Driver User',
        email: 'driver@example.com',
        roleName: 'driver',
        mustChangePassword: true,
      ),
    );

    expect(widget, isA<DriverChangePasswordScreen>());
  });

  test('driver without mandatory password change opens driver shell', () {
    final widget = authenticatedEntryFor(
      user: const DriverUser(
        id: '1',
        name: 'Driver User',
        email: 'driver@example.com',
        roleName: 'driver',
      ),
    );

    expect(widget, isA<DriverShellScreen>());
  });

  test('customer bypasses driver password change gate', () {
    final widget = authenticatedEntryFor(
      user: const DriverUser(
        id: '2',
        name: 'Customer User',
        email: 'customer@example.com',
        roleName: 'customer',
        mustChangePassword: true,
      ),
    );

    expect(widget, isA<CustomerShellScreen>());
  });
}
