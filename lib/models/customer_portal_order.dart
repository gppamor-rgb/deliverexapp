import '../core/delivery_status.dart';
import '../core/formatters.dart';
import 'driver_assignment.dart';

class CustomerPortalOrder {
  const CustomerPortalOrder(this.raw);

  final Map<String, dynamic> raw;

  factory CustomerPortalOrder.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return CustomerPortalOrder(json);
    }
    if (json is Map) {
      return CustomerPortalOrder(Map<String, dynamic>.from(json));
    }
    return const CustomerPortalOrder({});
  }

  Map<String, dynamic> get jobOrder {
    final value = raw['job_order'] ?? raw['jobOrder'] ?? raw['order'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String get id =>
      _firstString([raw['id'], raw['assignment_id'], jobOrder['id']]);

  String get trackingCode => _firstString([
    raw['tracking_code'],
    raw['tracking_id'],
    raw['public_id'],
    jobOrder['tracking_code'],
    jobOrder['tracking_id'],
    jobOrder['public_id'],
  ]);

  String get status => _firstString([
    raw['status'],
    raw['delivery_status'],
    raw['current_status'],
    jobOrder['status'],
  ]);

  String get statusLabel => status.isEmpty ? '-' : deliveryStatusLabel(status);

  String get pickupAddress => _firstString([
    raw['pickup_address'],
    raw['pickup_location'],
    jobOrder['pickup_address'],
    jobOrder['pickup_location'],
    jobOrder['pickup_name'],
  ]).ifBlankLocal('-');

  String get dropoffAddress => _firstString([
    raw['dropoff_address'],
    raw['dropoff_location'],
    raw['destination'],
    jobOrder['dropoff_address'],
    jobOrder['dropoff_location'],
    jobOrder['dropoff_name'],
  ]).ifBlankLocal('-');

  String get schedule => formatJobSchedule(jobOrder.isEmpty ? raw : jobOrder);

  String get priority => _firstString([
    raw['priority'],
    raw['delivery_priority'],
    jobOrder['priority'],
    jobOrder['delivery_priority'],
  ]).ifBlankLocal('-');

  String get scheduledStart {
    final value = _firstString([
      raw['scheduled_start'],
      raw['schedule_start'],
      raw['start_date'],
      raw['pickup_schedule'],
      jobOrder['scheduled_start'],
      jobOrder['schedule_start'],
      jobOrder['start_date'],
      jobOrder['pickup_schedule'],
    ]);
    return value.isEmpty ? '-' : formatDeliverexDateTime(value);
  }

  String get scheduledEnd {
    final value = _firstString([
      raw['scheduled_end'],
      raw['schedule_end'],
      raw['end_date'],
      raw['delivery_schedule'],
      jobOrder['scheduled_end'],
      jobOrder['schedule_end'],
      jobOrder['end_date'],
      jobOrder['delivery_schedule'],
    ]);
    return value.isEmpty ? '-' : formatDeliverexDateTime(value);
  }

  String get vehicleLabel {
    final vehicle = _map(raw['vehicle']).isNotEmpty
        ? _map(raw['vehicle'])
        : _map(jobOrder['vehicle']);
    final plate = _firstString([
      raw['vehicle_plate'],
      raw['plate_no'],
      vehicle['plate_no'],
      vehicle['plate_number'],
    ]);
    final type = _firstString([
      raw['vehicle_type'],
      vehicle['type'],
      vehicle['vehicle_type'],
    ]);
    if (plate.isEmpty && type.isEmpty) return '-';
    if (plate.isEmpty) return type;
    if (type.isEmpty) return plate;
    return '$plate - $type';
  }

  bool get isCompleted =>
      canonicalDeliveryStatus(status) == deliveryStatusCompleted;

  bool get isCancelled {
    final normalized = status.toLowerCase().trim();
    return normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'archived';
  }

  bool get isActive => !isCompleted && !isCancelled;
}

List<CustomerPortalOrder> customerPortalOrdersFromResponse(dynamic data) {
  final unwrapped = _unwrap(data);
  if (unwrapped is List) {
    return unwrapped.map(CustomerPortalOrder.fromJson).toList();
  }
  if (unwrapped is Map) {
    for (final key in [
      'orders',
      'deliveries',
      'assignments',
      'items',
      'data',
    ]) {
      final value = unwrapped[key];
      if (value is List) {
        return value.map(CustomerPortalOrder.fromJson).toList();
      }
    }
    return [CustomerPortalOrder.fromJson(unwrapped)];
  }
  return const [];
}

dynamic _unwrap(dynamic data) {
  if (data is Map) {
    for (final key in ['data', 'orders', 'deliveries', 'assignments']) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map && value != data) return value;
    }
  }
  return data;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

extension on String {
  String ifBlankLocal(String fallback) => isEmpty ? fallback : this;
}
