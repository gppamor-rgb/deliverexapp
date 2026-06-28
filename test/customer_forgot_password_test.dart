import 'package:deliverex/screens/customer_forgot_password_screen.dart';
import 'package:deliverex/services/customer_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCustomerAuthService extends CustomerAuthService {
  String? email;

  @override
  Future<String> forgotPassword({required String email}) async {
    this.email = email;
    return 'If an account exists for that email, a reset link has been sent. Check your inbox and spam folder.';
  }
}

void main() {
  test('forgot password payload trims email', () {
    expect(forgotPasswordBody(email: '  customer@example.com  '), {
      'email': 'customer@example.com',
    });
  });

  test('forgot password success message falls back when backend is empty', () {
    expect(
      forgotPasswordSuccessMessage({}),
      'If an account exists for that email, a reset link has been sent. Check your inbox and spam folder.',
    );
  });

  testWidgets('forgot password validates email and shows success', (
    tester,
  ) async {
    final service = _FakeCustomerAuthService();

    await tester.pumpWidget(
      MaterialApp(home: CustomerForgotPasswordScreen(authService: service)),
    );

    expect(find.text('Reset customer password'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(
      find.text(
        'Drivers: please contact your administrator to reset your password.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Email is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      ' customer@example.com ',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pump();

    expect(service.email, ' customer@example.com ');
    expect(
      find.text(
        'If an account exists for that email, a reset link has been sent. Check your inbox and spam folder.',
      ),
      findsOneWidget,
    );
  });
}
