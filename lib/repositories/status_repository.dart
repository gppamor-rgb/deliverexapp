import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/network_errors.dart';
import '../database/action_store.dart';
import '../services/connectivity_service.dart';
import '../services/driver_service.dart';

class StatusUpdateResult {
  final bool synced;
  final int? pendingActionId;
  final String? message;

  const StatusUpdateResult({
    required this.synced,
    this.pendingActionId,
    this.message,
  });
}

class StatusRepository {
  final _connectivity = ConnectivityService.instance;
  final _actionStore = ActionStore();
  final _driverService = DriverService();

  Future<StatusUpdateResult> postStatus({
    required String assignmentId,
    required String status,
    double? latitude,
    double? longitude,
    String? actionTakenAt,
  }) async {
    final effectiveActionTakenAt =
        actionTakenAt ?? DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'assignment_id': assignmentId,
      'status': status,
      'action_taken_at': effectiveActionTakenAt,
    };
    if (latitude != null) {
      payload['latitude'] = latitude;
    }
    if (longitude != null) {
      payload['longitude'] = longitude;
    }

    if (!_connectivity.isOnline) {
      final id = await _actionStore.addPendingAction(
        actionType: 'status_update',
        payload: payload,
        assignmentId: assignmentId,
        actionTakenAt: effectiveActionTakenAt,
      );
      if (kDebugMode) {
        debugPrint(
          'Deliverex saved status update offline (action id: $id): $status',
        );
      }
      return StatusUpdateResult(
        synced: false,
        pendingActionId: id,
        message:
            'Status saved offline at ${_formatActionTime(effectiveActionTakenAt)}. Will sync when connection is restored.',
      );
    }

