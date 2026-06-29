import 'package:deliverex/services/api_client.dart';
import 'package:deliverex/services/customer_portal_service.dart';
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

  test(
    'fetches linked deliveries from customer portal orders endpoint',
    () async {
      final session = SessionService();
      await session.saveLoginSession(
        role: MobileSessionRole.customer,
        accessToken: 'customer-token',
      );

      final service = CustomerPortalService(
        apiClient: apiClient((options) {
          expect(options.path, '/customer/portal/orders');
          expect(options.headers['Authorization'], 'Bearer customer-token');
          return Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {'tracking_code': 'T1', 'status': 'assigned'},
                {'tracking_code': 'T2', 'status': 'cancelled'},
              ],
            },
          );
        }),
      );

      final orders = await service.fetchOrders();

      expect(orders.map((order) => order.trackingCode), ['T1']);
    },
  );

  test(
    'link delivery sends website-compatible tracking code payload',
    () async {
      final session = SessionService();
      await session.saveLoginSession(
        role: MobileSessionRole.customer,
        accessToken: 'customer-token',
      );

      final service = CustomerPortalService(
        apiClient: apiClient((options) {
          expect(options.path, '/customer/portal/link-delivery');
          expect(options.data, {'tracking_code': 'TRACK-123'});
          return Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'message': 'Linked.'},
          );
        }),
      );

      expect(await service.linkDelivery(' TRACK-123 '), 'Linked.');
    },
  );

  test('submit inquiry sends website-compatible payload', () async {
    final session = SessionService();
    await session.saveLoginSession(
      role: MobileSessionRole.customer,
      accessToken: 'customer-token',
    );

    final service = CustomerPortalService(
      apiClient: apiClient((options) {
        expect(options.path, '/customer/inquiry');
        expect(options.headers['Authorization'], 'Bearer customer-token');
        expect(options.data, {
          'name': 'Customer User',
          'email': 'customer@example.com',
          'phone': '+639123456789',
          'inquiry_type': 'general_question',
          'subject': 'Delivery question',
          'message': 'Can you help me?',
        });
        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'message': 'Received.'},
        );
      }),
    );

    final message = await service.submitInquiry(
      name: ' Customer User ',
      email: ' customer@example.com ',
      phone: ' +639123456789 ',
      subject: ' Delivery question ',
      message: ' Can you help me? ',
    );

    expect(message, 'Received.');
  });
}
