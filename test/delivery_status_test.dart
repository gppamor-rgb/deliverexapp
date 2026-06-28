import 'package:deliverex/core/delivery_status.dart';
import 'package:deliverex/models/driver_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('labels backend delivery status lifecycle', () {
    expect(deliveryStatusLabel('assigned'), 'Assigned');
    expect(deliveryStatusLabel('en_route_to_pickup'), 'En Route to Pickup');
    expect(deliveryStatusLabel('arrived_at_pickup'), 'Arrived at Pickup');
    expect(
      deliveryStatusLabel('en_route_to_destination'),
      'En Route to Destination',
    );
    expect(deliveryStatusLabel('arrived'), 'Arrived');
    expect(deliveryStatusLabel('completed'), 'Completed');
  });

  test('keeps legacy status compatibility', () {
    expect(
      canonicalDeliveryStatus('in_progress'),
      deliveryStatusEnRouteToDestination,
    );
    expect(
      canonicalDeliveryStatus('en_route'),
      deliveryStatusEnRouteToDestination,
    );
    expect(canonicalDeliveryStatus('dispatched'), deliveryStatusAssigned);
  });

  test('maps status indexes for six-step timeline', () {
    expect(deliveryStatusIndex('assigned'), 0);
    expect(deliveryStatusIndex('en_route_to_pickup'), 1);
    expect(deliveryStatusIndex('arrived_at_pickup'), 2);
    expect(deliveryStatusIndex('en_route_to_destination'), 3);
    expect(deliveryStatusIndex('arrived'), 4);
    expect(deliveryStatusIndex('completed'), 5);
  });

  test('provides fallback next actions for backend lifecycle', () {
    expect(nextDeliveryStatus('assigned'), deliveryStatusEnRouteToPickup);
    expect(
      nextDeliveryStatus('en_route_to_pickup'),
      deliveryStatusArrivedAtPickup,
    );
    expect(
      nextDeliveryStatus('arrived_at_pickup'),
      deliveryStatusEnRouteToDestination,
    );
    expect(
      nextDeliveryStatus('en_route_to_destination'),
      deliveryStatusArrived,
    );
    expect(nextDeliveryStatus('arrived'), deliveryStatusCompleted);

    expect(deliveryActionLabel('assigned'), 'Start Pickup');
    expect(deliveryActionLabel('arrived_at_pickup'), 'Start Delivery');
    expect(deliveryActionLabel('arrived'), 'Complete Delivery');
  });

  test('requires GPS only for pickup start and final arrival', () {
    expect(deliveryStatusRequiresLocation('assigned'), isFalse);
    expect(deliveryStatusRequiresLocation('en_route_to_pickup'), isTrue);
    expect(deliveryStatusRequiresLocation('arrived_at_pickup'), isFalse);
    expect(deliveryStatusRequiresLocation('en_route_to_destination'), isFalse);
    expect(deliveryStatusRequiresLocation('arrived'), isTrue);
    expect(deliveryStatusRequiresLocation('completed'), isFalse);
  });

  test('driver assignment reads backend next status and allowed action', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'status': 'en_route_to_pickup',
      'next_status': 'arrived_at_pickup',
      'allowed_action': 'Arrived at Pickup',
    });

    expect(assignment.nextStatus, 'arrived_at_pickup');
    expect(assignment.allowedAction, 'Arrived at Pickup');
  });

  test('driver assignment falls back to local next status and action', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'status': 'arrived_at_pickup',
    });

    expect(assignment.nextStatus, deliveryStatusEnRouteToDestination);
    expect(assignment.allowedAction, 'Start Delivery');
  });

  test('new in-progress statuses are active', () {
    for (final status in [
      'assigned',
      'en_route_to_pickup',
      'arrived_at_pickup',
      'en_route_to_destination',
      'arrived',
    ]) {
      expect(isActiveDeliveryStatus(status), isTrue);
    }
    expect(isPendingDeliveryStatus('assigned'), isTrue);
    expect(isActiveDeliveryStatus('completed'), isFalse);
  });
}
