import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import '../core/app_colors.dart';
import '../database/action_store.dart';
import '../models/driver_user.dart';
import '../services/background_sync.dart';
import '../services/connectivity_service.dart';
import '../services/driver_service.dart';
import '../services/sync_service.dart';
import '../widgets/driver/connectivity_banner.dart';
import '../widgets/driver/driver_app_header.dart';
import '../widgets/driver/driver_bottom_nav.dart';
import 'document_upload_screen.dart';
import 'driver_home_screen.dart';
import 'driver_jobs_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class DriverShellScreen extends StatefulWidget {
  const DriverShellScreen({super.key, required this.user});

  final DriverUser user;

  @override
  State<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends State<DriverShellScreen> {
  final _driverService = DriverService();
  final _connectivity = ConnectivityService.instance;
  final _syncService = SyncService.instance;
  final _actionStore = ActionStore();
  var _index = 0;
  var _unreadCount = 0;
  var _isOnline = true;
  var _isSyncing = false;
  var _pendingCount = 0;
  var _hasError = false;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<SyncStatus>? _syncSub;

  late final _screens = [
    DriverHomeScreen(user: widget.user),
    const DriverJobsScreen(),
    const DocumentUploadScreen(),
    NotificationsScreen(onUnreadCountChanged: (count) {
      if (mounted) setState(() => _unreadCount = count);
    }),
    ProfileScreen(user: widget.user),
  ];

  static const _titles = [
    'Driver Home',
    'Jobs',
    'Upload Documents',
    'Notifications',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _connectivity.initialize();
    _isOnline = _connectivity.isOnline;
    _loadUnreadCount();
    _loadPendingCount();
    _connectivitySub = _connectivity.connectivityStream.listen(_onConnectivityChanged);
    _syncSub = _syncService.syncStream.listen(_onSyncStatusChanged);
    _registerBackgroundSync();
    _syncOnStart();
  }

  Future<void> _syncOnStart() async {
    await _loadPendingCount();
    if (_isOnline && _pendingCount > 0) {
      _syncService.processQueue();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    Workmanager().cancelAll();
    super.dispose();
  }

  Future<void> _registerBackgroundSync() async {
    await Workmanager().registerPeriodicTask(
      'deliverex_sync',
      backgroundSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    setState(() => _isOnline = online);
    _loadPendingCount();
    if (online) {
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
    } else if (status is SyncCompleted) {
      setState(() {
        _isSyncing = false;
        _hasError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('All updates synced successfully.'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (status is SyncError) {
      _loadPendingCount();
      setState(() {
        _isSyncing = false;
        _hasError = true;
      });
    } else if (status is SyncIdle) {
      setState(() {
        _isSyncing = false;
        _hasError = false;
      });
    }
  }

  Future<void> _loadPendingCount() async {
    final count = await _actionStore.getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _loadUnreadCount({bool silent = false}) async {
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
      if (mounted && !silent) {
        setState(() => _unreadCount = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ConnectivityBanner(
            isOnline: _isOnline,
            isSyncing: _isSyncing,
            pendingCount: _pendingCount,
            hasError: _hasError,
            onSyncTap: () => _syncService.processQueue(),
          ),
          DriverAppHeader(
            title: _titles[_index],
            unreadCount: _unreadCount,
            onNotificationsTap: () => setState(() => _index = 3),
            isOnline: _isOnline,
          ),
          Expanded(child: _screens[_index]),
        ],
      ),
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
