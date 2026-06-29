import 'package:deliverex/services/session_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores and reads driver session from secure storage', () async {
    final service = SessionService();
    final accessExpiresAt = DateTime.now().add(const Duration(hours: 2));
    final refreshExpiresAt = DateTime.now().add(const Duration(days: 7));

    await service.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      userId: 'driver-1',
    );

    final session = await service.readSession(MobileSessionRole.driver);

    expect(session?.accessToken, 'access-token');
    expect(session?.refreshToken, 'refresh-token');
    expect(session?.userId, 'driver-1');
    expect(session?.hasRefreshToken, isTrue);
    expect(session?.isRefreshTokenExpired, isFalse);
    expect(await service.readActiveRole(), MobileSessionRole.driver);
  });

  test('restore role priority uses active role first', () async {
    final service = SessionService();

    await service.saveLoginSession(
      role: MobileSessionRole.customer,
      accessToken: 'customer-token',
    );

    expect(await service.restoreRolePriority(), [
      MobileSessionRole.customer,
      MobileSessionRole.driver,
    ]);
  });

  test('keeps current single access-token backend compatible', () async {
    final service = SessionService();
    final dio = Dio();

    await service.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'legacy-access-token',
    );

    final token = await service.validAccessToken(
      role: MobileSessionRole.driver,
      dio: dio,
    );

    expect(token, 'legacy-access-token');
  });

  test('stores and reads cached user snapshot from secure storage', () async {
    final service = SessionService();

    await service.saveUserSnapshot(
      role: MobileSessionRole.driver,
      user: {
        'id': 7,
        'name': 'Driver User',
        'email': 'driver@example.com',
        'role': {'name': 'driver'},
        'must_change_password': true,
      },
    );

    final snapshot = await service.readUserSnapshot(MobileSessionRole.driver);

    expect(snapshot['id'], '7');
    expect(snapshot['name'], 'Driver User');
    expect(snapshot['email'], 'driver@example.com');
    expect(snapshot['role_name'], 'driver');
    expect(snapshot['must_change_password'], isTrue);
  });

  test('expired access token without refresh token requires sign in', () async {
    final service = SessionService();
    final dio = Dio();

    await service.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'expired-access-token',
      accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(
      () => service.validAccessToken(role: MobileSessionRole.driver, dio: dio),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('logout cleanup clears driver and customer sessions', () async {
    final service = SessionService();

    await service.saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );
    await service.saveLoginSession(
      role: MobileSessionRole.customer,
      accessToken: 'customer-token',
    );

    await service.clearAll();

    expect(await service.readSession(MobileSessionRole.driver), isNull);
    expect(await service.readSession(MobileSessionRole.customer), isNull);
    expect(await service.readActiveRole(), isNull);
    expect(await service.readUserSnapshot(MobileSessionRole.driver), isEmpty);
    expect(await service.readUserSnapshot(MobileSessionRole.customer), isEmpty);
  });
}
