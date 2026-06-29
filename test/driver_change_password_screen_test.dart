import 'package:deliverex/models/driver_user.dart';
import 'package:deliverex/screens/driver_change_password_screen.dart';
import 'package:deliverex/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  String? currentPassword;
  String? password;
  String? passwordConfirmation;
  AuthException? error;
  var loggedOut = false;

  @override
  Future<DriverUser> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    this.currentPassword = currentPassword;
    this.password = password;
    this.passwordConfirmation = passwordConfirmation;
    final error = this.error;
    if (error != null) throw error;
    return const DriverUser(
      id: '1',
      name: 'Driver User',
      email: 'driver@example.com',
      roleName: 'driver',
      mustChangePassword: false,
    );
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

void main() {
  const user = DriverUser(
    id: '1',
    name: 'Driver User',
    email: 'driver@example.com',
    roleName: 'driver',
    mustChangePassword: true,
  );

  testWidgets('validates password change fields', (tester) async {
    final service = _FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: DriverChangePasswordScreen(user: user, authService: service),
      ),
    );

    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pump();

    expect(find.text('Current password is required.'), findsOneWidget);
    expect(find.text('New password is required.'), findsOneWidget);
    expect(find.text('Confirm your new password.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.enterText(find.byType(TextFormField).at(2), 'different123');
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pump();

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('successful password change returns updated driver', (
    tester,
  ) async {
    final service = _FakeAuthService();
    DriverUser? changedUser;

    await tester.pumpWidget(
      MaterialApp(
        home: DriverChangePasswordScreen(
          user: user,
          authService: service,
          onPasswordChanged: (user) => changedUser = user,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'temporary123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(service.currentPassword, 'temporary123');
    expect(service.password, 'newpass123');
    expect(service.passwordConfirmation, 'newpass123');
    expect(changedUser?.mustChangePassword, isFalse);
  });

  testWidgets('backend password error is displayed', (tester) async {
    final service = _FakeAuthService()
      ..error = const AuthException('Current password is incorrect.');

    await tester.pumpWidget(
      MaterialApp(
        home: DriverChangePasswordScreen(user: user, authService: service),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'wrongpass');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
  });

  testWidgets('offline restore shows internet-required notice', (tester) async {
    final service = _FakeAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: DriverChangePasswordScreen(
          user: user,
          restoredOffline: true,
          authService: service,
        ),
      ),
    );

    expect(
      find.textContaining('Internet connection is required'),
      findsOneWidget,
    );
  });
}