    try {
      await _driverService.postStatus(
        assignmentId: assignmentId,
        status: status,
        latitude: latitude,
        longitude: longitude,
        actionTakenAt: effectiveActionTakenAt,
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        final id = await _actionStore.addPendingAction(
          actionType: 'status_update',
          payload: payload,
          assignmentId: assignmentId,
          actionTakenAt: effectiveActionTakenAt,
        );
        if (kDebugMode) {
          debugPrint(
            'Deliverex saved status update offline after failed attempt (action id: $id): $status',
          );
        }
        return StatusUpdateResult(
          synced: false,
          pendingActionId: id,
          message:
              'Status saved offline at ${_formatActionTime(effectiveActionTakenAt)}. Will sync when connection is restored.',
        );
      }
      rethrow;
    }
  }

  Future<StatusUpdateResult> postTracking({
    required String assignmentId,
    required double latitude,
    required double longitude,
    String? actionTakenAt,
  }) async {
    final effectiveActionTakenAt =
        actionTakenAt ?? DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'assignment_id': assignmentId,
      'latitude': latitude,
      'longitude': longitude,
      'action_taken_at': effectiveActionTakenAt,
      'captured_at': effectiveActionTakenAt,
    };

    if (!_connectivity.isOnline) {
      await _actionStore.addPendingAction(
        actionType: 'tracking',
        payload: payload,
        assignmentId: assignmentId,
        actionTakenAt: effectiveActionTakenAt,
      );
      return const StatusUpdateResult(
        synced: false,
        message: 'Tracking saved offline.',
      );
    }

    try {
      await _driverService.postTracking(
        assignmentId: assignmentId,
        latitude: latitude,
        longitude: longitude,
        capturedAt: effectiveActionTakenAt,
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        await _actionStore.addPendingAction(
          actionType: 'tracking',
          payload: payload,
          assignmentId: assignmentId,
          actionTakenAt: effectiveActionTakenAt,
        );
        return const StatusUpdateResult(
          synced: false,
          message: 'Tracking saved offline.',
        );
      }
      rethrow;
    }
  }

  Future<StatusUpdateResult> reportDelay({
    required String assignmentId,
    required String delayReason,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'assignment_id': assignmentId,
      'delay_reason': delayReason,
      'action_taken_at': DateTime.now().toIso8601String(),
      if (notes != null && notes.trim().isNotEmpty) 'delay_notes': notes.trim(),
    };

    if (!_connectivity.isOnline) {
      final id = await _actionStore.addPendingAction(
        actionType: 'delay',
        payload: payload,
        assignmentId: assignmentId,
      );
      return StatusUpdateResult(
        synced: false,
        pendingActionId: id,
        message: 'Delay report saved offline.',
      );
    }

    try {
      await _driverService.reportDelay(
        assignmentId: assignmentId,
        delayReason: delayReason,
        notes: notes,
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        await _actionStore.addPendingAction(
          actionType: 'delay',
          payload: payload,
          assignmentId: assignmentId,
        );
        return const StatusUpdateResult(
          synced: false,
          message: 'Delay report saved offline.',
        );
      }
      rethrow;
    }
  }

  Future<StatusUpdateResult> submitCompletionProof({
    required String assignmentId,
    required String proofType,
    String? documentType,
    required String proofFileName,
    required List<int> proofBytes,
    String? receiverName,
    String? receiverContact,
    String? deliveryNotes,
    String? signatureFileName,
    List<int>? signatureBytes,
  }) async {
    final actionTakenAt = DateTime.now().toIso8601String();

    final completionPayload = <String, dynamic>{
      'assignment_id': assignmentId,
      'proof_type': proofType,
      'action_taken_at': actionTakenAt,
    };
    if (documentType != null && documentType.trim().isNotEmpty) {
      completionPayload['document_type'] = documentType.trim();
    }
    if (receiverName != null && receiverName.trim().isNotEmpty) {
      completionPayload['receiver_name'] = receiverName.trim();
    }
    if (receiverContact != null && receiverContact.trim().isNotEmpty) {
      completionPayload['receiver_contact'] = receiverContact.trim();
    }
    if (deliveryNotes != null && deliveryNotes.trim().isNotEmpty) {
      completionPayload['delivery_notes'] = deliveryNotes.trim();
    }
    if (signatureFileName != null && signatureBytes != null) {
      completionPayload['signature_file_name'] = signatureFileName;
      completionPayload['signature_bytes'] = signatureBytes;
    }

    final statusPayload = <String, dynamic>{
      'assignment_id': assignmentId,
      'status': 'completed',
      'action_taken_at': actionTakenAt,
    };

    Future<int> queueCompletionProof() => _actionStore.addPendingAction(
      actionType: 'completion_proof',
      payload: completionPayload,
      fileBytes: proofBytes,
      fileName: proofFileName,
      assignmentId: assignmentId,
      actionTakenAt: actionTakenAt,
    );

    Future<int> queueStatusUpdate() => _actionStore.addPendingAction(
      actionType: 'status_update',
      payload: statusPayload,
      assignmentId: assignmentId,
      actionTakenAt: actionTakenAt,
    );

    if (!_connectivity.isOnline) {
      await queueCompletionProof();
      await queueStatusUpdate();
      return StatusUpdateResult(
        synced: false,
        message:
            'Completion saved offline at ${_formatActionTime(actionTakenAt)}. Will sync when connection is restored.',
      );
    }

    try {
      await _driverService.uploadCompletionProof(
        assignmentId: assignmentId,
        proofType: proofType,
        documentType: documentType,
        fileName: proofFileName,
        bytes: proofBytes,
        receiverName: receiverName,
        receiverContact: receiverContact,
        deliveryNotes: deliveryNotes,
        signatureFileName: signatureFileName,
        signatureBytes: signatureBytes,
      );
      await _driverService.postStatus(
        assignmentId: assignmentId,
        status: 'completed',
        actionTakenAt: actionTakenAt,
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        await queueCompletionProof();
        await queueStatusUpdate();
        return StatusUpdateResult(
          synced: false,
          message:
              'Completion saved offline at ${_formatActionTime(actionTakenAt)}. Will sync when connection is restored.',
        );
      }
      rethrow;
    }
  }

  String _formatActionTime(String actionTakenAt) {
    final parsed = DateTime.tryParse(actionTakenAt);
    if (parsed == null) return actionTakenAt;
    return DateFormat('h:mm a').format(parsed.toLocal());
  }
}
