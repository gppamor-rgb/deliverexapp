import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum MobileSessionRole { driver, customer }

class MobileSession {
  const MobileSession({
    required this.role,
    required this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    this.userId,
  });

  final MobileSessionRole role;
  final String accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final String? userId;

  bool get hasRefreshToken => refreshToken?.trim().isNotEmpty == true;

  bool get isAccessTokenExpiring {
    final expiry = accessExpiresAt;
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)));
  }

  bool get isRefreshTokenExpired {
    final expiry = refreshExpiresAt;
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now());
  }
}

class SessionExpiredException implements Exception {
  const SessionExpiredException([
    this.message = 'Session expired. Please sign in again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class SessionService {
  SessionService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final instance = SessionService();

  static const driverAccessTokenKey = 'deliverex_driver_token';
  static const customerAccessTokenKey = 'deliverex_customer_token';

  static const _activeRoleKey = 'deliverex_active_role';
  static const _driverRefreshTokenKey = 'deliverex_driver_refresh_token';
  static const _customerRefreshTokenKey = 'deliverex_customer_refresh_token';
  static const _driverAccessExpiresKey = 'deliverex_driver_access_expires_at';
  static const _customerAccessExpiresKey =
      'deliverex_customer_access_expires_at';
  static const _driverRefreshExpiresKey = 'deliverex_driver_refresh_expires_at';
  static const _customerRefreshExpiresKey =
      'deliverex_customer_refresh_expires_at';
  static const _driverUserIdKey = 'deliverex_driver_user_id';
  static const _customerUserIdKey = 'deliverex_customer_user_id';
  static const _driverUserSnapshotKey = 'deliverex_driver_user_snapshot';
  static const _customerUserSnapshotKey = 'deliverex_customer_user_snapshot';

  final FlutterSecureStorage _storage;

  Future<void> saveLoginSession({
    required MobileSessionRole role,
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
    String? userId,
  }) async {
    await _storage.write(key: _accessTokenKey(role), value: accessToken);
    await _storage.write(key: _activeRoleKey, value: role.name);

    await _writeNullable(_refreshTokenKey(role), refreshToken);
    await _writeNullable(
      _accessExpiresKey(role),
      accessExpiresAt?.toIso8601String(),
    );
    await _writeNullable(
      _refreshExpiresKey(role),
      refreshExpiresAt?.toIso8601String(),
    );
    await _writeNullable(_userIdKey(role), userId);
  }

  Future<void> saveUserSnapshot({
    required MobileSessionRole role,
    required Map<String, dynamic> user,
  }) async {
    final snapshot = _normalizeUserSnapshot(role: role, user: user);
    if (snapshot.isEmpty) {
      await _storage.delete(key: _userSnapshotKey(role));
      return;
    }
    await _storage.write(
      key: _userSnapshotKey(role),
      value: jsonEncode(snapshot),
    );
  }

  Future<void> saveSessionFromLoginResponse({
    required MobileSessionRole role,
    required Map<String, dynamic> data,
    required Headers headers,
    required String accessToken,
    String? userId,
  }) async {
    await saveLoginSession(
      role: role,
      accessToken: accessToken,
      refreshToken: _firstString([
        data['refresh_token'],
        data['refreshToken'],
        data['refresh'],
        data['data'] is Map ? (data['data'] as Map)['refresh_token'] : null,
        data['data'] is Map ? (data['data'] as Map)['refreshToken'] : null,
      ]),
      accessExpiresAt: _firstDate([
        data['access_expires_at'],
        data['access_token_expires_at'],
        data['expires_at'],
        data['data'] is Map ? (data['data'] as Map)['access_expires_at'] : null,
        data['data'] is Map
            ? (data['data'] as Map)['access_token_expires_at']
            : null,
      ]),
      refreshExpiresAt: _firstDate([
        data['refresh_expires_at'],
        data['refresh_token_expires_at'],
        data['data'] is Map
            ? (data['data'] as Map)['refresh_expires_at']
            : null,
        data['data'] is Map
            ? (data['data'] as Map)['refresh_token_expires_at']
            : null,
      ]),
      userId: userId,
    );

    if (kDebugMode && headers.value('authorization') != null) {
      debugPrint('Deliverex session saved access token from response headers');
    }
  }

  Future<MobileSession?> readSession(MobileSessionRole role) async {
    final accessToken = await _storage.read(key: _accessTokenKey(role));
    if (accessToken == null || accessToken.trim().isEmpty) {
      return null;
    }

    return MobileSession(
      role: role,
      accessToken: accessToken,
      refreshToken: await _storage.read(key: _refreshTokenKey(role)),
      accessExpiresAt: _parseDate(
        await _storage.read(key: _accessExpiresKey(role)),
      ),
      refreshExpiresAt: _parseDate(
        await _storage.read(key: _refreshExpiresKey(role)),
      ),
      userId: await _storage.read(key: _userIdKey(role)),
    );
  }

  Future<Map<String, dynamic>> readUserSnapshot(MobileSessionRole role) async {
    final raw = await _storage.read(key: _userSnapshotKey(role));
    final decoded = _ensureMap(raw);
    if (decoded.isEmpty) {
      return const {};
    }
    return _normalizeUserSnapshot(role: role, user: decoded);
  }

  Future<MobileSessionRole?> readActiveRole() async {
    final value = await _storage.read(key: _activeRoleKey);
    return switch (value) {
      'driver' => MobileSessionRole.driver,
      'customer' => MobileSessionRole.customer,
      _ => null,
    };
  }

  Future<List<MobileSessionRole>> restoreRolePriority() async {
    final activeRole = await readActiveRole();
    return [
      ?activeRole,
      for (final role in MobileSessionRole.values)
        if (role != activeRole) role,
    ];
  }

  Future<String?> validAccessToken({
    required MobileSessionRole role,
    required Dio dio,
  }) async {
    final session = await readSession(role);
    if (session == null) return null;
    if (!session.isAccessTokenExpiring) return session.accessToken;
    if (!session.hasRefreshToken || session.isRefreshTokenExpired) {
      throw const SessionExpiredException();
    }

    return _refreshAccessToken(session: session, dio: dio);
  }

  Future<String> refreshAccessToken({
    required MobileSessionRole role,
    required Dio dio,
  }) async {
    final session = await readSession(role);
    if (session == null ||
        !session.hasRefreshToken ||
        session.isRefreshTokenExpired) {
      throw const SessionExpiredException();
    }
    return _refreshAccessToken(session: session, dio: dio);
  }

  Future<String> _refreshAccessToken({
    required MobileSession session,
    required Dio dio,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': session.refreshToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Accept': 'application/json',
          },
        ),
      );
      final data = _ensureMap(response.data);
      final accessToken = _firstString([
        data['access_token'],
        data['token'],
        data['api_token'],
        data['data'] is Map ? (data['data'] as Map)['access_token'] : null,
        data['data'] is Map ? (data['data'] as Map)['token'] : null,
      ]);
      if (accessToken.isEmpty) {
        throw const SessionExpiredException();
      }

      await saveLoginSession(
        role: session.role,
        accessToken: accessToken,
        refreshToken: _firstString([
          data['refresh_token'],
          data['refreshToken'],
          data['data'] is Map ? (data['data'] as Map)['refresh_token'] : null,
          session.refreshToken,
        ]),
        accessExpiresAt:
            _firstDate([
              data['access_expires_at'],
              data['access_token_expires_at'],
              data['expires_at'],
              data['data'] is Map
                  ? (data['data'] as Map)['access_expires_at']
                  : null,
            ]) ??
            session.accessExpiresAt,
        refreshExpiresAt:
            _firstDate([
              data['refresh_expires_at'],
              data['refresh_token_expires_at'],
              data['data'] is Map
                  ? (data['data'] as Map)['refresh_expires_at']
                  : null,
            ]) ??
            session.refreshExpiresAt,
        userId: session.userId,
      );

      return accessToken;
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Deliverex session refresh failed: ${error.response?.statusCode}',
        );
      }
      throw const SessionExpiredException();
    }
  }

  Future<void> clearRole(MobileSessionRole role) async {
    await _storage.delete(key: _accessTokenKey(role));
    await _storage.delete(key: _refreshTokenKey(role));
    await _storage.delete(key: _accessExpiresKey(role));
    await _storage.delete(key: _refreshExpiresKey(role));
    await _storage.delete(key: _userIdKey(role));
    await _storage.delete(key: _userSnapshotKey(role));
  }

  Future<void> clearAll() async {
    await clearRole(MobileSessionRole.driver);
    await clearRole(MobileSessionRole.customer);
    await _storage.delete(key: _activeRoleKey);
  }

  Future<void> _writeNullable(String key, String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: trimmed);
    }
  }

  static String sessionExpiredMessage() {
    return 'Session expired. Please sign in again.';
  }

  static bool isSessionExpiredResponse(DioException error) {
    return error.response?.statusCode == 401 ||
        error.response?.statusCode == 419;
  }

  String _accessTokenKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => driverAccessTokenKey,
      MobileSessionRole.customer => customerAccessTokenKey,
    };
  }

  String _refreshTokenKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => _driverRefreshTokenKey,
      MobileSessionRole.customer => _customerRefreshTokenKey,
    };
  }

  String _accessExpiresKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => _driverAccessExpiresKey,
      MobileSessionRole.customer => _customerAccessExpiresKey,
    };
  }

  String _refreshExpiresKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => _driverRefreshExpiresKey,
      MobileSessionRole.customer => _customerRefreshExpiresKey,
    };
  }

  String _userIdKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => _driverUserIdKey,
      MobileSessionRole.customer => _customerUserIdKey,
    };
  }

  String _userSnapshotKey(MobileSessionRole role) {
    return switch (role) {
      MobileSessionRole.driver => _driverUserSnapshotKey,
      MobileSessionRole.customer => _customerUserSnapshotKey,
    };
  }
}

