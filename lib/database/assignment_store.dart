import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/driver_assignment.dart';
import 'database_helper.dart';

class AssignmentStore {
  final _db = DatabaseHelper.instance;

  Future<void> cacheAssignments(List<DriverAssignment> assignments) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    final driverId = await _db.getSetting('current_driver_id') ?? '';

    for (final assignment in assignments) {
      batch.insert('cached_assignments', {
        'id': assignment.id,
        'data': jsonEncode(assignment.raw),
        'cached_at': now,
        'driver_id': driverId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheAssignment(DriverAssignment assignment) async {
    final db = await _db.database;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    await db.insert('cached_assignments', {
      'id': assignment.id,
      'data': jsonEncode(assignment.raw),
      'cached_at': DateTime.now().toIso8601String(),
      'driver_id': driverId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DriverAssignment?> getCachedAssignment(String id) async {
    final db = await _db.database;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    final rows = await db.query(
      'cached_assignments',
      where: 'id = ? AND driver_id IN (?, ?)',
      whereArgs: [id, driverId, ''],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data =
        jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    return DriverAssignment.fromJson(data);
  }

  Future<List<DriverAssignment>> getCachedAssignments() async {
    final db = await _db.database;
    final driverId = await _db.getSetting('current_driver_id') ?? '';
    final rows = await db.query(
      'cached_assignments',
      where: 'driver_id IN (?, ?)',
      whereArgs: [driverId, ''],
      orderBy: 'cached_at DESC',
    );
    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return DriverAssignment.fromJson(data);
    }).toList();
  }

  Future<void> clearCache() async {
    final db = await _db.database;
    await db.delete('cached_assignments');
  }

  Future<void> removeCached(String id) async {
    final db = await _db.database;
    await db.delete('cached_assignments', where: 'id = ?', whereArgs: [id]);
  }
}
