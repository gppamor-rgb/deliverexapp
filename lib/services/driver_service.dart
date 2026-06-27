import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driver_assignment.dart';
import '../models/driver_notification.dart';
import 'api_client.dart';
import 'auth_service.dart';

class DriverService {
  DriverService({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  Future<DriverAssignmentsPage> fetchAssignments({
    int page = 1,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final response = await _apiClient.dio.get<dynamic>(
      '/driver/assignments',
      queryParameters: params,
      options: await _authOptions(),
    );
    return DriverAssignmentsPage.fromJson(response.data);
  }

  Future<DriverAssignment> fetchAssignment(String id) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/driver/assignments/$id',
      options: await _authOptions(),
    );
    final data = _unwrapObject(response.data);
    return DriverAssignment.fromJson(data);
  }

  Future<DriverProfile> fetchProfile({int historyPage = 1}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/driver/profile',
      queryParameters: {'history_page': historyPage},
      options: await _authOptions(),
    );
    return DriverProfile.fromJson(_unwrapObject(response.data));
  }

  Future<Response<dynamic>> updateProfile({
    required String name,
    required String phone,
  }) async {
    return _apiClient.dio.put<dynamic>(
      '/driver/profile',
      data: {'name': name.trim(), 'phone': phone.trim()},
      options: await _authOptions(),
    );
  }

  Future<Response<dynamic>> postStatus({
    required String assignmentId,
    required String status,
    double? latitude,
    double? longitude,
  }) async {
    return _apiClient.dio.post<dynamic>(
      '/driver/status',
      data: {
        'assignment_id': assignmentId,
        'status': status,
        // ignore: use_null_aware_elements
        if (latitude != null) 'latitude': latitude,
        // ignore: use_null_aware_elements
        if (longitude != null) 'longitude': longitude,
      },
      options: await _authOptions(),
    );
  }

  Future<void> postTracking({
    required String assignmentId,
    required double latitude,
    required double longitude,
  }) async {
    await _apiClient.dio.post<dynamic>(
      '/driver/tracking',
      data: {
        'assignment_id': assignmentId,
        'latitude': latitude,
        'longitude': longitude,
      },
      options: await _authOptions(),
    );
  }

  Future<Response<dynamic>> uploadDocument({
    required String assignmentId,
    required String type,
    required String fileName,
    required List<int> bytes,
    String? notes,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'assignment_id': assignmentId,
      'type': type,
      'document_type': type,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    return _apiClient.dio.post<dynamic>(
      '/driver/documents',
      data: formData,
      options: await _authOptions(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
  }

  Future<Response<dynamic>> uploadCompletionProof({
    required String assignmentId,
    required String proofType,
    required String fileName,
    required List<int> bytes,
    String? documentType,
    String? receiverName,
    String? receiverContact,
    String? deliveryNotes,
    String? signatureFileName,
    List<int>? signatureBytes,
  }) async {
    final formData = FormData.fromMap({
      'assignment_id': assignmentId,
      'proof_type': proofType,
      if (documentType != null && documentType.trim().isNotEmpty)
        'document_type': documentType.trim(),
      if (receiverName != null && receiverName.trim().isNotEmpty)
        'receiver_name': receiverName.trim(),
      if (receiverContact != null && receiverContact.trim().isNotEmpty)
        'receiver_contact': receiverContact.trim(),
      if (deliveryNotes != null && deliveryNotes.trim().isNotEmpty)
        'delivery_notes': deliveryNotes.trim(),
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (signatureFileName != null && signatureBytes != null)
        'signature': MultipartFile.fromBytes(
          signatureBytes,
          filename: signatureFileName,
        ),
    });

    return _apiClient.dio.post<dynamic>(
      '/driver/completion-proof',
      data: formData,
      options: await _authOptions(contentType: 'multipart/form-data'),
    );
  }

  Future<void> reportIssue({
    required String assignmentId,
    required String issueType,
    String? notes,
    String? fileName,
    List<int>? bytes,
  }) async {
    final formData = FormData.fromMap({
      'assignment_id': assignmentId,
      'issue_type': issueType,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (fileName != null && bytes != null)
        'photo': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    await _apiClient.dio.post<dynamic>(
      '/driver/issues',
      data: formData,
      options: await _authOptions(contentType: 'multipart/form-data'),
    );
  }

  Future<void> reportDelay({
    required String assignmentId,
    required String delayReason,
    String? notes,
  }) async {
    await _apiClient.dio.post<dynamic>(
      '/driver/delays',
      data: {
        'assignment_id': assignmentId,
        'delay_reason': delayReason,
        if (notes != null && notes.trim().isNotEmpty)
          'delay_notes': notes.trim(),
      },
      options: await _authOptions(),
    );
  }

  Future<DriverNotificationsPage> fetchNotifications({int page = 1}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/notifications',
      queryParameters: {'page': page},
      options: await _authOptions(),
    );
    return DriverNotificationsPage.fromJson(response.data);
  }

  Future<Response<dynamic>> markNotificationRead(String id) async {
    return _apiClient.dio.put<dynamic>(
      '/notifications/$id/read',
      options: await _authOptions(),
    );
  }

  Future<void> markAllNotificationsRead(List<String> ids) async {
    final opts = await _authOptions();
    for (final id in ids) {
      try {
        await _apiClient.dio.put<dynamic>(
          '/notifications/$id/read',
          options: opts,
        );
      } catch (_) {
        // Continue marking other notifications even if one fails.
      }
    }
  }

  Future<Options> _authOptions({String? contentType}) async {
    final token = await _storage.read(key: AuthService.tokenKey);
    return Options(
      contentType: contentType,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _unwrapObject(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const {};
  }
}
