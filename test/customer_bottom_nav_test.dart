import 'package:deliverex/widgets/customer/customer_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses website-aligned customer module labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomerBottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Deliveries'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Services'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('My Deliveries'), findsNothing);
  });
}
