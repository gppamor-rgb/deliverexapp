import '../core/formatters.dart';
import '../core/delivery_status.dart';
import 'driver_assignment.dart';

class DeliveryTrackingResult {
  const DeliveryTrackingResult(this.raw);

  final Map<String, dynamic> raw;

  factory DeliveryTrackingResult.fromJson(dynamic json) {
    final normalized = _map(_unwrap(json));
    return DeliveryTrackingResult(normalized);
  }

  Map<String, dynamic> get _source {
    final candidates = [
      raw['delivery'],
      raw['assignment'],
      raw['tracking'],
      raw['data'],
      raw,
    ];

    for (final candidate in candidates) {
      final map = _map(candidate);
      if (map.isNotEmpty && _looksLikeTrackingPayload(map)) {
        return map;
      }
    }

    return raw;
  }

  Map<String, dynamic> get jobOrder {
    final source = _source;
    final nested = _map(source['job_order']);
    if (nested.isNotEmpty) {
      return nested;
    }
    return _map(raw['job_order']);
  }

  String get trackingCode => _firstString([
    _string(_source['tracking_code']),
    _string(_source['tracking_id']),
    _string(_source['public_id']),
    _string(jobOrder['tracking_code']),
    _string(jobOrder['public_id']),
    _string(jobOrder['job_number']),
    _string(jobOrder['reference_no']),
  ]);

  String get status => _firstString([
    _string(_source['status']),
    _string(raw['status']),
    _string(_source['current_status']),
  ]);

  String get statusLabel => status.isEmpty ? '—' : driverStatusLabel(status);

  String get customerName => _firstString([
    _string(_source['customer_name']),
    _string(jobOrder['customer_name']),
    _string(jobOrder['client_name']),
    jobOrder['customer'] is Map
        ? _string(_map(jobOrder['customer'])['name'])
        : null,
    jobOrder['client'] is Map
        ? _string(_map(jobOrder['client'])['name'])
        : null,
  ]);

  String get customerEmail => _firstString([
    _string(_source['customer_email']),
    _string(jobOrder['customer_email']),
    _string(jobOrder['client_email']),
    jobOrder['customer'] is Map
        ? _string(_map(jobOrder['customer'])['email'])
        : null,
    jobOrder['client'] is Map
        ? _string(_map(jobOrder['client'])['email'])
        : null,
  ]);

  String get pickupAddress => _firstString([
    _string(_source['pickup_address']),
    _string(jobOrder['pickup_address']),
    _string(jobOrder['pickup_location']),
    _string(jobOrder['pickup_name']),
  ]).ifBlank('—');

  String get dropoffAddress => _firstString([
    _string(_source['dropoff_address']),
    _string(jobOrder['dropoff_address']),
    _string(jobOrder['dropoff_location']),
    _string(jobOrder['dropoff_name']),
  ]).ifBlank('—');

  String get schedule =>
      formatJobSchedule(jobOrder.isEmpty ? _source : jobOrder);

  String get etaLabel =>
      _firstString([
        _string(_source['eta_window']),
        _string(_source['estimated_arrival']),
        _string(_source['estimated_delivery']),
        _string(_source['eta']),
        _string(jobOrder['scheduled_end']),
      ]).isEmpty
      ? _fallbackEtaLabel
      : _firstString([
          _string(_source['eta_window']),
          _string(_source['estimated_arrival']),
          _string(_source['estimated_delivery']),
          _string(_source['eta']),
          _string(jobOrder['scheduled_end']),
        ]);

  String get _fallbackEtaLabel {
    return switch (canonicalDeliveryStatus(status)) {
      deliveryStatusCompleted => 'Delivered',
      deliveryStatusArrived => 'Arriving now',
      deliveryStatusEnRouteToPickup => 'Heading to pickup',
      deliveryStatusArrivedAtPickup => 'At pickup',
      deliveryStatusEnRouteToDestination => 'In transit',
      _ => 'Live tracking',
    };
  }

  String? get lastUpdated {
    final value = _firstString([
      _source['updated_at'],
      _source['captured_at'],
      _source['timestamp'],
      raw['updated_at'],
    ]);
    if (value.isEmpty) {
      return null;
    }
    return formatDeliverexDateTime(value);
  }

  Map<String, dynamic>? get latestTracking {
    final logs = trackingLogs;
    if (logs.isEmpty) {
      return null;
    }

    final sorted = [...logs]
      ..sort((a, b) => _sortValue(b).compareTo(_sortValue(a)));
    return sorted.first;
  }

  TrackingLocation? get lastLocation {
    final approximateLocation = _trackingLocationFromMap(
      _map(_source['approximate_location']).isNotEmpty
          ? _map(_source['approximate_location'])
          : _map(raw['approximate_location']),
    );
    if (approximateLocation != null) {
      return approximateLocation;
    }

    final logLocation = _trackingLocationFromMap(latestTracking);
    if (logLocation != null) {
      return logLocation;
    }

    return _trackingLocationFromMap(_source) ??
        _trackingLocationFromMap(raw) ??
        _trackingLocationFromMap(jobOrder);
  }

