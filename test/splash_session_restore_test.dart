import 'package:deliverex/models/driver_user.dart';
import 'package:deliverex/screens/driver_change_password_screen.dart';
import 'package:deliverex/screens/splash_screen.dart';
import 'package:deliverex/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.result);

  final SessionRestoreResult? result;

  @override
  Future<SessionRestoreResult?> restoreSession() async {
    return result;
  }
}

void main() {
  testWidgets('opens start screen when no saved session is restored', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: _FakeAuthService(null),
          startRouteBuilder: (_) => const Text('Start fallback'),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Start fallback'), findsOneWidget);
  });

  testWidgets('restores driver session to driver shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: _FakeAuthService(
            const SessionRestoreResult(
              token: 'driver-token',
              user: DriverUser(
                id: '1',
                name: 'Driver User',
                email: 'driver@example.com',
                roleName: 'driver',
              ),
            ),
          ),
          sessionRouteBuilder: (_, restored) =>
              Text(restored.isDriver ? 'Restored driver' : 'Restored customer'),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Restored driver'), findsOneWidget);
  });

  testWidgets('restores customer session to customer shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: _FakeAuthService(
            const SessionRestoreResult(
              token: 'customer-token',
              user: DriverUser(
                id: '2',
                name: 'Customer User',
                email: 'customer@example.com',
                roleName: 'customer',
              ),
            ),
          ),
          sessionRouteBuilder: (_, restored) =>
              Text(restored.isDriver ? 'Restored driver' : 'Restored customer'),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Restored customer'), findsOneWidget);
  });

  testWidgets('restored driver requiring password change opens password gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: _FakeAuthService(
            const SessionRestoreResult(
              token: 'driver-token',
              user: DriverUser(
                id: '3',
                name: 'New Driver',
                email: 'new-driver@example.com',
                roleName: 'driver',
                mustChangePassword: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(DriverChangePasswordScreen), findsOneWidget);
    expect(find.text('Create new password'), findsOneWidget);
  });

  testWidgets(
    'offline restored driver requiring password change shows notice',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            authService: _FakeAuthService(
              const SessionRestoreResult(
                token: 'driver-token',
                restoredOffline: true,
                user: DriverUser(
                  id: '4',
                  name: 'Offline Driver',
                  email: 'offline-driver@example.com',
                  roleName: 'driver',
                  mustChangePassword: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(DriverChangePasswordScreen), findsOneWidget);
      expect(
        find.textContaining('Internet connection is required'),
        findsOneWidget,
      );
    },
  );
}
