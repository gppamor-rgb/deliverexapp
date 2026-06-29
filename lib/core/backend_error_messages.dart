import 'package:dio/dio.dart';

import '../services/session_service.dart';

String messageFromDioException(
  DioException error, {
  String fallback = 'Request failed. Please try again.',
  String? serverErrorMessage,
}) {
  final statusCode = error.response?.statusCode;
  if (serverErrorMessage != null && statusCode != null && statusCode >= 500) {
    return serverErrorMessage;
  }
  if (statusCode == 401 || statusCode == 419) {
    return SessionService.sessionExpiredMessage();
  }

  final data = error.response?.data;
  final parsed = messageFromResponseData(data);
  if (parsed.isNotEmpty) return parsed;
  return error.message?.trim().isNotEmpty == true ? error.message! : fallback;
}

String messageFromResponseData(dynamic data) {
  if (data is Map) {
    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          final message = value.first?.toString().trim() ?? '';
          if (message.isNotEmpty) return message;
        }
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    for (final key in ['message', 'error', 'detail']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
  }

  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  return '';
}
