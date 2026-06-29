import 'dart:io';

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
        'action_timestamp': '2026-06-30T10:30:00.000',
        'action_taken_at': '2026-06-30T10:30:00.000',
        'synced_at': '2026-06-30T10:30:00.000',
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
    expect(data['action_timestamp'], '2026-06-30T10:15:00.000');
    expect(data['action_taken_at'], '2026-06-30T10:15:00.000');
    expect(data.containsKey('synced_at'), isFalse);
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
        'captured_at': '2026-06-30T10:30:00.000',
        'synced_at': '2026-06-30T10:30:00.000',
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
    expect(data['action_timestamp'], '2026-06-30T10:15:00.000');
    expect(data['action_taken_at'], '2026-06-30T10:15:00.000');
    expect(data['captured_at'], '2026-06-30T10:15:00.000');
    expect(data.containsKey('synced_at'), isFalse);
  });

  test('sync sends original delay timestamp fields', () async {
    RequestOptions? captured;
    final action = PendingAction(
      id: 44,
      actionType: 'delay',
      payload: {
        'assignment_id': '7',
        'delay_reason': 'traffic',
        'action_timestamp': '2026-06-30T10:30:00.000',
        'action_taken_at': '2026-06-30T10:30:00.000',
        'synced_at': '2026-06-30T10:30:00.000',
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

    expect(captured?.path, '/driver/delays');
    final data = captured!.data as Map<String, dynamic>;
    expect(data['action_timestamp'], '2026-06-30T10:15:00.000');
    expect(data['action_taken_at'], '2026-06-30T10:15:00.000');
    expect(data.containsKey('synced_at'), isFalse);
  });

  test('sync sends original timestamps for queued multipart actions', () async {
    final captured = <RequestOptions>[];
    final dio = dioWithRequestCapture(captured.add);

    for (final action in [
      PendingAction(
        id: 45,
        actionType: 'document',
        payload: {
          'assignment_id': '7',
          'type': 'receipt',
          'document_type': 'receipt',
          'action_timestamp': '2026-06-30T10:30:00.000',
          'action_taken_at': '2026-06-30T10:30:00.000',
          'synced_at': '2026-06-30T10:30:00.000',
        },
        fileBytes: const [1, 2, 3],
        fileName: 'receipt.jpg',
        assignmentId: '7',
        actionTakenAt: '2026-06-30T10:15:00.000',
        createdAt: '2026-06-30T10:15:00.000',
      ),
      PendingAction(
        id: 46,
        actionType: 'issue',
        payload: {
          'assignment_id': '7',
          'issue_type': 'safety_issue',
          'action_timestamp': '2026-06-30T10:30:00.000',
          'action_taken_at': '2026-06-30T10:30:00.000',
          'synced_at': '2026-06-30T10:30:00.000',
        },
        fileBytes: const [1, 2, 3],
        fileName: 'issue.jpg',
        assignmentId: '7',
        actionTakenAt: '2026-06-30T10:15:00.000',
        createdAt: '2026-06-30T10:15:00.000',
      ),
      PendingAction(
        id: 47,
        actionType: 'completion_proof',
        payload: {
          'assignment_id': '7',
          'proof_type': 'receipt_photo',
          'action_timestamp': '2026-06-30T10:30:00.000',
          'action_taken_at': '2026-06-30T10:30:00.000',
          'synced_at': '2026-06-30T10:30:00.000',
        },
        fileBytes: const [1, 2, 3],
        fileName: 'proof.jpg',
        assignmentId: '7',
        actionTakenAt: '2026-06-30T10:15:00.000',
        createdAt: '2026-06-30T10:15:00.000',
      ),
    ]) {
      await SyncService.executeActionStatic(
        action: action,
        dio: dio,
        token: 'driver-token',
      );
    }

    expect(captured.map((options) => options.path), [
      '/driver/documents',
      '/driver/issues',
      '/driver/completion-proof',
    ]);
    for (final options in captured) {
      final fields = _formFields(options.data as FormData);
      expect(fields['action_timestamp'], '2026-06-30T10:15:00.000');
      expect(fields['action_taken_at'], '2026-06-30T10:15:00.000');
      expect(fields.containsKey('synced_at'), isFalse);
    }
  });

  test('sync reads queued document bytes from file path', () async {
    RequestOptions? captured;
    final tempDir = await Directory.systemTemp.createTemp('deliverex_sync_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final queuedFile = File('${tempDir.path}/receipt.jpg');
    await queuedFile.writeAsBytes([9, 8, 7]);

    final action = PendingAction(
      id: 48,
      actionType: 'document',
      payload: {
        'assignment_id': '7',
        'type': 'receipt',
        'document_type': 'receipt',
      },
      filePath: queuedFile.path,
      fileName: 'receipt.jpg',
      assignmentId: '7',
      actionTakenAt: '2026-06-30T10:15:00.000',
      createdAt: '2026-06-30T10:15:00.000',
    );

    await SyncService.executeActionStatic(
      action: action,
      dio: dioWithRequestCapture((options) => captured = options),
      token: 'driver-token',
    );

    expect(captured?.path, '/driver/documents');
    final formData = captured!.data as FormData;
    expect(formData.files.single.value.filename, 'receipt.jpg');
  });

  test('upload validation failures are not discarded as synced', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://deliverex.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 422,
                data: {'message': 'The selected type is invalid.'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final action = PendingAction(
      id: 49,
      actionType: 'document',
      payload: {
        'assignment_id': '7',
        'type': 'receipt',
        'document_type': 'receipt',
      },
      fileBytes: const [1, 2, 3],
      fileName: 'receipt.jpg',
      assignmentId: '7',
      actionTakenAt: '2026-06-30T10:15:00.000',
      createdAt: '2026-06-30T10:15:00.000',
    );

    await expectLater(
      SyncService.executeActionStatic(
        action: action,
        dio: dio,
        token: 'driver-token',
      ),
      throwsA(isA<DioException>()),
    );
  });
}

Map<String, String> _formFields(FormData formData) {
  return {for (final field in formData.fields) field.key: field.value};
}
