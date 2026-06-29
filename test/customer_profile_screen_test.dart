import 'dart:async';

import 'package:deliverex/models/driver_user.dart';
import 'package:deliverex/screens/customer_profile_screen.dart';
import 'package:deliverex/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SlowAuthService extends AuthService {
  final completer = Completer<void>();
  var logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await completer.future;
  }
}

void main() {
  const user = DriverUser(
    id: '18',
    name: 'Customer Profile',
    email: 'customer@example.com',
    roleName: 'customer',
  );

  testWidgets('customer profile uses light UI and account actions', (
    tester,
  ) async {
    Object? popResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<Object>(
                    MaterialPageRoute(
                      builder: (_) => const CustomerProfileScreen(user: user),
                    ),
                  );
                },
                child: const Text('Open Profile'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Profile'), findsWidgets);
    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('Link Delivery'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, isNot(Colors.black));

    await tester.tap(find.text('Link Delivery'));
    await tester.pumpAndSettle();

    expect(popResult, 'link');
  });

  testWidgets('customer logout matches driver loading label', (tester) async {
    final service = _SlowAuthService();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(user: user, authService: service),
      ),
    );

    final logoutButton = find.widgetWithText(OutlinedButton, 'Log Out');
    expect(logoutButton, findsOneWidget);

    final button = tester.widget<OutlinedButton>(logoutButton);
    expect(button.style?.foregroundColor?.resolve({}), isNotNull);

    await tester.tap(find.text('Log Out'));
    await tester.pump();

    expect(service.logoutCalled, isTrue);
    expect(find.text('Logging out...'), findsOneWidget);

    service.completer.complete();
    await tester.pumpAndSettle();
  });
}
