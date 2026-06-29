import 'package:deliverex/services/api_client.dart';
import 'package:deliverex/services/tracking_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('uses website customer tracking endpoint first', () async {
    final requestedPaths = <String>[];
    final service = TrackingService(
      apiClient: apiClient((options) {
        requestedPaths.add(options.path);
        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'tracking_code': 'T123',
            'status': 'en_route_to_destination',
            'approximate_location': {'lat': 14.6, 'lng': 120.98},
          },
        );
      }),
    );

    final result = await service.lookup('T123');

    expect(requestedPaths.first, '/customer/track/T123');
    expect(requestedPaths, hasLength(1));
    expect(result.lastLocation?.displayText, '14.600000, 120.980000');
  });
}
