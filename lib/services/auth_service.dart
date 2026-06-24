import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/action_store.dart';
import '../database/assignment_store.dart';
import '../database/database_helper.dart';
import '../models/driver_user.dart';
import 'api_client.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final DriverUser user;
}

class AuthService {
  AuthService({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'deliverex_driver_token';
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final _dbHelper = DatabaseHelper.instance;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = _ensureMap(response.data);
      if (kDebugMode) {
        debugPrint('Deliverex login response data: $data');
      }

      final token = _firstString([
        data['token'],
        data['access_token'],
        data['api_token'],
        _headerToken(response.headers.value('authorization')),
        _headerToken(response.headers.value('Authorization')),
        _headerToken(response.headers.value('x-access-token')),
        _headerToken(response.headers.value('x-auth-token')),
        data['data'] is Map ? (data['data'] as Map)['token'] : null,
        data['data'] is Map ? (data['data'] as Map)['access_token'] : null,
        data['data'] is Map ? (data['data'] as Map)['api_token'] : null,
      ]);
      final userJson = _extractUser(data);
      if (kDebugMode) {
        debugPrint('Deliverex login extracted user: $userJson');
      }
      final user = DriverUser.fromJson(userJson);

      if (token.isEmpty) {
        throw const AuthException(
          'Login succeeded, but no token was returned.',
        );
      }
      if (!user.isDriver) {
        if (kDebugMode) {
          debugPrint(
            'Deliverex login accepted a non-driver role (${user.roleName}) so the app can continue; backend authorization should enforce access.',
          );
        }
      }

      await _storage.write(key: tokenKey, value: token);
      await _dbHelper.setSetting(tokenKey, token);
      await _dbHelper.setSetting('current_driver_id', user.id);
      return AuthResult(token: token, user: user);
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint('Deliverex login DioException: ${error.type}');
        debugPrint(
          'Deliverex login response status: ${error.response?.statusCode}',
        );
        debugPrint('Deliverex login response data: ${error.response?.data}');
      }
      throw AuthException(_messageFromDio(error));
    }
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('Deliverex login response is a string: $data');
      }
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  Future<void> logout() async {
    final token = await _storage.read(key: tokenKey);
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/logout',
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException {
      // Local logout should still clear the token if the server is unreachable.
    } finally {
      await _storage.delete(key: tokenKey);
      await _dbHelper.deleteSetting(tokenKey);
      await _dbHelper.deleteSetting('current_driver_id');
      await _dbHelper.deleteSetting('locally_read_notification_ids');
      await AssignmentStore().clearCache();
      await ActionStore().clearAll();
    }
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> data) {
    final candidates = [
      data['user'],
      data['driver'],
      data['account'],
      data['data'] is Map ? (data['data'] as Map)['user'] : null,
      data['data'] is Map ? (data['data'] as Map)['driver'] : null,
      data['data'] is Map ? (data['data'] as Map)['account'] : null,
      data,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        if (candidate.containsKey('email') ||
            candidate.containsKey('role') ||
            candidate.containsKey('role_name')) {
          return candidate;
        }
      }
      if (candidate is Map) {
        final map = Map<String, dynamic>.from(candidate);
        if (map.containsKey('email') ||
            map.containsKey('role') ||
            map.containsKey('role_name')) {
          return map;
        }
      }
    }
    return const {};
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

  String _headerToken(String? headerValue) {
    final value = headerValue?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    final bearerMatch = RegExp(
      r'^Bearer\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (bearerMatch != null) {
      return bearerMatch.group(1)?.trim() ?? '';
    }

    final cookieMatch = RegExp(
      r'(?:^|;\s*)(?:token|access_token|auth_token)=([^;]+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (cookieMatch != null) {
      return cookieMatch.group(1)?.trim() ?? '';
    }

    return '';
  }

  String _messageFromDio(DioException error) {
    if (kDebugMode) {
      debugPrint('Deliverex DioException type: ${error.type}');
      debugPrint('Deliverex DioException message: ${error.message}');
      debugPrint(
        'Deliverex DioException response: ${error.response?.statusCode}',
      );
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

    return 'Unable to sign in. Check your email and password.';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