  List<Map<String, dynamic>> get trackingLogs => _sortedLogs([
    ..._list(_source['tracking_logs']),
    ..._list(_source['status_logs']),
    ..._list(raw['tracking_logs']),
    ..._list(raw['status_logs']),
    ..._list(_source['events']),
    ..._list(raw['events']),
  ]);

  Map<String, dynamic>? get completionProof {
    final candidate = _map(_source['completion_proof']);
    if (candidate.isNotEmpty) {
      return candidate;
    }

    final proof = _map(raw['completion_proof']);
    if (proof.isNotEmpty) {
      return proof;
    }

    final documents = _list(_source['proof_documents']);
    if (documents.isNotEmpty) {
      return documents.first;
    }

    return null;
  }

  TrackingProofDocument? get proofDocument {
    for (final candidate in _proofDocumentCandidates) {
      final proof = TrackingProofDocument.fromJson(candidate);
      if (proof != null) {
        return proof;
      }
    }
    return null;
  }

  bool get hasProof => proofDocument != null;

  List<Map<String, dynamic>> get _proofDocumentCandidates {
    final candidates = <Map<String, dynamic>>[];

    for (final value in [
      _source['completion_proof'],
      raw['completion_proof'],
      _source['proof_document'],
      raw['proof_document'],
      _source['pod'],
      raw['pod'],
    ]) {
      final map = _map(value);
      if (map.isNotEmpty) {
        candidates.add(map);
      }
    }

    candidates.addAll(_list(_source['proof_documents']));
    candidates.addAll(_list(raw['proof_documents']));

    final documents = [
      ..._list(_source['documents']),
      ..._list(raw['documents']),
      ..._list(_source['delivery_documents']),
      ..._list(raw['delivery_documents']),
    ];
    candidates.addAll(documents.where(_isProofDocument));

    return candidates;
  }

  String get notes => _firstString([
    _string(_source['notes']),
    _string(jobOrder['notes']),
    _string(jobOrder['job_requirements']),
    _string(jobOrder['material_details']),
    _string(jobOrder['load_details']),
  ]);

  String get vehicleLabel {
    final vehicle = _map(_source['vehicle']).isNotEmpty
        ? _map(_source['vehicle'])
        : _map(raw['vehicle']);
    final plate = _string(vehicle['plate_no']);
    final displayType = _withFallback(_string(vehicle['type']), '—');
    if (plate.isEmpty) {
      return displayType;
    }
    return '$plate · $displayType';
  }

  double? get dropoffLatitude => _firstDouble([
    _source['dropoff_latitude'],
    _source['dropoff_lat'],
    _source['destination_latitude'],
    _source['latitude'],
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['latitude'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lat'] : null,
  ]);

  double? get dropoffLongitude => _firstDouble([
    _source['dropoff_longitude'],
    _source['dropoff_lng'],
    _source['dropoff_lon'],
    _source['destination_longitude'],
    _source['longitude'],
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['longitude'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lng'] : null,
    jobOrder['dropoff'] is Map ? _map(jobOrder['dropoff'])['lon'] : null,
  ]);
}

class TrackingProofDocument {
  const TrackingProofDocument({
    required this.id,
    required this.typeLabel,
    required this.submittedAt,
    required this.statusLabel,
    required this.fileUrl,
  });

  final String id;
  final String typeLabel;
  final String submittedAt;
  final String statusLabel;
  final String? fileUrl;

  bool get canView => fileUrl != null && fileUrl!.trim().isNotEmpty;

  static TrackingProofDocument? fromJson(Map<String, dynamic> json) {
    if (json.isEmpty || !_looksLikeProofDocument(json)) {
      return null;
    }

    final id = _firstString([
      json['id'],
      json['document_id'],
      json['delivery_document_id'],
      json['file_id'],
    ]);
    final rawType = _firstString([
      json['type_label'],
      json['document_type_label'],
      json['label'],
      json['name'],
      json['title'],
      json['type'],
      json['document_type'],
    ]);
    final submittedAt = _firstString([
      json['submitted_at'],
      json['uploaded_at'],
      json['completed_at'],
      json['created_at'],
      json['updated_at'],
    ]);
    final status = _firstString([
      json['status_label'],
      json['processing_status'],
      json['ocr_status'],
      json['status'],
      json['state'],
    ]);
    final fileUrl = _resolveProofFileUrl(json, id);

    return TrackingProofDocument(
      id: id,
      typeLabel: _proofTypeLabel(rawType),
      submittedAt: submittedAt.isEmpty
          ? '—'
          : formatDeliverexDateTime(submittedAt),
      statusLabel: status.isEmpty ? 'Available' : _proofStatusLabel(status),
      fileUrl: fileUrl,
    );
  }
}

bool _isProofDocument(Map<String, dynamic> value) {
  final type = _firstString([
    value['type'],
    value['document_type'],
    value['kind'],
    value['category'],
    value['name'],
    value['title'],
  ]).toLowerCase();
  return type == 'pod' ||
      type == 'proof_of_delivery' ||
      type.contains('proof of delivery') ||
      type.contains('delivery receipt');
}

bool _looksLikeProofDocument(Map<String, dynamic> value) {
  if (_isProofDocument(value)) {
    return true;
  }

  final hasFile = _firstString([
    value['file_url'],
    value['url'],
    value['download_url'],
    value['file_path'],
    value['path'],
    value['attachment_url'],
  ]).isNotEmpty;
  final hasDocumentId = _firstString([
    value['id'],
    value['document_id'],
    value['delivery_document_id'],
  ]).isNotEmpty;
  final hasProofKeys =
      value.containsKey('receiver_name') ||
      value.containsKey('proof_type') ||
      value.containsKey('completed_at');

  return hasFile || (hasDocumentId && hasProofKeys);
}

String _proofTypeLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'pod' || 'proof_of_delivery' => 'Proof of Delivery',
    'receipt' || 'delivery_receipt' => 'Delivery Receipt Photo',
    'invoice' => 'Invoice',
    'job_order' => 'Job Order',
    _ => value.trim().isEmpty ? 'Proof of Delivery' : value.trim(),
  };
}

