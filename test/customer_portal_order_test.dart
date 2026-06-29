import 'package:deliverex/models/customer_portal_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses customer portal orders from website-style response', () {
    final orders = customerPortalOrdersFromResponse({
      'data': {
        'orders': [
          {
            'id': 7,
            'status': 'en_route_to_destination',
            'job_order': {
              'tracking_code': 'T123',
              'pickup_location': 'Pickup Site',
              'dropoff_location': 'Drop-off Site',
            },
          },
        ],
      },
    });

    expect(orders, hasLength(1));
    expect(orders.single.trackingCode, 'T123');
    expect(orders.single.pickupAddress, 'Pickup Site');
    expect(orders.single.dropoffAddress, 'Drop-off Site');
    expect(orders.single.isActive, isTrue);
  });

  test('separates active and completed deliveries', () {
    final orders = customerPortalOrdersFromResponse([
      {'status': 'assigned', 'tracking_code': 'A'},
      {'status': 'completed', 'tracking_code': 'B'},
      {'status': 'cancelled', 'tracking_code': 'C'},
    ]);

    expect(orders.where((order) => order.isActive).map((o) => o.trackingCode), [
      'A',
    ]);
    expect(
      orders.where((order) => order.isCompleted).map((o) => o.trackingCode),
      ['B'],
    );
    expect(
      orders.where((order) => order.isCancelled).map((o) => o.trackingCode),
      ['C'],
    );
  });

  test('reads priority and schedule detail fields safely', () {
    final order = CustomerPortalOrder.fromJson({
      'priority': 'Urgent',
      'scheduled_start': '2026-07-01T04:19:00.000000Z',
      'job_order': {'scheduled_end': '2026-07-01T08:30:00.000000Z'},
    });

    expect(order.priority, 'Urgent');
    expect(order.scheduledStart, isNot('-'));
    expect(order.scheduledEnd, isNot('-'));
  });

  test('missing detail fields render placeholders', () {
    const order = CustomerPortalOrder({});

    expect(order.priority, '-');
    expect(order.scheduledStart, '-');
    expect(order.scheduledEnd, '-');
  });
}
