import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  }) async {
    final payload = <String, dynamic>{
      'assignment_id': assignmentId,
      'status': status,
      'action_taken_at': DateTime.now().toIso8601String(),
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
      );
      if (kDebugMode) {
        debugPrint(
          'Deliverex saved status update offline (action id: $id): $status',
        );
      }
      return StatusUpdateResult(
        synced: false,
        pendingActionId: id,
        message: 'Status saved offline. Will sync when connection is restored.',
      );
    }

    try {
      await _driverService.postStatus(
        assignmentId: assignmentId,
        status: status,
        latitude: latitude,
        longitude: longitude,
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        final id = await _actionStore.addPendingAction(
          actionType: 'status_update',
          payload: payload,
          assignmentId: assignmentId,
        );
        if (kDebugMode) {
          debugPrint(
            'Deliverex saved status update offline after failed attempt (action id: $id): $status',
          );
        }
        return StatusUpdateResult(
          synced: false,
          pendingActionId: id,
          message: 'Status saved offline. Will sync when connection is restored.',
        );
      }
      rethrow;
    }
  }

  Future<StatusUpdateResult> postTracking({
    required String assignmentId,
    required double latitude,
    required double longitude,
  }) async {
    final payload = <String, dynamic>{
      'assignment_id': assignmentId,
      'latitude': latitude,
      'longitude': longitude,
      'action_taken_at': DateTime.now().toIso8601String(),
    };

    if (!_connectivity.isOnline) {
      await _actionStore.addPendingAction(
        actionType: 'tracking',
        payload: payload,
        assignmentId: assignmentId,
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
      );
      return const StatusUpdateResult(synced: true);
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        await _actionStore.addPendingAction(
          actionType: 'tracking',
          payload: payload,
          assignmentId: assignmentId,
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
      if (_isConnectionError(e)) {
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

  bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}
