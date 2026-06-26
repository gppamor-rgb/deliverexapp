import 'package:dio/dio.dart';

import '../core/network_errors.dart';
import '../database/assignment_store.dart';
import '../models/driver_assignment.dart';
import '../services/connectivity_service.dart';
import '../services/driver_service.dart';

class AssignmentRepository {
  final _service = DriverService();
  final _connectivity = ConnectivityService.instance;
  final _cache = AssignmentStore();

  Future<List<DriverAssignment>> fetchAssignments({
    int page = 1,
    String? status,
  }) async {
    if (!_connectivity.isOnline) {
      final cached = await _cache.getCachedAssignments();
      return cached;
    }

    try {
      final pageData = await _service.fetchAssignments(
        page: page,
        status: status,
      );

      if (page == 1) {
        await _cache.cacheAssignments(pageData.assignments);
      }
      return pageData.assignments;
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        final cached = await _cache.getCachedAssignments();
        return cached;
      }
      rethrow;
    }
  }

  Future<DriverAssignment?> fetchAssignment(String id) async {
    if (!_connectivity.isOnline) {
      return _cache.getCachedAssignment(id);
    }

    try {
      final assignment = await _service.fetchAssignment(id);
      await _cache.cacheAssignment(assignment);
      return assignment;
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        return _cache.getCachedAssignment(id);
      }
      rethrow;
    }
  }
}
