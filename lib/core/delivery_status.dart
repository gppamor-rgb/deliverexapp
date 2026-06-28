const deliveryStatusAssigned = 'assigned';
const deliveryStatusEnRouteToPickup = 'en_route_to_pickup';
const deliveryStatusArrivedAtPickup = 'arrived_at_pickup';
const deliveryStatusEnRouteToDestination = 'en_route_to_destination';
const deliveryStatusArrived = 'arrived';
const deliveryStatusCompleted = 'completed';
const deliveryStatusCancelled = 'cancelled';

const deliveryStatusLifecycle = [
  deliveryStatusAssigned,
  deliveryStatusEnRouteToPickup,
  deliveryStatusArrivedAtPickup,
  deliveryStatusEnRouteToDestination,
  deliveryStatusArrived,
  deliveryStatusCompleted,
];

String? canonicalDeliveryStatus(String? status) {
  final value = status?.trim().toLowerCase() ?? '';
  return switch (value) {
    'assigned' || 'dispatched' || 'pending' => deliveryStatusAssigned,
    'en_route_to_pickup' ||
    'en route to pickup' => deliveryStatusEnRouteToPickup,
    'arrived_at_pickup' || 'arrived at pickup' => deliveryStatusArrivedAtPickup,
    'en_route_to_destination' ||
    'en route to destination' ||
    'in_progress' ||
    'en_route' ||
    'en route' => deliveryStatusEnRouteToDestination,
    'arrived' => deliveryStatusArrived,
    'completed' ||
    'delivered' ||
    'completed_with_pod' => deliveryStatusCompleted,
    'cancelled' || 'canceled' => deliveryStatusCancelled,
    _ => null,
  };
}

String deliveryStatusLabel(String status) {
  final canonical = canonicalDeliveryStatus(status);
  return switch (canonical) {
    deliveryStatusAssigned => 'Assigned',
    deliveryStatusEnRouteToPickup => 'En Route to Pickup',
    deliveryStatusArrivedAtPickup => 'Arrived at Pickup',
    deliveryStatusEnRouteToDestination => 'En Route to Destination',
    deliveryStatusArrived => 'Arrived',
    deliveryStatusCompleted => 'Completed',
    deliveryStatusCancelled => 'Cancelled',
    _ => status.trim().isEmpty ? '—' : _titleize(status),
  };
}

bool isPendingDeliveryStatus(String status) {
  return canonicalDeliveryStatus(status) == deliveryStatusAssigned;
}

bool isActiveDeliveryStatus(String status) {
  return switch (canonicalDeliveryStatus(status)) {
    deliveryStatusAssigned ||
    deliveryStatusEnRouteToPickup ||
    deliveryStatusArrivedAtPickup ||
    deliveryStatusEnRouteToDestination ||
    deliveryStatusArrived => true,
    _ => false,
  };
}

String? nextDeliveryStatus(String status) {
  return switch (canonicalDeliveryStatus(status)) {
    deliveryStatusAssigned => deliveryStatusEnRouteToPickup,
    deliveryStatusEnRouteToPickup => deliveryStatusArrivedAtPickup,
    deliveryStatusArrivedAtPickup => deliveryStatusEnRouteToDestination,
    deliveryStatusEnRouteToDestination => deliveryStatusArrived,
    deliveryStatusArrived => deliveryStatusCompleted,
    _ => null,
  };
}

String deliveryActionLabel(String status) {
  return switch (canonicalDeliveryStatus(status)) {
    deliveryStatusAssigned => 'Start Pickup',
    deliveryStatusEnRouteToPickup => 'Arrived at Pickup',
    deliveryStatusArrivedAtPickup => 'Start Delivery',
    deliveryStatusEnRouteToDestination => 'Arrived',
    deliveryStatusArrived => 'Complete Delivery',
    deliveryStatusCompleted => 'Completed',
    deliveryStatusCancelled => 'Cancelled',
    _ => 'No status action',
  };
}

bool deliveryStatusRequiresLocation(String status) {
  return switch (canonicalDeliveryStatus(status)) {
    deliveryStatusEnRouteToPickup || deliveryStatusArrived => true,
    _ => false,
  };
}

int deliveryStatusIndex(String status) {
  final canonical = canonicalDeliveryStatus(status);
  final index = deliveryStatusLifecycle.indexOf(canonical ?? '');
  return index < 0 ? 0 : index;
}

String _titleize(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
