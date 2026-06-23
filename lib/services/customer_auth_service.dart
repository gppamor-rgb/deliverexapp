import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/customer_user.dart';
import 'api_client.dart';

class CustomerAuthResult {
  const CustomerAuthResult({required this.token, required this.user});

  final String token;
  final CustomerUser user;
}

class CustomerAuthService {
  CustomerAuthService({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'deliverex_customer_token';
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  Future<CustomerAuthResult> register({
    required String firstName,
    String? middleName,
    required String lastName,
    required String email,
    String? mobile,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final body = <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
      if (middleName != null && middleName.trim().isNotEmpty) {
        body['middle_name'] = middleName.trim();
      }
      body['name'] = [
        firstName.trim(),
        if (middleName != null && middleName.trim().isNotEmpty) middleName.trim(),
        lastName.trim(),
      ].join(' ');
      body['mobile'] = mobile?.trim() ?? '';

      final response = await _apiClient.dio.post<dynamic>(
        '/auth/register/customer',
        data: body,
      );
      final data = _ensureMap(response.data);
      if (kDebugMode) {
        debugPrint('Deliverex register response data: $data');
      }

      final token = _firstString([
        data['token'],
        data['access_token'],
        data['api_token'],
      ]);

      Map<String, dynamic> userJson = _extractUser(data);
      if (userJson.isEmpty && data.containsKey('data')) {
        final nested = data['data'];
        if (nested is Map) {
          userJson = _extractUser(Map<String, dynamic>.from(nested));
        }
      }

      final user = CustomerUser.fromJson(userJson);

      if (token.isNotEmpty) {
        await _storage.write(key: tokenKey, value: token);
      }

      return CustomerAuthResult(token: token, user: user);
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint('Deliverex register DioException: ${error.type}');
      }
      throw AuthException(_messageFromDio(error));
    }
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> data) {
    final candidates = [
      data['user'],
      data['customer'],
      data['account'],
      data['data'] is Map ? (data['data'] as Map)['user'] : null,
      data['data'] is Map ? (data['data'] as Map)['customer'] : null,
      data,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        if (candidate.containsKey('email') ||
            candidate.containsKey('first_name') ||
            candidate.containsKey('last_name')) {
          return candidate;
        }
      }
      if (candidate is Map) {
        final map = Map<String, dynamic>.from(candidate);
        if (map.containsKey('email') ||
            map.containsKey('first_name') ||
            map.containsKey('last_name')) {
          return map;
        }
      }
    }
    return const {};
  }

  String _messageFromDio(DioException error) {
    if (kDebugMode) {
      debugPrint('Deliverex register DioException type: ${error.type}');
      debugPrint('Deliverex register DioException message: ${error.message}');
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The server took too long to respond.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Check your internet connection.';
    }
    if (error.type == DioExceptionType.cancel) {
      return 'Request was cancelled. Please try again.';
    }

    final response = error.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map) {
        final message =
            data['message']?.toString() ?? data['error']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        final errors = data['errors'];
        if (errors is Map) {
          for (final entry in errors.entries) {
            final value = entry.value;
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
            if (value is String && value.isNotEmpty) {
              return value;
            }
          }
        }
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
    }

    if (response != null) {
      return 'Server error (${response.statusCode}). Please try again.';
    }

    return 'Unable to create account. Please try again.';
  }

  String _firstString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
