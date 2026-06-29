import 'dart:io';

import 'package:deliverex/services/api_client.dart';
import 'package:deliverex/services/auth_service.dart';
import 'package:deliverex/services/session_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  ApiClient apiClient(
    Response<dynamic> Function(RequestOptions options) handler,
  ) {
    final client = ApiClient();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, requestHandler) {
          try {
            requestHandler.resolve(handler(options));
          } on DioException catch (error) {
            requestHandler.reject(error);
          }
        },
      ),
    );
    return client;
  }

  Response<dynamic> jsonResponse(
    RequestOptions options,
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) {
    return Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    );
  }

  test(
    'change password sends backend-compatible payload and updates cache',
    () async {
      final session = SessionService();
      await session.saveLoginSession(
        role: MobileSessionRole.driver,
        accessToken: 'driver-token',
      );

      final service = AuthService(
        apiClient: apiClient((options) {
          expect(options.path, '/auth/change-password');
          expect(options.headers['Authorization'], 'Bearer driver-token');
          expect(options.data, {
            'current_password': 'temporary123',
            'password': 'newpass123',
            'password_confirmation': 'newpass123',
          });
          return jsonResponse(options, {
            'message': 'Password updated successfully.',
            'user': {
              'id': 7,
              'name': 'Driver User',
              'email': 'driver@example.com',
              'role': {'name': 'driver'},
              'must_change_password': false,
            },
          });
        }),
      );

      final user = await service.changePassword(
        currentPassword: 'temporary123',
        password: 'newpass123',
        passwordConfirmation: 'newpass123',
      );

      expect(user.mustChangePassword, isFalse);
      final snapshot = await session.readUserSnapshot(MobileSessionRole.driver);
      expect(snapshot['must_change_password'], isFalse);
    },
  );

  test('change password surfaces backend validation message', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        throw DioException(
          requestOptions: options,
          response: jsonResponse(options, {
            'errors': {
              'current_password': ['Current password is incorrect.'],
            },
          }, statusCode: 422),
          type: DioExceptionType.badResponse,
        );
      }),
    );

    expect(
      () => service.changePassword(
        currentPassword: 'wrong',
        password: 'newpass123',
        passwordConfirmation: 'newpass123',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Current password is incorrect.',
        ),
      ),
    );
  });

  test('restores a valid driver session through auth me', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        expect(options.path, '/auth/me');
        expect(options.headers['Authorization'], 'Bearer driver-token');
        return jsonResponse(options, {
          'user': {
            'id': 7,
            'name': 'Driver User',
            'email': 'driver@example.com',
            'role': {'name': 'driver'},
            'must_change_password': true,
          },
        });
      }),
    );

    final restored = await service.restoreSession();

    expect(restored?.user.name, 'Driver User');
    expect(restored?.isDriver, isTrue);
    final snapshot = await session.readUserSnapshot(MobileSessionRole.driver);
    expect(snapshot['name'], 'Driver User');
    expect(snapshot['role_name'], 'driver');
    expect(snapshot['must_change_password'], isTrue);
  });

  test('restores a valid customer session through auth me', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.customer,
      accessToken: 'customer-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        expect(options.path, '/auth/me');
        expect(options.headers['Authorization'], 'Bearer customer-token');
        return jsonResponse(options, {
          'user': {
            'id': 8,
            'name': 'Customer User',
            'email': 'customer@example.com',
            'role': {'name': 'customer'},
          },
        });
      }),
    );

    final restored = await service.restoreSession();

    expect(restored?.user.name, 'Customer User');
    expect(restored?.isDriver, isFalse);
    final snapshot = await session.readUserSnapshot(MobileSessionRole.customer);
    expect(snapshot['name'], 'Customer User');
    expect(snapshot['role_name'], 'customer');
  });

  test('restores cached driver session when auth me is unreachable', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );
    await session.saveUserSnapshot(
      role: MobileSessionRole.driver,
      user: {
        'id': 7,
        'name': 'Cached Driver',
        'email': 'driver@example.com',
        'role_name': 'driver',
        'must_change_password': true,
      },
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('No route to host'),
        );
      }),
    );

    final restored = await service.restoreSession();

    expect(restored?.token, 'driver-token');
    expect(restored?.user.name, 'Cached Driver');
    expect(restored?.isDriver, isTrue);
    expect(restored?.restoredOffline, isTrue);
    expect(restored?.user.mustChangePassword, isTrue);
  });

  test(
    'restores cached customer session when auth me is unreachable',
    () async {
      final session = SessionService();
      await session.saveLoginSession(
        role: MobileSessionRole.customer,
        accessToken: 'customer-token',
      );
      await session.saveUserSnapshot(
        role: MobileSessionRole.customer,
        user: {
          'id': 8,
          'name': 'Cached Customer',
          'email': 'customer@example.com',
          'role_name': 'customer',
        },
      );

      final service = AuthService(
        apiClient: apiClient((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }),
      );

      final restored = await service.restoreSession();

      expect(restored?.token, 'customer-token');
      expect(restored?.user.name, 'Cached Customer');
      expect(restored?.isDriver, isFalse);
    },
  );

  test('clears expired saved session and returns null', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'expired-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        throw DioException(
          requestOptions: options,
          response: jsonResponse(options, {
            'message': 'Unauthenticated.',
          }, statusCode: 401),
          type: DioExceptionType.badResponse,
        );
      }),
    );

    final restored = await service.restoreSession();

    expect(restored, isNull);
    expect(await session.readSession(MobileSessionRole.driver), isNull);
    expect(await session.readUserSnapshot(MobileSessionRole.driver), isEmpty);
  });

  test('malformed auth me response returns null', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) => jsonResponse(options, {'data': {}})),
    );

    expect(await service.restoreSession(), isNull);
  });

  test('offline restore without cached user falls back to null', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );

    final service = AuthService(
      apiClient: apiClient((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Network is unreachable'),
        );
      }),
    );

    expect(await service.restoreSession(), isNull);
  });

  test(
    'offline restore with malformed cached user falls back to null',
    () async {
      final session = SessionService();
      await session.saveLoginSession(
        role: MobileSessionRole.driver,
        accessToken: 'driver-token',
      );
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'deliverex_driver_user_snapshot',
        value: '{"role_name":"driver"}',
      );

      final service = AuthService(
        apiClient: apiClient((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('Network is unreachable'),
          );
        }),
      );

      expect(await service.restoreSession(), isNull);
    },
  );
}
