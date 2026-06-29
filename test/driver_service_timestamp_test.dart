import 'package:deliverex/services/api_client.dart';
import 'package:deliverex/services/driver_service.dart';
import 'package:deliverex/services/session_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actionTakenAt = '2026-06-30T10:15:00.000';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  ApiClient apiClient(void Function(RequestOptions options) onRequest) {
    final client = ApiClient();
    client.dio.interceptors.add(
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
    return client;
  }

  Future<DriverService> serviceCapturing(
    void Function(RequestOptions options) onRequest,
  ) async {
    await SessionService().saveLoginSession(
      role: MobileSessionRole.driver,
      accessToken: 'driver-token',
    );
    return DriverService(apiClient: apiClient(onRequest));
  }

  test('online document upload sends both timestamp fields', () async {
    RequestOptions? captured;
    final service = await serviceCapturing((options) => captured = options);

    await service.uploadDocument(
      assignmentId: '7',
      type: 'receipt',
      fileName: 'receipt.jpg',
      bytes: const [1, 2, 3],
      actionTakenAt: actionTakenAt,
    );

    expect(captured?.path, '/driver/documents');
    final fields = _formFields(captured!.data as FormData);
    expect(fields['action_timestamp'], actionTakenAt);
    expect(fields['action_taken_at'], actionTakenAt);
  });

  test('online completion proof sends both timestamp fields', () async {
    RequestOptions? captured;
    final service = await serviceCapturing((options) => captured = options);

    await service.uploadCompletionProof(
      assignmentId: '7',
      proofType: 'receipt_photo',
      fileName: 'proof.jpg',
      bytes: const [1, 2, 3],
      actionTakenAt: actionTakenAt,
    );

    expect(captured?.path, '/driver/completion-proof');
    final fields = _formFields(captured!.data as FormData);
    expect(fields['action_timestamp'], actionTakenAt);
    expect(fields['action_taken_at'], actionTakenAt);
  });

  test('online issue report sends both timestamp fields', () async {
    RequestOptions? captured;
    final service = await serviceCapturing((options) => captured = options);

    await service.reportIssue(
      assignmentId: '7',
      issueType: 'safety_issue',
      fileName: 'issue.jpg',
      bytes: const [1, 2, 3],
      actionTakenAt: actionTakenAt,
    );

    expect(captured?.path, '/driver/issues');
    final fields = _formFields(captured!.data as FormData);
    expect(fields['action_timestamp'], actionTakenAt);
    expect(fields['action_taken_at'], actionTakenAt);
  });

  test('online delay report sends both timestamp fields', () async {
    RequestOptions? captured;
    final service = await serviceCapturing((options) => captured = options);

    await service.reportDelay(
      assignmentId: '7',
      delayReason: 'traffic',
      actionTakenAt: actionTakenAt,
    );

    expect(captured?.path, '/driver/delays');
    final data = captured!.data as Map<String, dynamic>;
    expect(data['action_timestamp'], actionTakenAt);
    expect(data['action_taken_at'], actionTakenAt);
  });
}

Map<String, String> _formFields(FormData formData) {
  return {for (final field in formData.fields) field.key: field.value};
}
