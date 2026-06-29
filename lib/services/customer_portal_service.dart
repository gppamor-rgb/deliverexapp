import 'package:dio/dio.dart';

import '../models/customer_portal_order.dart';
import 'api_client.dart';
import 'session_service.dart';

class CustomerPortalService {
  CustomerPortalService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final _sessionService = SessionService.instance;

  Future<List<CustomerPortalOrder>> fetchOrders() async {
    final response = await _apiClient.dio.get<dynamic>(
      '/customer/portal/orders',
      options: await _customerOptions(),
    );
    return customerPortalOrdersFromResponse(
      response.data,
    ).where((order) => !order.isCancelled).toList();
  }

  Future<String> linkDelivery(String trackingCode) async {
    final code = trackingCode.trim();
    if (code.isEmpty) {
      throw const CustomerPortalException('Enter a Tracking ID.');
    }

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/customer/portal/link-delivery',
        data: {'tracking_code': code},
        options: await _customerOptions(),
      );
      return _messageFromResponse(
        response.data,
      ).ifBlank('Delivery linked successfully.');
    } on DioException catch (error) {
      throw CustomerPortalException(_messageFromDio(error));
    }
  }

  Future<String> submitInquiry({
    required String name,
    required String email,
    String? phone,
    String inquiryType = 'general_question',
    required String subject,
    required String message,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/customer/inquiry',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone?.trim() ?? '',
          'inquiry_type': inquiryType.trim(),
          'subject': subject.trim(),
          'message': message.trim(),
        },
        options: await _customerOptions(),
      );
      return _messageFromResponse(
        response.data,
      ).ifBlank('Inquiry submitted successfully.');
    } on DioException catch (error) {
      throw CustomerPortalException(_messageFromDio(error));
    }
  }

  Future<Options> _customerOptions() async {
    final token = await _sessionService.validAccessToken(
      role: MobileSessionRole.customer,
      dio: _apiClient.dio,
    );
    return Options(
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      extra: const {'sessionRole': 'customer'},
    );
  }

  String _messageFromDio(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Check your internet connection.';
    }

    final response = error.response;
    if (response?.statusCode == 401 || response?.statusCode == 419) {
      return SessionService.sessionExpiredMessage();
    }
    final backend = _messageFromResponse(response?.data);
    if (backend.isNotEmpty) return backend;
    if (response != null) {
      return 'Server error (${response.statusCode}). Please try again.';
    }
    return 'Unable to link delivery. Please try again.';
  }

  String _messageFromResponse(dynamic data) {
    if (data is Map) {
      final message = data['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
      final error = data['error']?.toString().trim() ?? '';
      if (error.isNotEmpty) return error;
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return '';
  }
}

class CustomerPortalException implements Exception {
  const CustomerPortalException(this.message);

  final String message;
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : trim();
}