String _proofStatusLabel(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return 'Available';
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String? _resolveProofFileUrl(Map<String, dynamic> value, String id) {
  final direct = _firstString([
    value['file_url'],
    value['url'],
    value['download_url'],
    value['view_url'],
    value['attachment_url'],
    value['public_url'],
  ]);
  final normalizedDirect = _normalizeProofUrl(direct);
  if (normalizedDirect != null) {
    return normalizedDirect;
  }

  final path = _firstString([
    value['file_path'],
    value['path'],
    value['storage_path'],
    value['document_path'],
  ]);
  final normalizedPath = _normalizeProofUrl(path);
  if (normalizedPath != null) {
    return normalizedPath;
  }

  if (id.isNotEmpty) {
    return 'https://deliverexapp.com/api/documents/$id/file';
  }

  return null;
}

String? _normalizeProofUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }

  if (trimmed.startsWith('/')) {
    return 'https://deliverexapp.com$trimmed';
  }

  if (trimmed.startsWith('storage/') || trimmed.startsWith('api/')) {
    return 'https://deliverexapp.com/$trimmed';
  }

  return 'https://deliverexapp.com/storage/$trimmed';
}

class TrackingLocation {
  const TrackingLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String? timestamp;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayText {
    if (address.isNotEmpty) {
      return address;
    }
    if (hasCoordinates) {
      return '${_formatCoordinate(latitude!)}, ${_formatCoordinate(longitude!)}';
    }
    return 'Last location unavailable';
  }
}

dynamic _unwrap(dynamic json) {
  if (json is Map) {
    final data = json['data'];
    if (data is Map || data is List) {
      return data;
    }
    for (final key in ['tracking', 'assignment', 'delivery', 'result']) {
      final nested = json[key];
      if (nested is Map || nested is List) {
        return nested;
      }
    }
    return json;
  }
  if (json is List && json.isNotEmpty) {
    return json.first;
  }
  return json;
}

List<Map<String, dynamic>> _sortedLogs(List<Map<String, dynamic>> logs) {
  final unique = <String, Map<String, dynamic>>{};
  for (final log in logs) {
    unique['${_sortValue(log)}|${log.hashCode}'] = log;
  }
  final sorted = unique.values.toList()
    ..sort((a, b) => _sortValue(b).compareTo(_sortValue(a)));
  return sorted;
}

String _sortValue(Map<String, dynamic> value) {
  return _firstString([
    value['captured_at'],
    value['created_at'],
    value['updated_at'],
    value['timestamp'],
    value['time'],
  ]);
}

bool _looksLikeTrackingPayload(Map<String, dynamic> value) {
  return value.containsKey('job_order') ||
      value.containsKey('tracking_logs') ||
      value.containsKey('status_logs') ||
      value.containsKey('approximate_location') ||
      value.containsKey('tracking_code') ||
      value.containsKey('status');
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

String _withFallback(String value, String fallback) {
  return value.isEmpty ? fallback : value;
}

TrackingLocation? _trackingLocationFromMap(Map<String, dynamic>? value) {
  final map = value ?? const {};
  if (map.isEmpty) {
    return null;
  }

  final address = _firstString([
    map['address'],
    map['location'],
    map['current_location'],
    map['formatted_address'],
    map['last_location'],
    map['last_known_location'],
  ]);
  final latitude = _firstDouble([
    map['latitude'],
    map['lat'],
    map['current_latitude'],
    map['last_latitude'],
    map['last_lat'],
  ]);
  final longitude = _firstDouble([
    map['longitude'],
    map['lng'],
    map['lon'],
    map['current_longitude'],
    map['last_longitude'],
    map['last_lng'],
    map['last_lon'],
  ]);
  final timestamp = _firstString([
    map['captured_at'],
    map['created_at'],
    map['updated_at'],
    map['timestamp'],
    map['time'],
  ]);

  if (address.isEmpty && latitude == null && longitude == null) {
    return null;
  }

  return TrackingLocation(
    address: address,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp.isEmpty ? null : formatDeliverexDateTime(timestamp),
  );
}

String _formatCoordinate(double value) => value.toStringAsFixed(6);
