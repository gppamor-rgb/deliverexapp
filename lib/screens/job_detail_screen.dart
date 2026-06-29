import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/backend_error_messages.dart';
import '../core/delivery_status.dart';
import '../core/formatters.dart';
import '../core/network_errors.dart';
import '../database/action_store.dart';
import '../models/driver_assignment.dart';
import '../repositories/assignment_repository.dart';
import '../repositories/status_repository.dart';
import '../services/connectivity_service.dart';
import '../services/driver_service.dart';
import '../services/sync_service.dart';
import '../widgets/driver/connectivity_banner.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';
import '../widgets/driver/driver_primary_button.dart';
import '../widgets/driver/driver_status_chip.dart';
import 'document_upload_screen.dart';
import 'notifications_screen.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _driverService = DriverService();
  final _statusRepository = StatusRepository();
  final _assignmentRepository = AssignmentRepository();
  final _actionStore = ActionStore();
  final _connectivity = ConnectivityService.instance;
  final _syncService = SyncService.instance;
  late Future<DriverAssignment> _future;
  var _submitting = false;
  String? _message;
  var _unreadCount = 0;
  var _isOnline = true;
  var _isSyncing = false;
  var _pendingCount = 0;
  var _hasError = false;
  var _syncError = '';
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<SyncStatus>? _syncSub;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadUnreadCount();
    _isOnline = _connectivity.isOnline;
    _connectivitySub = _connectivity.connectivityStream.listen(
      _onConnectivityChanged,
    );
    _syncSub = _syncService.syncStream.listen(_onSyncStatusChanged);
    _loadPendingCount();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _onConnectivityChanged(bool online) async {
    if (!mounted) return;
    setState(() => _isOnline = online);
    await _loadPendingCount();
    if (online && _pendingCount > 0) {
      _syncService.processQueue();
    }
  }

  void _onSyncStatusChanged(SyncStatus status) {
    if (!mounted) return;
    _loadPendingCount();
    if (status is SyncSyncing) {
      setState(() {
        _isSyncing = true;
        _pendingCount = status.pendingCount;
        _hasError = status.hasError;
      });
    } else if (status is SyncCompleted || status is SyncIdle) {
      setState(() {
        _isSyncing = false;
        _hasError = false;
        _syncError = '';
      });
      if (status is SyncCompleted) {
        _refresh();
      }
    } else if (status is SyncError) {
      _loadPendingCount();
      setState(() {
        _isSyncing = false;
        _hasError = true;
        _syncError = status.message;
      });
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await _actionStore.getPendingCount();
      if (mounted) setState(() => _pendingCount = count);
    } catch (_) {}
  }

  Future<DriverAssignment> _load() async {
    final assignment = await _assignmentRepository.fetchAssignment(
      widget.assignmentId,
    );
    if (assignment == null) {
      throw Exception('No cached data available for this delivery.');
    }
    return assignment;
  }

  Future<void> _refresh() async {
    try {
      final assignment = await _load();
      if (mounted) {
        setState(() => _future = Future.value(assignment));
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final page = await _driverService.fetchNotifications(page: 1);
      if (mounted) {
        setState(() {
          _unreadCount = page.notifications
              .where((item) => !item.isRead)
              .length;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  Future<void> _updateStatus(
    DriverAssignment assignment,
    String nextStatus,
  ) async {
    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final actionTakenAt = DateTime.now().toIso8601String();
      final position = _statusRequiresLocation(nextStatus)
          ? await _capturePosition()
          : null;

      if (kDebugMode) {
        debugPrint('Deliverex tapped status action');
        debugPrint('Deliverex status update assignment id: ${assignment.id}');
        debugPrint(
          'Deliverex status update current status: ${assignment.status}',
        );
        debugPrint('Deliverex status update next status: $nextStatus');
        if (position != null) {
          debugPrint('Deliverex status update latitude: ${position.latitude}');
          debugPrint(
            'Deliverex status update longitude: ${position.longitude}',
          );
        }
      }

      final result = await _statusRepository.postStatus(
        assignmentId: assignment.id,
        status: nextStatus,
        latitude: position?.latitude,
        longitude: position?.longitude,
        actionTakenAt: actionTakenAt,
      );

      if (kDebugMode) {
        debugPrint(
          'Deliverex status update result synced=${result.synced} actionId=${result.pendingActionId}',
        );
      }

      if (position != null) {
        await _tryPostTracking(assignment.id, position, actionTakenAt);
      }

      final refreshedFuture = _load();
      setState(() {
        _message = result.synced
            ? 'Status updated successfully.'
            : (result.message ??
                  'Status saved offline. Will sync when connected.');
        _future = refreshedFuture;
      });

      if (!result.synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message ?? 'Saved offline for later sync.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on _LocationStatusException catch (error) {
      if (kDebugMode) {
        debugPrint('Deliverex status update GPS error: ${error.debugMessage}');
      }
      if (mounted) {
        setState(() => _message = error.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } on DioException catch (error) {
      final message = _backendErrorMessage(error);
      if (kDebugMode) {
        debugPrint(
          'Deliverex status update request URL: ${error.requestOptions.uri}',
        );
        debugPrint('Deliverex status update assignment id: ${assignment.id}');
        debugPrint(
          'Deliverex status update current status: ${assignment.status}',
        );
        debugPrint('Deliverex status update next status: $nextStatus');
        debugPrint(
          'Deliverex status update Dio error status code: ${error.response?.statusCode}',
        );
        debugPrint(
          'Deliverex status update Dio error response body: ${error.response?.data}',
        );
        debugPrint('Deliverex status update Dio error type: ${error.type}');
        debugPrint(
          'Deliverex status update Dio error message: ${error.message}',
        );
      }
      if (mounted) {
        final displayMessage = 'Status update failed: $message';
        setState(() => _message = displayMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (error) {
      final message = error.toString();
      if (kDebugMode) {
        debugPrint('Deliverex status update unexpected error: $error');
      }
      if (mounted) {
        setState(() => _message = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handlePrimaryAction(DriverAssignment assignment) async {
    final nextStatus = assignment.nextStatus;
    if (nextStatus == null) {
      return;
    }

    if (canonicalDeliveryStatus(nextStatus) == deliveryStatusCompleted) {
      if (kDebugMode) {
        debugPrint('Deliverex Complete Delivery tapped');
      }
      await _showCompleteDeliverySheet(assignment);
      return;
    }

    final confirmed = await _showStatusConfirmDialog(
      currentLabel: assignment.statusLabel,
      nextLabel: assignment.allowedAction,
    );
    if (confirmed != true) return;

    await _updateStatus(assignment, nextStatus);
  }

  Future<bool> _showStatusConfirmDialog({
    required String currentLabel,
    required String nextLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Status'),
        content: Text('Change status from $currentLabel to $nextLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  Future<void> _showCompleteDeliverySheet(DriverAssignment assignment) async {
    if (kDebugMode) {
      debugPrint('Deliverex complete delivery bottom sheet opened');
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteDeliverySheet(
        assignment: assignment,
        onSubmit: (request) => _submitCompletionProof(assignment, request),
      ),
    );
  }

  Future<void> _submitCompletionProof(
    DriverAssignment assignment,
    _CompletionProofRequest request,
  ) async {
    final documentType = request.proofType == 'ocr_document'
        ? request.documentType
        : null;

    if (kDebugMode) {
      debugPrint(
        'Deliverex complete delivery submit: '
        'assignment_id: ${assignment.id}, '
        'proof_type: ${request.proofType}, '
        'document_type: $documentType, '
        'proof_file: ${request.proofFileName}, '
        'signature_file: ${request.signatureFileName}',
      );
    }

    try {
      final result = await _statusRepository.submitCompletionProof(
        assignmentId: assignment.id,
        proofType: request.proofType,
        documentType: documentType,
        proofFileName: request.proofFileName,
        proofBytes: request.proofBytes,
        receiverName: request.receiverName,
        receiverContact: request.receiverContact,
        deliveryNotes: request.deliveryNotes,
        signatureFileName: request.signatureFileName,
        signatureBytes: request.signatureBytes,
      );

      final refreshedFuture = _load();
      setState(() {
        _message = result.synced
            ? 'Delivery completed successfully.'
            : (result.message ??
                  'Completion saved offline. Will sync when connected.');
        _future = refreshedFuture;
      });

      if (!result.synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message ?? 'Saved offline for later sync.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Deliverex complete delivery Dio error: ${error.response?.statusCode}',
        );
      }
      throw _CompletionProofException(_backendErrorMessage(error));
    }
  }

  bool _statusRequiresLocation(String status) =>
      deliveryStatusRequiresLocation(status);

  Future<void> _tryPostTracking(
    String assignmentId,
    Position position,
    String actionTakenAt,
  ) async {
    try {
      await _statusRepository.postTracking(
        assignmentId: assignmentId,
        latitude: position.latitude,
        longitude: position.longitude,
        actionTakenAt: actionTakenAt,
      );
      if (kDebugMode) {
        debugPrint(
          'Deliverex tracking update sent for assignment $assignmentId',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Deliverex tracking/GPS update skipped after status update: $error',
        );
      }
    }
  }

  String _backendErrorMessage(DioException error) {
    return messageFromDioException(
      error,
      fallback: 'Unable to update delivery status.',
      serverErrorMessage:
          'The server could not update the delivery status. Please try again or contact your administrator.',
    );
  }

  Future<Position> _capturePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (kDebugMode) {
      debugPrint('Deliverex location service enabled: $serviceEnabled');
    }
    if (!serviceEnabled) {
      throw const _LocationStatusException(
        'Please enable location services to confirm arrival.',
        'Location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (kDebugMode) {
      debugPrint('Deliverex location permission before request: $permission');
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (kDebugMode) {
      debugPrint('Deliverex location permission after request: $permission');
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationStatusException(
        'Location permission is required to confirm arrival.',
        'Location permission denied.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationStatusException(
        'Location permission is required to confirm arrival.',
        'Location permission denied forever.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (kDebugMode) {
        debugPrint('Deliverex current GPS latitude: ${position.latitude}');
        debugPrint('Deliverex current GPS longitude: ${position.longitude}');
      }
      return position;
    } catch (error) {
      throw _LocationStatusException(
        'Unable to get current GPS location. Please try again.',
        error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          _HeaderNotificationBadge(
            count: _unreadCount,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: AppColors.background,
                    appBar: AppBar(
                      title: const Text('Notifications'),
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.text,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                    ),
                    body: const NotificationsScreen(),
                  ),
                ),
              );
              _loadUnreadCount();
            },
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: Column(
        children: [
          ConnectivityBanner(
            isOnline: _isOnline,
            isSyncing: _isSyncing,
            pendingCount: _pendingCount,
            hasError: _hasError,
            errorMessage: _syncError.isNotEmpty ? _syncError : null,
            onSyncTap: () => _syncService.processQueue(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<DriverAssignment>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 14),
                        DriverEmptyState(
                          title: 'Loading delivery',
                          message:
                              'Fetching assignment details from Deliverex.',
                          icon: Icons.sync_rounded,
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        DriverEmptyState(
                          title: 'Unable to load delivery',
                          message:
                              snapshot.error?.toString() ??
                              'No assignment found.',
                          icon: Icons.cloud_off_outlined,
                        ),
                      ],
                    );
                  }

                  final assignment = snapshot.data!;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      assignment.isActive || assignment.isPending
                          ? (MediaQuery.paddingOf(context).bottom + 140)
                          : 24,
                    ),
                    children: [
                      if (_pendingCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DriverCard(
                            child: Row(
                              children: [
                                Icon(
                                  _hasError
                                      ? Icons.warning_amber_rounded
                                      : Icons.sync_rounded,
                                  color: _hasError
                                      ? AppColors.danger
                                      : AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _hasError
                                        ? 'Sync failed. Tap banner to retry.'
                                        : '$_pendingCount update${_pendingCount == 1 ? '' : 's'} pending sync',
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _StatusTrackerCard(assignment: assignment),
                      const SizedBox(height: 14),
                      _ClientCard(assignment: assignment),
                      const SizedBox(height: 14),
                      _RouteCard(assignment: assignment),
                      const SizedBox(height: 14),
                      _NavigationCard(assignment: assignment),
                      const SizedBox(height: 14),
                      _LoadDetailsCard(assignment: assignment),
                      const SizedBox(height: 14),
                      _VehicleCard(assignment: assignment),
                      const SizedBox(height: 14),
                      DriverCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.receipt_long_outlined,
                              label: 'DELIVERY NOTES',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              assignment.notes.ifBlank('No delivery notes.'),
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (assignment.statusLogs.isNotEmpty) ...[
                        _StatusHistoryCard(logs: assignment.statusLogs),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        DriverCard(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color:
                                  _message!.contains('success') ||
                                      _message!.contains('sent')
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<DriverAssignment>(
        future: _future,
        builder: (context, snapshot) {
          final assignment = snapshot.data;
          if (assignment == null ||
              (!assignment.isActive && !assignment.isPending)) {
            return const SizedBox.shrink();
          }
          return _StickyJobActions(
            submitting: _submitting,
            primaryLabel: assignment.allowedAction,
            onPrimary: assignment.nextStatus == null
                ? null
                : () => _handlePrimaryAction(assignment),
            onUpload: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: AppBar(
                    title: const Text('Upload'),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.text,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                  ),
                  body: DocumentUploadScreen(
                    initialAssignmentId: assignment.id,
                  ),
                ),
              ),
            ),
            onIssue: () => _showIssueSheet(assignment),
            onDelay: () => _showDelaySheet(assignment),
          );
        },
      ),
    );
  }

  Future<void> _showIssueSheet(DriverAssignment assignment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IssueSheet(
        onSubmit:
            ({
              required issueType,
              required notes,
              required fileName,
              required bytes,
            }) async {
              if (!_connectivity.isOnline) {
                final payload = <String, dynamic>{
                  'assignment_id': assignment.id,
                  'issue_type': issueType,
                  'action_taken_at': DateTime.now().toIso8601String(),
                };
                if (notes.trim().isNotEmpty) payload['notes'] = notes.trim();
                await _actionStore.addPendingAction(
                  actionType: 'issue',
                  payload: payload,
                  fileBytes: bytes,
                  fileName: fileName,
                  assignmentId: assignment.id,
                );
                if (mounted) {
                  setState(
                    () => _message = 'Issue saved offline for later sync.',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Issue saved offline for later sync.'),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.warning,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                return;
              }
              try {
                await _driverService.reportIssue(
                  assignmentId: assignment.id,
                  issueType: issueType,
                  notes: notes,
                  fileName: fileName,
                  bytes: bytes,
                );
                if (mounted) {
                  setState(() => _message = 'Issue report submitted.');
                }
              } on DioException catch (e) {
                if (isNetworkTransportError(e)) {
                  final payload = <String, dynamic>{
                    'assignment_id': assignment.id,
                    'issue_type': issueType,
                    'action_taken_at': DateTime.now().toIso8601String(),
                  };
                  if (notes.trim().isNotEmpty) payload['notes'] = notes.trim();
                  await _actionStore.addPendingAction(
                    actionType: 'issue',
                    payload: payload,
                    fileBytes: bytes,
                    fileName: fileName,
                    assignmentId: assignment.id,
                  );
                  if (mounted) {
                    setState(
                      () => _message = 'Issue saved offline for later sync.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Issue saved offline for later sync.',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.warning,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  rethrow;
                }
              }
            },
      ),
    );
  }

  Future<void> _showDelaySheet(DriverAssignment assignment) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DelaySheet(
        onSubmit: ({required reason, required notes}) async {
          final result = await _statusRepository.reportDelay(
            assignmentId: assignment.id,
            delayReason: reason,
            notes: notes,
          );
          if (mounted) {
            setState(
              () => _message = result.synced
                  ? 'Delay report submitted.'
                  : 'Delay report saved offline.',
            );
            if (!result.synced) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Delay saved offline for later sync.'),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.warning,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _CompletionProofRequest {
  const _CompletionProofRequest({
    required this.proofType,
    required this.proofTypeLabel,
    required this.documentType,
    required this.proofFileName,
    required this.proofBytes,
    required this.receiverName,
    required this.receiverContact,
    required this.deliveryNotes,
    required this.signatureFileName,
    required this.signatureBytes,
  });

  final String proofType;
  final String proofTypeLabel;
  final String documentType;
  final String proofFileName;
  final List<int> proofBytes;
  final String receiverName;
  final String receiverContact;
  final String deliveryNotes;
  final String? signatureFileName;
  final List<int>? signatureBytes;
}

class _CompletionProofException implements Exception {
  const _CompletionProofException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef _CompleteDeliverySubmit =
    Future<void> Function(_CompletionProofRequest request);

class _CompleteDeliverySheet extends StatefulWidget {
  const _CompleteDeliverySheet({
    required this.assignment,
    required this.onSubmit,
  });

  final DriverAssignment assignment;
  final _CompleteDeliverySubmit onSubmit;

  @override
  State<_CompleteDeliverySheet> createState() => _CompleteDeliverySheetState();
}

class _CompleteDeliverySheetState extends State<_CompleteDeliverySheet> {
  final _receiverNameController = TextEditingController();
  final _receiverContactController = TextEditingController();
  final _notesController = TextEditingController();
  var _proofType = 'receipt_photo';
  var _documentType = 'receipt';
  PlatformFile? _proofFile;
  PlatformFile? _signatureFile;
  var _submitting = false;
  String? _error;

  static const _maxProofBytes = 10 * 1024 * 1024;
  static const _maxSignatureBytes = 5 * 1024 * 1024;

  static const _proofTypes = [
    ('receipt_photo', 'Receipt Photo'),
    ('ocr_document', 'OCR Document'),
  ];

  static const _documentTypes = [
    ('receipt', 'Receipt'),
    ('pod', 'POD'),
    ('signed_doc', 'Signed Doc'),
    ('invoice', 'Invoice'),
  ];

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverContactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (result == null) {
      return;
    }
    final file = result.files.single;
    if (file.bytes != null && file.bytes!.length > _maxProofBytes) {
      setState(
        () => _error =
            'Proof file is too large. Please upload an image under 10 MB.',
      );
      return;
    }
    setState(() {
      _proofFile = file;
      _error = null;
    });
    if (kDebugMode) {
      debugPrint('Deliverex complete proof file selected: ${_proofFile?.name}');
    }
  }

  Future<void> _pickSignature() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (result == null) {
      return;
    }
    final file = result.files.single;
    if (file.bytes != null && file.bytes!.length > _maxSignatureBytes) {
      setState(
        () => _error =
            'Signature file is too large. Please upload an image under 5 MB.',
      );
      return;
    }
    setState(() {
      _signatureFile = file;
      _error = null;
    });
    if (kDebugMode) {
      debugPrint(
        'Deliverex receiver signature captured: ${_signatureFile?.name}',
      );
    }
  }

  Future<void> _submit() async {
    final proof = _proofFile;
    final proofBytes = proof?.bytes;
    if (proof == null || proofBytes == null) {
      setState(() => _error = 'Upload delivery proof before completing.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload delivery proof before completing.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (proofBytes.length > _maxProofBytes) {
      setState(
        () => _error =
            'Proof file is too large. Please upload an image under 10 MB.',
      );
      return;
    }
    final signatureBytes = _signatureFile?.bytes;
    if (signatureBytes != null && signatureBytes.length > _maxSignatureBytes) {
      setState(
        () => _error =
            'Signature file is too large. Please upload an image under 5 MB.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final proofTypeLabel = _proofTypes
          .firstWhere((item) => item.$1 == _proofType)
          .$2;
      await widget.onSubmit(
        _CompletionProofRequest(
          proofType: _proofType,
          proofTypeLabel: proofTypeLabel,
          documentType: _documentType,
          proofFileName: proof.name,
          proofBytes: proofBytes,
          receiverName: _receiverNameController.text,
          receiverContact: _receiverContactController.text,
          deliveryNotes: _notesController.text,
          signatureFileName: _signatureFile?.name,
          signatureBytes: signatureBytes,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Deliverex complete delivery submit error: $error');
      }
      if (mounted) {
        setState(() => _error = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProof = _proofFile?.bytes != null;
    return _DriverBottomSheet(
      title: 'Complete delivery?',
      subtitle:
          'Upload delivery proof (receipt photo or OCR document) before completing. Receiver details are optional.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final type in _proofTypes)
              ChoiceChip(
                label: Text(type.$2),
                selected: _proofType == type.$1,
                onSelected: _submitting
                    ? null
                    : (_) {
                        setState(() {
                          _proofType = type.$1;
                          _proofFile = null;
                          _error = null;
                        });
                        if (kDebugMode) {
                          debugPrint(
                            'Deliverex selected completion proof type: ${type.$1}',
                          );
                        }
                      },
                selectedColor: AppColors.primary.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: _proofType == type.$1
                      ? AppColors.primary
                      : AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: _proofType == type.$1
                      ? AppColors.primary
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        if (_proofType == 'ocr_document') ...[
          const _SheetLabel('OCR document type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _documentTypes)
                ChoiceChip(
                  label: Text(type.$2),
                  selected: _documentType == type.$1,
                  onSelected: _submitting
                      ? null
                      : (_) {
                          setState(() => _documentType = type.$1);
                          if (kDebugMode) {
                            debugPrint(
                              'Deliverex selected OCR document_type: ${type.$1}',
                            );
                          }
                        },
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _documentType == type.$1
                        ? AppColors.primary
                        : AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: _documentType == type.$1
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickProof,
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(hasProof ? _proofFile!.name : 'Capture / upload proof'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.text,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (hasProof) ...[
          const SizedBox(height: 8),
          const Text(
            'Proof attached',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 18),
        const _SheetLabel('Receiver name (optional)'),
        TextField(
          controller: _receiverNameController,
          enabled: !_submitting,
          decoration: const InputDecoration(
            hintText: 'Who received the delivery?',
          ),
        ),
        const SizedBox(height: 16),
        const _SheetLabel('Receiver contact (optional)'),
        TextField(
          controller: _receiverContactController,
          enabled: !_submitting,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Mobile number'),
        ),
        const SizedBox(height: 16),
        const _SheetLabel('Delivery notes (optional)'),
        TextField(
          controller: _notesController,
          enabled: !_submitting,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Any remarks about the delivery...',
          ),
        ),
        const SizedBox(height: 22),
        const _SheetLabel('Receiver signature (optional)'),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickSignature,
          icon: const Icon(Icons.camera_alt_outlined, size: 16),
          label: Text(_signatureFile?.name ?? 'Capture signature'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: AppColors.mutedText,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        DriverPrimaryButton(
          label: 'Submit Proof & Complete',
          loading: _submitting,
          onPressed: hasProof ? _submit : null,
        ),
        const SizedBox(height: 10),
        _CancelSheetButton(disabled: _submitting),
      ],
    );
  }
}

class _LocationStatusException implements Exception {
  const _LocationStatusException(this.message, this.debugMessage);

  final String message;
  final String debugMessage;
}

class _HeaderNotificationBadge extends StatelessWidget {
  const _HeaderNotificationBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 28),
          if (count > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTrackerCard extends StatelessWidget {
  const _StatusTrackerCard({required this.assignment});

  final DriverAssignment assignment;

  static const _steps = [
    ('assigned', 'Assigned', Icons.check_rounded),
    ('en_route_to_pickup', 'En Route to Pickup', Icons.near_me_rounded),
    ('arrived_at_pickup', 'Arrived at Pickup', Icons.warehouse_rounded),
    ('en_route_to_destination', 'En Route to Destination', Icons.route_rounded),
    ('arrived', 'Arrived', Icons.location_on_rounded),
    ('completed', 'Completed', Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _statusIndex(assignment.status);
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                assignment.publicId,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              DriverStatusChip(label: assignment.status),
            ],
          ),
          if (assignment.lastUpdated != null) ...[
            const SizedBox(height: 14),
            Text(
              'Last updated ${assignment.lastUpdated}',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  SizedBox(
                    width: 108,
                    child: _TimelineStep(
                      label: _steps[i].$2,
                      sublabel: i == currentIndex ? _steps[i].$2 : null,
                      icon: _steps[i].$3,
                      active: i == currentIndex,
                      complete: i < currentIndex,
                    ),
                  ),
                  if (i < _steps.length - 1)
                    SizedBox(
                      width: 20,
                      child: Container(
                        margin: const EdgeInsets.only(top: 17),
                        height: 2,
                        color: i < currentIndex
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : AppColors.border,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _statusIndex(String status) {
    return deliveryStatusIndex(status);
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.active,
    required this.complete,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final IconData icon;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : complete
        ? AppColors.success
        : AppColors.mutedText;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : complete
                ? AppColors.success.withValues(alpha: 0.16)
                : AppColors.surfaceSoft,
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : complete
                  ? AppColors.success
                  : AppColors.border,
              width: 2,
            ),
          ),
          child: Icon(icon, color: active ? Colors.white : color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (sublabel != null)
          Text(
            sublabel!,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.person_outline, label: 'CLIENT'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.clientEmail,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.place_outlined, label: 'ROUTE'),
          const SizedBox(height: 12),
          _KvRow(label: 'Pickup', value: assignment.pickupAddress),
          _KvRow(label: 'Drop-off', value: assignment.dropoffAddress),
          _KvRow(label: 'Schedule', value: assignment.schedule),
          _KvRow(label: 'Tracking', value: assignment.trackingCode),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.navigation_outlined,
            label: 'NAVIGATION',
          ),
          const SizedBox(height: 10),
          Text(
            assignment.dropoffAddress,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openMaps(assignment),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Google Maps'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openWaze(assignment),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Waze'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xff35c6ea),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(DriverAssignment assignment) async {
    final lat = assignment.dropoffLatitude;
    final lng = assignment.dropoffLongitude;
    final destination = lat != null && lng != null
        ? '$lat,$lng'
        : Uri.encodeComponent(assignment.dropoffAddress);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWaze(DriverAssignment assignment) async {
    final lat = assignment.dropoffLatitude;
    final lng = assignment.dropoffLongitude;
    final query = lat != null && lng != null
        ? 'll=$lat,$lng'
        : 'q=${Uri.encodeComponent(assignment.dropoffAddress)}';
    final uri = Uri.parse('https://waze.com/ul?$query&navigate=yes');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LoadDetailsCard extends StatelessWidget {
  const _LoadDetailsCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.inventory_2_outlined,
            label: 'LOAD DETAILS',
          ),
          const SizedBox(height: 12),
          _KvRow(label: 'Material Type', value: assignment.materialType),
          _KvRow(
            label: 'Material Specification',
            value: assignment.materialSpecification,
          ),
          _KvRow(label: 'Load Volume', value: assignment.loadVolume),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.assignment});

  final DriverAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.directions_car_filled_outlined,
            label: 'VEHICLE',
          ),
          const SizedBox(height: 12),
          _KvRow(
            label: 'Plate',
            value: '${assignment.vehicle['plate_no'] ?? '—'}',
          ),
          _KvRow(label: 'Type', value: '${assignment.vehicle['type'] ?? '—'}'),
        ],
      ),
    );
  }
}

class _StatusHistoryCard extends StatelessWidget {
  const _StatusHistoryCard({required this.logs});

  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS HISTORY',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ...() {
            final sortedLogs = List<Map<String, dynamic>>.from(logs);
            sortedLogs.sort((a, b) {
              final aDate = (a['created_at'] ?? a['timestamp'] ?? '') as String;
              final bDate = (b['created_at'] ?? b['timestamp'] ?? '') as String;
              return bDate.compareTo(aDate);
            });
            return sortedLogs.map(
              (log) => _HistoryRow(
                rawDate: log['created_at'] ?? log['timestamp'],
                status: '${log['status'] ?? ''}',
              ),
            );
          }(),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.rawDate, required this.status});

  final dynamic rawDate;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDeliverexDateTime(rawDate),
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          DriverStatusChip(label: status),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mutedText, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyJobActions extends StatelessWidget {
  const _StickyJobActions({
    required this.submitting,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onUpload,
    required this.onIssue,
    required this.onDelay,
  });

  final bool submitting;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onUpload;
  final VoidCallback onIssue;
  final VoidCallback onDelay;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottom + 12),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DriverPrimaryButton(
              label: primaryLabel,
              loading: submitting,
              onPressed: onPrimary,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.upload_file_outlined,
                    label: 'Upload',
                    onTap: onUpload,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'Report Issue',
                    onTap: onIssue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.schedule_outlined,
              label: 'Report Delay',
              onTap: onDelay,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

typedef IssueSubmit =
    Future<void> Function({
      required String issueType,
      required String notes,
      required String? fileName,
      required List<int>? bytes,
    });

class _IssueSheet extends StatefulWidget {
  const _IssueSheet({required this.onSubmit});

  final IssueSubmit onSubmit;

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  final _notesController = TextEditingController();
  final _types = const [
    ('vehicle_breakdown', 'Vehicle Breakdown'),
    ('flat_tire', 'Flat Tire'),
    ('accident', 'Accident'),
    ('wrong_material', 'Wrong Material'),
    ('site_inaccessible', 'Site Inaccessible'),
    ('safety_issue', 'Safety Issue'),
    ('other', 'Other'),
  ];
  String? _selected;
  PlatformFile? _photo;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    setState(() => _photo = result?.files.single);
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'Select an issue type.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        issueType: _selected!,
        notes: _notesController.text,
        fileName: _photo?.name,
        bytes: _photo?.bytes,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DriverBottomSheet(
      title: 'Report Issue',
      subtitle:
          'Select the issue category, add notes, and optionally attach a photo.',
      children: [
        for (final type in _types)
          _SheetOption(
            label: type.$2,
            selected: _selected == type.$1,
            onTap: () => setState(() => _selected = type.$1),
          ),
        const SizedBox(height: 12),
        const _SheetLabel('Notes (optional)'),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Describe the issue...'),
        ),
        const SizedBox(height: 14),
        const _SheetLabel('Photo (optional)'),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(_photo?.name ?? 'Add photo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            backgroundColor: AppColors.surfaceSoft,
            side: BorderSide.none,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        DriverPrimaryButton(
          label: 'Submit Issue Report',
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        _CancelSheetButton(disabled: _submitting),
      ],
    );
  }
}

typedef DelaySubmit =
    Future<void> Function({required String reason, required String notes});

class _DelaySheet extends StatefulWidget {
  const _DelaySheet({required this.onSubmit});

  final DelaySubmit onSubmit;

  @override
  State<_DelaySheet> createState() => _DelaySheetState();
}

class _DelaySheetState extends State<_DelaySheet> {
  final _notesController = TextEditingController();
  final _reasons = const [
    ('traffic_congestion', 'Traffic Congestion'),
    ('vehicle_breakdown', 'Vehicle Breakdown'),
    ('loading_delay', 'Loading Delay'),
    ('client_site_not_ready', 'Client Site Not Ready'),
    ('weather_condition', 'Weather Condition'),
    ('road_closure', 'Road Closure'),
    ('accident', 'Accident'),
    ('other', 'Other'),
  ];
  String? _selected;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'Select a delay reason.');
      return;
    }
    if (_selected == 'other' && _notesController.text.trim().isEmpty) {
      setState(() => _error = 'Notes are required when selecting Other.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(reason: _selected!, notes: _notesController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DriverBottomSheet(
      title: 'Report Delay',
      subtitle:
          'Select the reason for the delivery delay. Notes are required if you choose Other.',
      children: [
        for (final reason in _reasons)
          _SheetOption(
            label: reason.$2,
            selected: _selected == reason.$1,
            onTap: () => setState(() => _selected = reason.$1),
          ),
        const SizedBox(height: 12),
        const _SheetLabel('Additional notes (optional)'),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Describe the delay...'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        DriverPrimaryButton(
          label: 'Submit Delay Report',
          loading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        _CancelSheetButton(disabled: _submitting),
      ],
    );
  }
}

class _DriverBottomSheet extends StatelessWidget {
  const _DriverBottomSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.94,
      minChildSize: 0.45,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              MediaQuery.paddingOf(context).bottom + 18,
            ),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: AppColors.text,
          backgroundColor: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CancelSheetButton extends StatelessWidget {
  const _CancelSheetButton({required this.disabled});

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: disabled ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.surfaceSoft,
          foregroundColor: AppColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