Map<String, dynamic> _normalizeUserSnapshot({
  required MobileSessionRole role,
  required Map<String, dynamic> user,
}) {
  final roleObject = user['role'];
  final roleName = _firstString([
    roleObject is Map ? roleObject['name'] : null,
    roleObject is Map ? roleObject['title'] : null,
    roleObject is Map ? roleObject['slug'] : null,
    roleObject is Map ? roleObject['type'] : null,
    roleObject is Map ? roleObject['code'] : null,
    user['role_name'],
    roleObject is! Map ? roleObject : null,
    user['role_title'],
    user['role_slug'],
    user['role_type'],
    role.name,
  ]);
  final id = _firstString([user['id'], user['user_id']]);
  final email = _firstString([user['email']]);
  final firstName = _firstString([user['first_name']]);
  final lastName = _firstString([user['last_name']]);
  final name = _firstString([
    user['name'],
    [firstName, lastName].where((part) => part.isNotEmpty).join(' '),
    role == MobileSessionRole.driver ? 'Driver' : 'Customer',
  ]);
  final mustChangePassword = _boolValue(user['must_change_password']);

  if ((id.isEmpty && email.isEmpty) || roleName.isEmpty) {
    return const {};
  }

  return {
    'id': id,
    'name': name,
    'email': email,
    'role_name': roleName,
    'must_change_password': mustChangePassword,
  };
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

String _firstString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

DateTime? _firstDate(List<dynamic> values) {
  for (final value in values) {
    final parsed = _parseDate(value?.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _parseDate(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final numeric = num.tryParse(text);
  if (numeric != null) {
    final milliseconds = numeric > 100000000000
        ? numeric.toInt()
        : (numeric * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  return DateTime.tryParse(text);
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}
