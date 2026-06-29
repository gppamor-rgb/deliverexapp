import 'package:deliverex/database/action_store.dart';
import 'package:deliverex/services/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Dio dioWithRequestCapture(void Function(RequestOptions options) onRequest) {
    final dio = Dio(BaseOptions(baseUrl: 'https://deliverex.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          onRequest(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'message': 'ok'},
            ),
          );
        },
      ),
    );
    return dio;
  }

  test('sync sends original status action timestamp, not sync time', () async {
    RequestOptions? captured;
    final action = PendingAction(
      id: 42,
      actionType: 'status_update',
      payload: {
        'assignment_id': '7',
        'status': 'arrived',
        'action_taken_at': '2026-06-30T10:30:00.000',
      },
      assignmentId: '7',
      actionTakenAt: '2026-06-30T10:15:00.000',
      createdAt: '2026-06-30T10:15:00.000',
    );

    await SyncService.executeActionStatic(
      action: action,
      dio: dioWithRequestCapture((options) => captured = options),
      token: 'driver-token',
    );

    expect(captured?.path, '/driver/status');
    expect(captured?.headers['Authorization'], 'Bearer driver-token');
    final data = captured!.data as Map<String, dynamic>;
    expect(data['action_taken_at'], '2026-06-30T10:15:00.000');
    expect(data['sync_id'], '42');
  });

  test('sync sends captured_at for queued tracking from action time', () async {
    RequestOptions? captured;
    final action = PendingAction(
      id: 43,
      actionType: 'tracking',
      payload: {
        'assignment_id': '7',
        'latitude': 14.6040792,
        'longitude': 120.9885911,
      },
      assignmentId: '7',
      actionTakenAt: '2026-06-30T10:15:00.000',
      createdAt: '2026-06-30T10:15:00.000',
    );

    await SyncService.executeActionStatic(
      action: action,
      dio: dioWithRequestCapture((options) => captured = options),
      token: 'driver-token',
    );

    expect(captured?.path, '/driver/tracking');
    final data = captured!.data as Map<String, dynamic>;
    expect(data['action_taken_at'], '2026-06-30T10:15:00.000');
    expect(data['captured_at'], '2026-06-30T10:15:00.000');
  });
}
