import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/action_timestamp.dart';
import '../services/offline_file_store.dart';
import 'database_helper.dart';

const _actionMetadataColumns = [
  'id',
  'action_type',
  'payload',
  'file_path',
  'file_name',
  'assignment_id',
  'action_taken_at',
  'status',
  'retry_count',
  'last_error',
  'synced_at',
  'created_at',
];

class PendingAction {
  final int? id;
  final String actionType;
  final Map<String, dynamic> payload;
  final String? filePath;
  final List<int>? fileBytes;
  final String? fileName;
  final String? assignmentId;
  final String actionTakenAt;
  final String status;
  final int retryCount;
  final String? lastError;
  final String? syncedAt;
  final String createdAt;

  const PendingAction({
    this.id,
    required this.actionType,
    required this.payload,
    this.filePath,
    this.fileBytes,
    this.fileName,
    this.assignmentId,
    required this.actionTakenAt,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastError,
    this.syncedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'action_type': actionType,
    'payload': jsonEncode(payload),
    'file_path': filePath,
    'file_bytes': fileBytes,
    'file_name': fileName,
    'assignment_id': assignmentId,
    'action_taken_at': actionTakenAt,
    'status': status,
    'retry_count': retryCount,
    'last_error': lastError,
    'synced_at': syncedAt,
    'created_at': createdAt,
  };

  factory PendingAction.fromMap(Map<String, dynamic> map) => PendingAction(
    id: map['id'] as int?,
    actionType: map['action_type'] as String,
    payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
    filePath: map['file_path'] as String?,
    fileBytes: map['file_bytes'] as List<int>?,
    fileName: map['file_name'] as String?,
    assignmentId: map['assignment_id'] as String?,
    actionTakenAt: map['action_taken_at'] as String,
    status: map['status'] as String? ?? 'pending',
    retryCount: map['retry_count'] as int? ?? 0,
    lastError: map['last_error'] as String?,
    syncedAt: map['synced_at'] as String?,
    createdAt: map['created_at'] as String,
  );
}

class ActionStore {
  final _db = DatabaseHelper.instance;
  final _fileStore = OfflineFileStore.instance;

  Future<int> addPendingAction({
    required String actionType,
    required Map<String, dynamic> payload,
    List<int>? fileBytes,
    String? fileName,
    String? filePath,
    String? assignmentId,
    String? actionTakenAt,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final fallbackActionTakenAt = actionTimestampNow();
    final effectiveActionTakenAt =
        actionTakenAt ??
        payload['action_timestamp']?.toString() ??
        payload['action_taken_at']?.toString() ??
        fallbackActionTakenAt;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    final effectivePayload = Map<String, dynamic>.from(payload);
    if (fileBytes != null) {
      effectivePayload.putIfAbsent('file_size', () => fileBytes.length);
    }
    final storedFilePath =
        filePath ??
        (fileBytes != null && fileName != null
            ? await _fileStore.saveBytes(
                actionType: actionType,
                fileName: fileName,
                bytes: fileBytes,
              )
            : null);

    return db.insert('offline_actions', {
      'action_type': actionType,
      'payload': jsonEncode(effectivePayload),
      'file_path': storedFilePath,
      'file_bytes': storedFilePath == null ? fileBytes : null,
      'file_name': fileName,
      'assignment_id': assignmentId,
      'action_taken_at': effectiveActionTakenAt,
      'status': 'pending',
      'retry_count': 0,
      'created_at': now,
      'driver_id': driverId,
    });
  }

  Future<List<PendingAction>> getPendingActions() async {
    final db = await _db.database;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    final rows = await db.query(
      'offline_actions',
      columns: _actionMetadataColumns,
      where: 'status IN (?, ?) AND driver_id IN (?, ?)',
      whereArgs: ['pending', 'failed', driverId, ''],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingAction.fromMap).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _db.database;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_actions WHERE status IN (?, ?) AND driver_id IN (?, ?)',
      ['pending', 'failed', driverId, ''],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSynced(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'offline_actions',
      columns: _actionMetadataColumns,
      where: 'id = ?',
      whereArgs: [id],
    );
    final action = rows.isEmpty ? null : PendingAction.fromMap(rows.first);
    await db.update(
      'offline_actions',
      {'status': 'synced', 'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (action != null) {
      await _fileStore.deleteActionFiles(
        filePath: action.filePath,
        payload: action.payload,
      );
    }
  }

  Future<void> markFailed(int id, {String? error}) async {
    final db = await _db.database;
    final action = await db.query(
      'offline_actions',
      columns: _actionMetadataColumns,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (action.isEmpty) return;

    final current = PendingAction.fromMap(action.first);
    final newRetryCount = current.retryCount + 1;

    await db.update(
      'offline_actions',
      {'status': 'failed', 'retry_count': newRetryCount, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeSyncedOlderThan(Duration age) async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(age).toIso8601String();
    await db.delete(
      'offline_actions',
      where: 'status = ? AND synced_at < ?',
      whereArgs: ['synced', cutoff],
    );
  }

  Future<String?> getLatestError({String? actionType}) async {
    final db = await _db.database;
    final where = StringBuffer('last_error IS NOT NULL');
    final args = <Object?>[];
    if (actionType != null && actionType.isNotEmpty) {
      where.write(' AND action_type = ?');
      args.add(actionType);
    }
    final rows = await db.query(
      'offline_actions',
      columns: ['last_error'],
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['last_error'] as String?;
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    final rows = await db.query(
      'offline_actions',
      columns: ['file_path', 'payload'],
    );
    for (final row in rows) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      await _fileStore.deleteActionFiles(
        filePath: row['file_path'] as String?,
        payload: payload,
      );
    }
    await db.delete('offline_actions');
  }
}
