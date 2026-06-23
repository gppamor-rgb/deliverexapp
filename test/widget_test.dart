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
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign Up as Customer'), findsOneWidget);
    expect(find.text('Track Delivery'), findsOneWidget);
  });

  testWidgets('opens the tracking screen from the start screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeliverexDriverApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    await tester.tap(find.text('Track Delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Track your delivery'), findsOneWidget);
    expect(find.text('Tracking ID'), findsOneWidget);
  });
}
