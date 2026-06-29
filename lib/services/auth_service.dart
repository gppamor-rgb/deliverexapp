import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network_errors.dart';
import '../database/action_store.dart';
import '../database/assignment_store.dart';
import '../database/database_helper.dart';
import '../models/driver_user.dart';
import 'api_client.dart';
import 'session_service.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final DriverUser user;
}

class SessionRestoreResult {
  const SessionRestoreResult({
    required this.token,
    required this.user,
    this.restoredOffline = false,
  });

  final String token;
  final DriverUser user;
  final bool restoredOffline;

  bool get isDriver => user.isDriver;
}

class AuthService {
  AuthService({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'deliverex_driver_token';
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final _sessionService = SessionService.instance;
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

      await _sessionService.saveSessionFromLoginResponse(
        role: user.isDriver
            ? MobileSessionRole.driver
            : MobileSessionRole.customer,
        data: data,
        headers: response.headers,
        accessToken: token,
        userId: user.id,
      );
      await _sessionService.saveUserSnapshot(
        role: user.isDriver
            ? MobileSessionRole.driver
            : MobileSessionRole.customer,
        user: _userSnapshotFromDriverUser(user),
      );
      await _dbHelper.deleteSetting(tokenKey);
      if (user.isDriver) {
        await _dbHelper.setSetting('current_driver_id', user.id);
      } else {
        await _dbHelper.deleteSetting('current_driver_id');
      }
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

  Future<SessionRestoreResult?> restoreSession() async {
    for (final role in await _sessionService.restoreRolePriority()) {
      final session = await _sessionService.readSession(role);
      final token = session?.accessToken.trim() ?? '';
      if (session == null || token.isEmpty) {
        continue;
      }

      try {
        final response = await _apiClient.dio.get<dynamic>(
          '/auth/me',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            extra: {'sessionRole': role.name},
          ),
        );
        final data = _ensureMap(response.data);
        final userJson = _extractUser(data);
        if (userJson.isEmpty) {
          await _sessionService.clearRole(role);
          continue;
        }

        final user = DriverUser.fromJson(userJson);
        await _sessionService.saveUserSnapshot(
          role: user.isDriver
              ? MobileSessionRole.driver
              : MobileSessionRole.customer,
          user: _userSnapshotFromDriverUser(user),
        );
        try {
          if (user.isDriver) {
            await _dbHelper.setSetting('current_driver_id', user.id);
          } else {
            await _dbHelper.deleteSetting('current_driver_id');
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Deliverex restore session cache update failed: $error');
          }
        }

        return SessionRestoreResult(token: token, user: user);
      } on DioException catch (error) {
        if (SessionService.isSessionExpiredResponse(error)) {
          await _sessionService.clearRole(role);
          continue;
        }
        if (isNetworkTransportError(error)) {
          final cachedUser = await _cachedUserForOfflineRestore(role);
          if (cachedUser != null) {
            return SessionRestoreResult(
              token: token,
              user: cachedUser,
              restoredOffline: true,
            );
          }
        }
        continue;
      } on SessionExpiredException {
        await _sessionService.clearRole(role);
        continue;
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<DriverUser> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final token = await _sessionService.validAccessToken(
        role: MobileSessionRole.driver,
        dio: _apiClient.dio,
      );
      if (token == null || token.isEmpty) {
        throw const AuthException('Session expired. Please sign in again.');
      }

      final response = await _apiClient.dio.post<dynamic>(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          extra: const {'sessionRole': 'driver'},
        ),
      );
      final data = _ensureMap(response.data);
      final userJson = _extractUser(data);
      if (userJson.isEmpty) {
        throw const AuthException(
          'Password updated, but user data was missing.',
        );
      }

      final user = DriverUser.fromJson(userJson);
      await _sessionService.saveUserSnapshot(
        role: MobileSessionRole.driver,
        user: _userSnapshotFromDriverUser(user),
      );
      await _dbHelper.setSetting('current_driver_id', user.id);
      return user;
    } on DioException catch (error) {
      throw AuthException(_messageFromDio(error));
    } on SessionExpiredException {
      throw const AuthException('Session expired. Please sign in again.');
    }
  }

  Future<DriverUser?> _cachedUserForOfflineRestore(
    MobileSessionRole role,
  ) async {
    final userJson = await _sessionService.readUserSnapshot(role);
    if (userJson.isEmpty) {
      return null;
    }

    final user = DriverUser.fromJson(userJson);
    if (user.id.trim().isEmpty && user.email.trim().isEmpty) {
      return null;
    }

    final expectedRoleMatches = switch (role) {
      MobileSessionRole.driver => user.isDriver,
      MobileSessionRole.customer => !user.isDriver,
    };
    if (!expectedRoleMatches) {
      return null;
    }

    try {
      if (user.isDriver) {
        await _dbHelper.setSetting('current_driver_id', user.id);
      } else {
        await _dbHelper.deleteSetting('current_driver_id');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Deliverex offline restore cache update failed: $error');
      }
    }

    if (kDebugMode) {
      debugPrint(
        'Deliverex restored cached ${role.name} session while offline',
      );
    }
    return user;
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
    final driverToken = await _storage.read(
      key: SessionService.driverAccessTokenKey,
    );
    final customerToken = await _storage.read(
      key: SessionService.customerAccessTokenKey,
    );
    final token = driverToken?.isNotEmpty == true ? driverToken : customerToken;
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
      await _sessionService.clearAll();
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

  Map<String, dynamic> _userSnapshotFromDriverUser(DriverUser user) {
    return {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role_name': user.roleName,
      'must_change_password': user.mustChangePassword,
    };
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
    if (response?.statusCode == 401 || response?.statusCode == 419) {
      return SessionService.sessionExpiredMessage();
    }

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
