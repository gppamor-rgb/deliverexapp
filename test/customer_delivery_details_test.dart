import 'package:deliverex/models/customer_portal_order.dart';
import 'package:deliverex/screens/customer_delivery_details_sheet.dart';
import 'package:deliverex/screens/customer_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final order = CustomerPortalOrder.fromJson({
    'tracking_code': 'VGAKWMHXQG',
    'status': 'en_route_to_pickup',
    'priority': 'Urgent',
    'scheduled_start': '2026-07-01T04:19:00.000000Z',
    'job_order': {
      'pickup_location': 'SOLID / J.C. Rodriguez Construction Corp.',
      'dropoff_location': 'J Barlin St. Manila',
    },
  });

  testWidgets('delivery card opens details bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomerOrderCard(order: order)),
      ),
    );

    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('DELIVERY DETAILS'), findsOneWidget);
    expect(find.text('DELIVERY PROGRESS'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('ROUTE'), findsOneWidget);
    expect(find.text('Track Shipment'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('details sheet returns track request', (tester) async {
    bool? shouldTrack;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    shouldTrack = await showCustomerDeliveryDetailsSheet(
                      context,
                      order: order,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track Shipment'));
    await tester.pumpAndSettle();

    expect(shouldTrack, isTrue);
  });
}
