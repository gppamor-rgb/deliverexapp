import 'package:deliverex/models/delivery_tracking_result.dart';
import 'package:deliverex/screens/tracking_screen.dart';
import 'package:deliverex/services/tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTrackingService extends TrackingService {
  _FakeTrackingService(this.result);

  final DeliveryTrackingResult result;

  @override
  Future<DeliveryTrackingResult> lookup(String trackingCode) async {
    return result;
  }
}

void main() {
  testWidgets('shows tracking-focused result without customer or proof cards', (
    tester,
  ) async {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T9S7Z5EKWF',
      'status': 'en_route_to_destination',
      'customer_name': 'Hidden Customer',
      'job_order': {
        'pickup_location': 'Dream Rock Resources Philippines, Inc.',
        'dropoff_location': 'FEU Tech',
        'scheduled_end': '2026-06-28T22:18:00.000000Z',
      },
      'tracking_logs': [
        {
          'latitude': 14.6040792,
          'longitude': 120.9885911,
          'address': 'Near FEU Tech',
          'captured_at': '2026-06-28T10:00:00.000000Z',
        },
      ],
      'completion_proof': {'receiver_name': 'Receiver'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TrackingScreen(
          trackingService: _FakeTrackingService(result),
          showBackButton: false,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'T9S7Z5EKWF');
    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(find.text('Last Location'), findsOneWidget);
    expect(find.text('Near FEU Tech'), findsOneWidget);
    expect(find.text('Open Last Location'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.text('Route Details'), findsOneWidget);
    expect(find.text('Customer'), findsNothing);
    expect(find.text('Hidden Customer'), findsNothing);
    expect(find.text('Proof of delivery'), findsNothing);
    expect(find.text('Receiver'), findsNothing);
  });
}
