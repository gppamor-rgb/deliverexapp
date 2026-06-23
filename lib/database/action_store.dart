import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

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

  Future<int> addPendingAction({
    required String actionType,
    required Map<String, dynamic> payload,
    List<int>? fileBytes,
    String? fileName,
    String? filePath,
    String? assignmentId,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    return db.insert('offline_actions', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'file_path': filePath,
      'file_bytes': fileBytes,
      'file_name': fileName,
      'assignment_id': assignmentId,
      'action_taken_at': now,
      'status': 'pending',
      'retry_count': 0,
      'created_at': now,
    });
  }

  Future<List<PendingAction>> getPendingActions() async {
    final db = await _db.database;
    final rows = await db.query(
      'offline_actions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingAction.fromMap).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_actions WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSynced(int id) async {
    final db = await _db.database;
    await db.update(
      'offline_actions',
      {
        'status': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, {String? error}) async {
    final db = await _db.database;
    final action = await db.query(
      'offline_actions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (action.isEmpty) return;

    final current = PendingAction.fromMap(action.first);
    final newRetryCount = current.retryCount + 1;

    if (newRetryCount >= 3) {
      await db.update(
        'offline_actions',
        {
          'status': 'failed',
          'retry_count': newRetryCount,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        'offline_actions',
        {
          'status': 'pending',
          'retry_count': newRetryCount,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
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

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('offline_actions');
  }
}
