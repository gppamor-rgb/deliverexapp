import 'package:flutter/foundation.dart';

import '../core/formatters.dart';

class DriverAssignment {
  const DriverAssignment(this.raw);

  final Map<String, dynamic> raw;

  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(json);
  }

  String get id => _string(raw['id']);
  String get jobOrderId => _string(raw['job_order_id']);
  String get status => _string(raw['status']);
  String get statusLabel => driverStatusLabel(status);
  Map<String, dynamic> get jobOrder => _map(raw['job_order']);
  Map<String, dynamic> get vehicle => _map(raw['vehicle']);
  List<Map<String, dynamic>> get statusLogs =>
      _list(raw['delivery_status_logs']);
  List<Map<String, dynamic>> get trackingLogs => _list(raw['tracking_logs']);
  bool get hasCompletionProof => raw['completion_proof'] != null;

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isPending => status == 'assigned' || status == 'dispatched';
  bool get isActive =>
      status == 'in_progress' || status == 'en_route' || status == 'arrived';

  String get displayJobNumber => getDisplayJobNumber(this);
  String get publicId => displayJobNumber;
  String get displayName => buildDisplayName(jobOrder).ifBlank('—');
  String get clientEmail => buildClientEmail(jobOrder).ifBlank('—');
  String get pickupAddress =>
      buildDisplayAddress('pickup', jobOrder).ifBlank('—');
  String get dropoffAddress =>
      buildDisplayAddress('dropoff', jobOrder).ifBlank('—');
  String get schedule => formatJobSchedule(jobOrder);
  String get trackingCode => _string(jobOrder['tracking_code']).ifBlank('—');
  double? get dropoffLatitude => _firstDouble([
    jobOrder['dropoff_latitude'],
    jobOrder['dropoff_lat'],
    jobOrder['destination_latitude'],
    jobOrder['latitude'],
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['latitude'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lat'] : null,
  ]);
  double? get dropoffLongitude => _firstDouble([
    jobOrder['dropoff_longitude'],
    jobOrder['dropoff_lng'],
    jobOrder['dropoff_lon'],
    jobOrder['destination_longitude'],
    jobOrder['longitude'],
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['longitude'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lng'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lon'] : null,
  ]);
  String get vehicleLabel {
    final plate = _string(vehicle['plate_no']);
    final type = _string(vehicle['type']).ifBlank('—');
    if (plate.isEmpty) {
      return type;
    }
    return '$plate · $type';
  }

  String get notes {
    return [
      _string(jobOrder['notes']),
      _string(jobOrder['job_requirements']),
      _string(jobOrder['material_details']),
      _string(jobOrder['load_details']),
    ].where((value) => value.isNotEmpty).join('\n');
  }

  Map<String, dynamic>? get latestTracking {
    if (trackingLogs.isEmpty) {
      return null;
    }
    final logs = [...trackingLogs];
    logs.sort(
      (a, b) => _string(b['captured_at']).compareTo(_string(a['captured_at'])),
    );
    return logs.first;
  }

  String? get lastUpdated {
    final value = _string(raw['updated_at']);
    if (value.isEmpty) {
      return null;
    }
    return formatDeliverexDateTime(value);
  }
}

String getDisplayJobNumber(DriverAssignment assignment) {
  final selected = _firstNamedString({
    'job_order.public_id': assignment.jobOrder['public_id'],
    'job_order.job_number': assignment.jobOrder['job_number'],
    'job_order.job_order_number': assignment.jobOrder['job_order_number'],
    'job_order.order_number': assignment.jobOrder['order_number'],
    'job_order.reference_no': assignment.jobOrder['reference_no'],
  });

  if (kDebugMode) {
    debugPrint('Deliverex job_order raw: ${assignment.jobOrder}');
    if (selected != null) {
      debugPrint(
        'Deliverex selected job number field: ${selected.$1}=${selected.$2}',
      );
    } else {
      debugPrint('Deliverex selected job number field: none');
    }
  }

  if (selected != null) {
    return selected.$2;
  }

  final jobOrderId = _string(
    assignment.jobOrder['id'],
  ).ifBlank(assignment.jobOrderId);
  if (jobOrderId.isNotEmpty) {
    final formatted = formatJobPublicId(
      jobOrderId,
      _scheduledYear(assignment.jobOrder),
    );
    if (kDebugMode) {
      debugPrint(
        'Deliverex selected job number field: job_order.id/job_order_id=$jobOrderId formatted=$formatted',
      );
    }
    return formatted;
  }
  return '—';
}

String formatJobPublicId(dynamic id, int year) {
  final idText = _string(id);
  if (idText.isEmpty) {
    return '—';
  }
  final numericId = int.tryParse(idText);
  final padded = numericId == null
      ? idText
      : numericId.toString().padLeft(3, '0');
  return 'J-$year-$padded';
}

int _scheduledYear(Map<String, dynamic> job) {
  final scheduled = _string(job['scheduled_start']);
  final parsed = DateTime.tryParse(scheduled);
  return parsed?.toLocal().year ?? DateTime.now().year;
}

String driverStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'in_progress' => 'En Route',
    'en_route' => 'En Route',
    'dispatched' => 'Dispatched',
    'arrived' => 'Arrived',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    'assigned' => 'Assigned',
    _ => status.trim().isEmpty ? '—' : _titleize(status),
  };
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

class DriverAssignmentsPage {
  const DriverAssignmentsPage({required this.assignments});

  final List<DriverAssignment> assignments;

  factory DriverAssignmentsPage.fromJson(dynamic json) {
    final list = _extractList(json);
    return DriverAssignmentsPage(
      assignments: list
          .whereType<Map>()
          .map(
            (item) =>
                DriverAssignment.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class DriverProfile {
  const DriverProfile(this.raw);

  final Map<String, dynamic> raw;

  factory DriverProfile.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return DriverProfile(json);
    }
    if (json is Map) {
      return DriverProfile(Map<String, dynamic>.from(json));
    }
    return const DriverProfile({});
  }

  Map<String, dynamic> get vehicle {
    final driver = _map(raw['driver']);
    return _map(
      raw['vehicle'] ??
          driver['vehicle'] ??
          _map(raw['current_assignment'])['vehicle'],
    );
  }

  Map<String, dynamic> get driver =>
      _map(raw['driver']).isEmpty ? raw : _map(raw['driver']);
}

class DriverStats {
  const DriverStats({
    required this.jobsToday,
    required this.pending,
    required this.completed,
  });

  final int jobsToday;
  final int pending;
  final int completed;

  factory DriverStats.fromAssignments(List<DriverAssignment> assignments) {
    final now = DateTime.now();
    final today = assignments.where((assignment) {
      final scheduled = _string(assignment.jobOrder['scheduled_start']);
      if (scheduled.isEmpty) {
        return assignment.isActive || assignment.isPending;
      }
      final date = DateTime.tryParse(scheduled)?.toLocal();
      if (date == null) {
        return assignment.isActive || assignment.isPending;
      }
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;

    return DriverStats(
      jobsToday: today,
      pending: assignments
          .where((assignment) => assignment.isActive || assignment.isPending)
          .length,
      completed: assignments
          .where((assignment) => assignment.isCompleted)
          .length,
    );
  }
}

String formatJobSchedule(Map<String, dynamic> job) {
  final start = _string(job['scheduled_start']);
  final end = _string(job['scheduled_end']);
  final startLabel = formatDeliverexDateTime(start);
  if (end.isEmpty) {
    return startLabel;
  }
  final endLabel = formatDeliverexDateTime(end);
  return '$startLabel - $endLabel';
}

String buildDisplayName(Map<String, dynamic> job) {
  final selected = _firstNamedString({
    'job_order.customer.name': job['customer'] is Map
        ? _map(job['customer'])['name']
        : null,
    'job_order.client.name': job['client'] is Map
        ? _map(job['client'])['name']
        : null,
    'job_order.customer_name': job['customer_name'],
    'job_order.client_name': job['client_name'],
  });
  final name = selected?.$2 ?? '';
  if (kDebugMode) {
    debugPrint(
      'Deliverex selected client name field: ${selected?.$1 ?? 'none'}=$name',
    );
  }
  return name;
}

String buildClientEmail(Map<String, dynamic> job) {
  final selected = _firstNamedString({
    'job_order.customer.email': job['customer'] is Map
        ? _map(job['customer'])['email']
        : null,
    'job_order.client.email': job['client'] is Map
        ? _map(job['client'])['email']
        : null,
    'job_order.customer_email': job['customer_email'],
    'job_order.client_email': job['client_email'],
    'job_order.contact_email': job['contact_email'],
  });

  final email = selected?.$2 ?? '';
  if (kDebugMode) {
    debugPrint(
      'Deliverex selected client email field: ${selected?.$1 ?? 'none'}=$email',
    );
  }
  return email;
}

(String, String)? _firstNamedString(Map<String, dynamic> values) {
  for (final entry in values.entries) {
    final value = _string(entry.value);
    if (value.isNotEmpty) {
      return (entry.key, value);
    }
  }
  return null;
}

String buildDisplayAddress(String prefix, Map<String, dynamic> job) {
  return _firstString([
    job['${prefix}_address'],
    job['${prefix}_location'],
    job['${prefix}_name'],
    job[prefix] is Map ? _map(job[prefix])['address'] : null,
    job[prefix] is Map ? _map(job[prefix])['location'] : null,
  ]);
}

List<dynamic> _extractList(dynamic json) {
  if (json is List) {
    return json;
  }
  if (json is Map) {
    final data = json['data'];
    if (data is List) {
      return data;
    }
    if (data is Map && data['data'] is List) {
      return data['data'] as List;
    }
    if (json['assignments'] is List) {
      return json['assignments'] as List;
    }
  }
  return const [];
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final string = _string(value);
    if (string.isNotEmpty) {
      return string;
    }
  }
  return '';
}

String _string(dynamic value) => value?.toString().trim() ?? '';

double? _firstDouble(List<dynamic> values) {
  for (final value in values) {
    if (value is num) {
      return value.toDouble();
    }
    final parsed = double.tryParse(_string(value));
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

extension BlankString on String {
  String ifBlank(String fallback) => isEmpty ? fallback : this;
}
