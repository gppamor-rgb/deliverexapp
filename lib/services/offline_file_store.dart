import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OfflineFileStore {
  OfflineFileStore._();
  static final OfflineFileStore instance = OfflineFileStore._();

  Future<String> saveBytes({
    required String actionType,
    required String fileName,
    required List<int> bytes,
  }) async {
    final directory = await _offlineDirectory();
    final safeName = _safeFileName(fileName);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path = p.join(directory.path, '${actionType}_${timestamp}_$safeName');
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<List<int>> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw OfflineFileMissingException(path);
    }
    return file.readAsBytes();
  }

  Future<void> deletePath(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteActionFiles({
    String? filePath,
    Map<String, dynamic> payload = const {},
  }) async {
    await deletePath(filePath);
    final signaturePath = payload['signature_file_path']?.toString();
    await deletePath(signaturePath);
  }

  Future<Directory> _offlineDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'offline_uploads'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _safeFileName(String fileName) {
    final base = p.basename(fileName.trim().isEmpty ? 'upload.bin' : fileName);
    return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

class OfflineFileMissingException implements Exception {
  const OfflineFileMissingException(this.path);

  final String path;

  @override
  String toString() => 'Queued upload file is missing: $path';
}
