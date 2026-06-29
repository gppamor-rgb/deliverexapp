import 'package:deliverex/models/driver_user.dart';
import 'package:deliverex/screens/customer_support_screen.dart';
import 'package:deliverex/services/customer_portal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCustomerPortalService extends CustomerPortalService {
  Map<String, String?>? payload;
  CustomerPortalException? error;

  @override
  Future<String> submitInquiry({
    required String name,
    required String email,
    String? phone,
    String inquiryType = 'general_question',
    required String subject,
    required String message,
  }) async {
    final error = this.error;
    if (error != null) throw error;
    payload = {
      'name': name,
      'email': email,
      'phone': phone,
      'inquiry_type': inquiryType,
      'subject': subject,
      'message': message,
    };
    return 'Inquiry submitted successfully.';
  }
}

void main() {
  const user = DriverUser(
    id: '18',
    name: 'Brix Nunez Barillo',
    email: 'bruxpogi@gmail.com',
    roleName: 'customer',
  );

  Future<_FakeCustomerPortalService> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeCustomerPortalService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerSupportScreen(user: user, portalService: service),
        ),
      ),
    );
    return service;
  }

  testWidgets('renders inquiry form with prefilled read-only identity', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Submit an inquiry'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Brix Nunez Barillo'), findsOneWidget);
    expect(find.text('bruxpogi@gmail.com'), findsOneWidget);
    expect(find.text('+63'), findsOneWidget);

    final nameField = tester.widget<EditableText>(
      find.byType(EditableText).at(0),
    );
    final emailField = tester.widget<EditableText>(
      find.byType(EditableText).at(1),
    );
    expect(nameField.readOnly, isTrue);
    expect(emailField.readOnly, isTrue);
  });

  testWidgets('validates required subject and message fields', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Submit inquiry'));
    await tester.pump();

    expect(find.text('Subject is required.'), findsOneWidget);
    expect(find.text('Message is required.'), findsOneWidget);
  });

  testWidgets('validates partial optional phone field', (tester) async {
    final service = await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(2), '+63917');
    await tester.enterText(find.byType(TextFormField).at(3), 'Delivery help');
    await tester.enterText(find.byType(TextFormField).at(4), 'Please help.');
    await tester.tap(find.text('Submit inquiry'));
    await tester.pump();

    expect(service.payload, isNull);
    expect(
      find.text('Enter exactly 10 numeric digits after +63.'),
      findsOneWidget,
    );
  });

  testWidgets('submits inquiry and clears editable fields on success', (
    tester,
  ) async {
    final service = await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(2), '+639123456789');
    await tester.enterText(find.byType(TextFormField).at(3), 'Delivery help');
    await tester.enterText(find.byType(TextFormField).at(4), 'Please help.');
    await tester.tap(find.text('Submit inquiry'));
    await tester.pumpAndSettle();

    expect(service.payload, {
      'name': 'Brix Nunez Barillo',
      'email': 'bruxpogi@gmail.com',
      'phone': '+639123456789',
      'inquiry_type': 'general_question',
      'subject': 'Delivery help',
      'message': 'Please help.',
    });
    expect(find.text('Inquiry submitted successfully.'), findsOneWidget);
    expect(find.text('+63'), findsOneWidget);
    expect(find.text('Delivery help'), findsNothing);
    expect(find.text('Please help.'), findsNothing);
  });

  testWidgets('shows backend inquiry errors cleanly', (tester) async {
    final service = await pumpScreen(tester)
      ..error = const CustomerPortalException('Message is too short.');

    await tester.enterText(find.byType(TextFormField).at(3), 'Help');
    await tester.enterText(find.byType(TextFormField).at(4), 'Hi');
    await tester.tap(find.text('Submit inquiry'));
    await tester.pumpAndSettle();

    expect(service.payload, isNull);
    expect(find.text('Message is too short.'), findsOneWidget);
  });
}
