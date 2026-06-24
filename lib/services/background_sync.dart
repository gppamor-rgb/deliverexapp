import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../database/action_store.dart';
import '../database/database_helper.dart';
import 'api_client.dart';
import 'sync_service.dart';

const backgroundSyncTaskName = 'deliverex_background_sync';

@pragma('vm:entry-point')
void backgroundSyncCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) {
      debugPrint('Deliverex background sync started: $task');
    }

    try {
      final dbHelper = DatabaseHelper.instance;
      final token = await dbHelper.getSetting('deliverex_driver_token');
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('Deliverex background sync: no token found');
        }
        return false;
      }

      final actionStore = ActionStore();
      final pending = await actionStore.getPendingActions();
      if (pending.isEmpty) {
        if (kDebugMode) {
          debugPrint('Deliverex background sync: no pending actions');
        }
        return true;
      }

      final dio = ApiClient().dio;

      for (final action in pending) {
        try {
          await SyncService.executeActionStatic(
            action: action,
            dio: dio,
            token: token,
          );
          await actionStore.markSynced(action.id!);
          if (kDebugMode) {
            debugPrint(
              'Deliverex background synced action ${action.id}: ${action.actionType}',
            );
          }
        } on DiscardActionException {
          await actionStore.markSynced(action.id!);
          if (kDebugMode) {
            debugPrint(
              'Deliverex background discarded action ${action.id} (server has newer data)',
            );
          }
        } catch (e) {
          final error = SyncService.extractServerMessage(e);
          if (kDebugMode) {
            debugPrint(
              'Deliverex background sync failed action ${action.id}: $error',
            );
          }
          await actionStore.markFailed(action.id!, error: error);
        }
      }

      if (kDebugMode) {
        final remaining = await actionStore.getPendingCount();
        debugPrint('Deliverex background sync completed. Remaining: $remaining');
      }

      if (pending.isNotEmpty) {
        await actionStore.removeSyncedOlderThan(const Duration(days: 7));
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Deliverex background sync error: $e');
      }
      return false;
    }
  });
}
