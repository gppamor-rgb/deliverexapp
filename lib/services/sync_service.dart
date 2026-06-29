import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/action_timestamp.dart';
import '../core/document_type_mapper.dart';
import '../database/action_store.dart';
import 'api_client.dart';
import 'offline_file_store.dart';
import 'session_service.dart';

class DiscardActionException implements Exception {}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _actionStore = ActionStore();
  final _apiClient = ApiClient();
  final _sessionService = SessionService.instance;

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

      final String? token;
      try {
        token = await _sessionService.validAccessToken(
          role: MobileSessionRole.driver,
          dio: _apiClient.dio,
        );
      } on SessionExpiredException catch (error) {
        _syncController.add(SyncError(error.message));
        return;
      }
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
            debugPrint(
              'Deliverex synced action ${action.id}: ${action.actionType}',
            );
          }
        } on DiscardActionException {
          await _actionStore.markSynced(action.id!);
          if (kDebugMode) {
            debugPrint(
              'Deliverex discarded action ${action.id} (server has newer data)',
            );
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
          SyncError(
            lastError ??
                '$remaining update${remaining == 1 ? '' : 's'} failed to sync',
          ),
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
    enrichedPayload.remove('synced_at');
    enrichedPayload.remove('captured_at');
    enrichedPayload.remove('file_size');
    enrichedPayload.remove('signature_file_size');
    enrichedPayload.addAll(actionTimestampFields(action.actionTakenAt));
    if (action.actionType == 'tracking') {
      enrichedPayload['captured_at'] = action.actionTakenAt;
    }
    enrichedPayload['sync_id'] = action.id?.toString();
    if (kDebugMode) {
      debugPrint(
        'Deliverex sync replay action id=${action.id} '
        'type=${action.actionType} '
        'actionTakenAt=${action.actionTakenAt} '
        'syncTime=${DateTime.now().toIso8601String()} '
        'action_timestamp=${enrichedPayload['action_timestamp']} '
        'action_taken_at=${enrichedPayload['action_taken_at']} '
        'captured_at=${enrichedPayload['captured_at']}',
      );
    }

    try {
      await _sendAction(
        action: action,
        dio: dio,
        token: token,
        payload: enrichedPayload,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final serverTimestamp =
            e.response?.data?['server_timestamp'] as String?;
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

    final opts = Options(
      headers: headers,
      extra: const {'sessionRole': 'driver'},
    );

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
        final photoBytes = await _queuedFileBytes(action);
        final formData = FormData.fromMap({
          ...payload,
          if (photoBytes != null && action.fileName != null)
            'photo': MultipartFile.fromBytes(
              photoBytes,
              filename: action.fileName!,
            ),
        });
        await dio.post(
          '/driver/issues',
          data: formData,
          options: Options(
            headers: headers,
            extra: const {'sessionRole': 'driver'},
            contentType: 'multipart/form-data',
          ),
        );
        break;
      case 'document':
        final documentBytes = await _queuedFileBytes(action);
        final rawType = payload['type']?.toString();
        final normalizedType = rawType == null
            ? null
            : normalizeDocumentType(rawType);
        final rawDocumentType = payload['document_type']?.toString();
        final normalizedDocumentType = rawDocumentType == null
            ? normalizedType
            : normalizeDocumentType(rawDocumentType);
        final formData = FormData.fromMap({
          ...payload,
          'type': ?normalizedType,
          'document_type': ?normalizedDocumentType,
          if (documentBytes != null && action.fileName != null)
            'file': MultipartFile.fromBytes(
              documentBytes,
              filename: action.fileName!,
            ),
        });
        await dio.post(
          '/driver/documents',
          data: formData,
          options: Options(
            headers: headers,
            extra: const {'sessionRole': 'driver'},
            contentType: 'multipart/form-data',
          ),
        );
        break;
      case 'completion_proof':
        final proofBytes = await _queuedFileBytes(action);
        final signatureBytes = await _queuedSignatureBytes(payload);
        final formData = FormData.fromMap({
          ...payload,
          if (proofBytes != null && action.fileName != null)
            'file': MultipartFile.fromBytes(
              proofBytes,
              filename: action.fileName!,
            ),
          if (signatureBytes != null)
            'signature': MultipartFile.fromBytes(
              signatureBytes,
              filename:
                  payload['signature_file_name'] as String? ?? 'signature.png',
            ),
        });
        formData.fields.removeWhere(
          (field) =>
              field.key == 'signature_bytes' ||
              field.key == 'signature_file_name' ||
              field.key == 'signature_file_path',
        );
        await dio.post(
          '/driver/completion-proof',
          data: formData,
          options: Options(
            headers: headers,
            extra: const {'sessionRole': 'driver'},
            contentType: 'multipart/form-data',
          ),
        );
        break;
    }
  }

  static Future<List<int>?> _queuedFileBytes(PendingAction action) async {
    if (action.filePath != null && action.filePath!.isNotEmpty) {
      return OfflineFileStore.instance.readBytes(action.filePath!);
    }
    if (action.fileBytes == null &&
        (action.actionType == 'document' ||
            action.actionType == 'completion_proof')) {
      throw const OfflineFileMissingException(
        'Queued upload file is no longer available. Please upload it again.',
      );
    }
    return action.fileBytes;
  }

  static Future<List<int>?> _queuedSignatureBytes(
    Map<String, dynamic> payload,
  ) async {
    final path = payload['signature_file_path']?.toString();
    if (path != null && path.isNotEmpty) {
      return OfflineFileStore.instance.readBytes(path);
    }
    final bytes = payload['signature_bytes'];
    if (bytes is List) {
      return List<int>.from(bytes);
    }
    return null;
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
