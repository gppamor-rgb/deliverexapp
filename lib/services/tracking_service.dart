import 'package:dio/dio.dart';

import '../models/delivery_tracking_result.dart';
import 'api_client.dart';

class TrackingService {
  TrackingService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<DeliveryTrackingResult> lookup(String trackingCode) async {
    final code = trackingCode.trim();
    if (code.isEmpty) {
      throw const TrackingLookupException('Enter a tracking ID.');
    }

    final attempts = <_LookupAttempt>[
      _LookupAttempt('/tracking/$code'),
      _LookupAttempt('/tracking', {'tracking_code': code}),
      _LookupAttempt('/tracking', {'tracking_id': code}),
      _LookupAttempt('/tracking', {'code': code}),
      _LookupAttempt('/customer/tracking/$code'),
      _LookupAttempt('/customer/track/$code'),
      _LookupAttempt('/customer/tracking', {'tracking_code': code}),
      _LookupAttempt('/customer/tracking', {'tracking_id': code}),
      _LookupAttempt('/public/tracking/$code'),
    ];

    DioException? lastError;

    for (final attempt in attempts) {
      try {
        final response = await _apiClient.dio.get<dynamic>(
          attempt.path,
          queryParameters: attempt.queryParameters,
          options: Options(headers: {'Accept': 'application/json'}),
        );
        final result = DeliveryTrackingResult.fromJson(response.data);
        if (result.trackingCode.isNotEmpty || result.status.isNotEmpty) {
          return result;
        }
      } on DioException catch (error) {
        lastError = error;
      }
    }

    throw TrackingLookupException(_messageFrom(lastError, code));
  }

  String _messageFrom(DioException? error, String trackingCode) {
    final backendMessage = _extractBackendMessage(error?.response?.data);
    if (backendMessage.isNotEmpty) {
      return backendMessage;
    }

    if (error?.response?.statusCode == 404) {
      return 'No delivery matched "$trackingCode".';
    }

    return 'Unable to load tracking details right now.';
  }

  String _extractBackendMessage(dynamic data) {
    if (data is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      final nested = data['data'];
      if (nested != null && nested != data) {
        return _extractBackendMessage(nested);
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return '';
  }
}

class TrackingLookupException implements Exception {
  const TrackingLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _LookupAttempt {
  const _LookupAttempt(this.path, [this.queryParameters = const {}]);

  final String path;
  final Map<String, dynamic> queryParameters;
}
