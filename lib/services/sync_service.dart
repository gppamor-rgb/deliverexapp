import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/action_store.dart';
import 'api_client.dart';
import 'auth_service.dart';

class DiscardActionException implements Exception {}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _actionStore = ActionStore();
  final _apiClient = ApiClient();
  final _storage = const FlutterSecureStorage();

  final _syncController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStream => _syncController.stream;

  bool _isSyncing = false;

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await _actionStore.getPendingActions();
      if (pending.isEmpty) {
        _syncController.add(const SyncIdle());
        return;
      }

      _syncController.add(SyncSyncing(pendingCount: pending.length));

      final token = await _storage.read(key: AuthService.tokenKey);
      if (token == null || token.isEmpty) {
        _syncController.add(const SyncError('No auth token'));
        return;
      }

      for (final action in pending) {
        try {
          await executeActionStatic(
            action: action,
            dio: _apiClient.dio,
            token: token,
          );
          await _actionStore.markSynced(action.id!);
          if (kDebugMode) {
            debugPrint('Deliverex synced action ${action.id}: ${action.actionType}');
          }
        } on DiscardActionException {
          await _actionStore.markSynced(action.id!);
          if (kDebugMode) {
            debugPrint('Deliverex discarded action ${action.id} (server has newer data)');
          }
        } catch (e) {
          final error = extractServerMessage(e);
          if (kDebugMode) {
            debugPrint('Deliverex sync failed action ${action.id}: $error');
          }
          await _actionStore.markFailed(action.id!, error: error);
        }
      }

      final remaining = await _actionStore.getPendingCount();
      if (remaining == 0) {
        _syncController.add(const SyncCompleted());
        await _actionStore.removeSyncedOlderThan(const Duration(days: 7));
      } else {
        final lastError = await _actionStore.getLatestError();
        _syncController.add(
          SyncError(lastError ?? '$remaining update${remaining == 1 ? '' : 's'} failed to sync'),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> executeActionStatic({
    required PendingAction action,
    required Dio dio,
    required String token,
  }) async {
    final enrichedPayload = Map<String, dynamic>.from(action.payload);
    enrichedPayload['action_taken_at'] = action.actionTakenAt;
    enrichedPayload['sync_id'] = action.id?.toString();

    try {
      await _sendAction(action: action, dio: dio, token: token, payload: enrichedPayload);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final serverTimestamp = e.response?.data?['server_timestamp'] as String?;
        if (serverTimestamp != null &&
            action.actionTakenAt.compareTo(serverTimestamp) < 0) {
          throw DiscardActionException();
        }
        await _sendAction(
          action: action,
          dio: dio,
          token: token,
          payload: enrichedPayload,
          force: true,
        );
        return;
      }
      rethrow;
    }
  }

  static Future<void> _sendAction({
    required PendingAction action,
    required Dio dio,
    required String token,
    required Map<String, dynamic> payload,
    bool force = false,
  }) async {
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (force) headers['X-Force-Sync'] = 'true';

    final opts = Options(headers: headers);

    switch (action.actionType) {
      case 'status_update':
        await dio.post('/driver/status', data: payload, options: opts);
        break;
      case 'tracking':
        await dio.post('/driver/tracking', data: payload, options: opts);
        break;
      case 'delay':
        await dio.post('/driver/delays', data: payload, options: opts);
        break;
      case 'issue':
        final formData = FormData.fromMap({
          ...payload,
          if (action.fileBytes != null && action.fileName != null)
            'photo': MultipartFile.fromBytes(
              action.fileBytes!,
              filename: action.fileName!,
            ),
        });
        await dio.post(
          '/driver/issues',
          data: formData,
          options: Options(
            headers: headers,
            contentType: 'multipart/form-data',
          ),
        );
        break;
      case 'document':
        final formData = FormData.fromMap({
          ...payload,
          if (action.fileBytes != null && action.fileName != null)
            'file': MultipartFile.fromBytes(
              action.fileBytes!,
              filename: action.fileName!,
            ),
        });
        await dio.post(
          '/driver/documents',
          data: formData,
          options: Options(
            headers: headers,
            contentType: 'multipart/form-data',
          ),
        );
        break;
      case 'completion_proof':
        final formData = FormData.fromMap({
          ...payload,
          if (action.fileBytes != null && action.fileName != null)
            'file': MultipartFile.fromBytes(
              action.fileBytes!,
              filename: action.fileName!,
            ),
          if (payload['signature_bytes'] != null)
            'signature': MultipartFile.fromBytes(
              List<int>.from(payload['signature_bytes'] as List),
              filename: payload['signature_file_name'] as String? ?? 'signature.png',
            ),
        });
        formData.fields.removeWhere(
          (field) =>
              field.key == 'signature_bytes' ||
              field.key == 'signature_file_name',
        );
        await dio.post(
          '/driver/completion-proof',
          data: formData,
          options: Options(
            headers: headers,
            contentType: 'multipart/form-data',
          ),
        );
        break;
    }
  }

  static String extractServerMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) return message;
        final error2 = data['error']?.toString();
        if (error2 != null && error2.isNotEmpty) return error2;
      }
      if (data is String && data.isNotEmpty) return data;
    }
    return error.toString();
  }

  void dispose() {
    _syncController.close();
  }
}

sealed class SyncStatus {
  const SyncStatus();
}

class SyncIdle extends SyncStatus {
  const SyncIdle();
}

class SyncSyncing extends SyncStatus {
  const SyncSyncing({this.pendingCount = 0, this.hasError = false});
  final int pendingCount;
  final bool hasError;
}

class SyncCompleted extends SyncStatus {
  const SyncCompleted();
}

class SyncError extends SyncStatus {
  const SyncError(this.message);
  final String message;
}
