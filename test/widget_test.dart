import 'package:deliverex/app/deliverex_driver_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows splash screen then start screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeliverexDriverApp());

    expect(find.text('DELIVEREX'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Deliverex'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('or continue without an account'), findsOneWidget);
    expect(find.text('Track a Delivery'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Chatbot'), findsNothing);
  });

  testWidgets('opens the tracking screen from the start screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeliverexDriverApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    await tester.ensureVisible(find.text('Track a Delivery'));
    await tester.tap(find.text('Track a Delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Track your delivery'), findsOneWidget);
    expect(find.text('Tracking ID'), findsOneWidget);
  });

  testWidgets('opens the sign up screen from the start screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeliverexDriverApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create customer account'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
  });

  testWidgets('validates empty sign in fields', (WidgetTester tester) async {
    await tester.pumpWidget(const DeliverexDriverApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });
}
