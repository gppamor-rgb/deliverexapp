import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_colors.dart';
import '../core/network_errors.dart';
import '../database/action_store.dart';
import '../models/driver_assignment.dart';
import '../repositories/assignment_repository.dart';
import '../services/driver_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_primary_button.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key, this.initialAssignmentId});

  final String? initialAssignmentId;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _driverService = DriverService();
  final _assignmentRepo = AssignmentRepository();
  final _actionStore = ActionStore();
  final _notesController = TextEditingController();
  late Future<List<DriverAssignment>> _future;
  DriverAssignment? _selectedAssignment;
  PlatformFile? _file;
  var _type = 'proof_of_delivery';
  var _submitting = false;
  String? _message;
  var _pendingUploadCount = 0;

  static const _types = [
    ('delivery_receipt', 'Delivery Receipt'),
    ('invoice', 'Invoice'),
    ('proof_of_delivery', 'Proof of Delivery'),
    ('job_order', 'Job Order'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _loadAssignments();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final pending = await _actionStore.getPendingActions();
    if (!mounted) return;
    setState(() {
      _pendingUploadCount = pending
          .where((a) => a.actionType == 'document')
          .length;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<List<DriverAssignment>> _loadAssignments() async {
    try {
      final assignments = await _assignmentRepo.fetchAssignments(page: 1);
      return assignments
          .where((assignment) => assignment.isActive || assignment.isPending)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Deliverex document_upload: assignments fetch failed: $e');
      }
      return [];
    }
  }

  Future<void> _pickFile({bool imageOnly = false}) async {
    if (imageOnly) {
      final xFile = await ImagePicker().pickImage(source: ImageSource.camera);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      setState(() {
        _file = PlatformFile(
          name: xFile.name,
          size: bytes.length,
          bytes: bytes,
        );
        _message = null;
      });
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    setState(() {
      _file = result?.files.single;
      _message = null;
    });
  }

  Future<void> _upload() async {
    final assignment = _selectedAssignment;
    final file = _file;
    final bytes = file?.bytes;
    if (assignment == null || file == null || bytes == null) {
      setState(() => _message = 'Select an assignment and document first.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      if (kDebugMode) {
        debugPrint(
          'Deliverex document upload: ${file.name}, ${bytes.length} bytes',
        );
      }
      await _driverService.uploadDocument(
        assignmentId: assignment.id,
        type: _type,
        fileName: file.name,
        bytes: bytes,
        notes: _notesController.text,
      );
      await _loadPendingCount();
      setState(() {
        _file = null;
        _notesController.clear();
        _message = 'Document uploaded successfully.';
      });
    } on DioException catch (e) {
      if (isNetworkTransportError(e)) {
        final payload = <String, dynamic>{
          'assignment_id': assignment.id,
          'type': _type,
          'action_taken_at': DateTime.now().toIso8601String(),
        };
        final notes = _notesController.text.trim();
        if (notes.isNotEmpty) {
          payload['notes'] = notes;
        }

        await _actionStore.addPendingAction(
          actionType: 'document',
          payload: payload,
          fileBytes: bytes,
          fileName: file.name,
          assignmentId: assignment.id,
        );
        await _loadPendingCount();

        setState(() {
          _file = null;
          _notesController.clear();
          _message =
              'Document saved offline. Will upload when connection is restored.';
        });
      } else {
        setState(() => _message = e.toString());
      }
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriverAssignment>>(
      future: _future,
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? const <DriverAssignment>[];
        if (_selectedAssignment == null && assignments.isNotEmpty) {
          _selectedAssignment = _initialAssignment(assignments);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              DriverEmptyState(
                title: 'Unable to load assignments',
                message: snapshot.error.toString(),
                icon: Icons.cloud_off_outlined,
              )
            else if (assignments.isEmpty)
              const DriverEmptyState(
                title: 'No active assignments',
                message:
                    'Documents can be uploaded once an assignment is active.',
                icon: Icons.description_outlined,
              )
            else ...[
              if (_pendingUploadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 20,
                          color: AppColors.accent.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_pendingUploadCount file(s) pending upload — will sync when connected',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              DriverCard(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DriverAssignment>(
                    value: _selectedAssignment,
                    isExpanded: true,
                    itemHeight: 64,
                    items: [
                      for (final assignment in assignments)
                        DropdownMenuItem(
                          value: assignment,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'ASSIGNMENT',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                assignment.displayJobNumber,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedAssignment = value),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('DOCUMENT'),
              if (_file == null)
                InkWell(
                  onTap: _showUploadOptions,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xffcbd5e1),
                        width: 1.6,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 36,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tap to add document',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                DriverCard(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: AppColors.accent.withValues(alpha: 0.1),
                          child: (_file!.extension ?? '') == 'pdf'
                              ? const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppColors.danger,
                                  size: 28,
                                )
                              : Image.memory(_file!.bytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _file!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSize(_file!.size),
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.mutedText,
                        onPressed: _removeFile,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const _SectionLabel('DOCUMENT TYPE'),
              DriverCard(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    itemHeight: 52,
                    items: [
                      for (final type in _types)
                        DropdownMenuItem(
                          value: type.$1,
                          child: Row(
                            children: [
                              Icon(
                                _iconForType(type.$1),
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                type.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Notes (optional)'),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Any remarks about this document...',
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('successfully')
                        ? AppColors.success
                        : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              DriverPrimaryButton(
                label: 'Submit Document',
                loading: _submitting,
                onPressed: _upload,
              ),
            ],
          ],
        );
      },
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Use your camera to capture a document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(imageOnly: true);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.upload_rounded,
                    color: AppColors.accent,
                  ),
                ),
                title: const Text(
                  'Upload from Device',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Browse files (JPG, PNG, PDF)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _removeFile() {
    setState(() {
      _file = null;
      _message = null;
    });
  }

  DriverAssignment _initialAssignment(List<DriverAssignment> assignments) {
    final initialId = widget.initialAssignmentId;
    if (initialId != null) {
      for (final assignment in assignments) {
        if (assignment.id == initialId) {
          return assignment;
        }
      }
    }
    return assignments.first;
  }

  static IconData _iconForType(String type) {
    return switch (type) {
      'delivery_receipt' => Icons.receipt_long_rounded,
      'invoice' => Icons.request_quote_rounded,
      'proof_of_delivery' => Icons.verified_rounded,
      'job_order' => Icons.assignment_rounded,
      _ => Icons.description_rounded,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
