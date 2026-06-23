import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../database/database_helper.dart';
import '../models/driver_notification.dart';
import '../services/driver_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onUnreadCountChanged});

  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _driverService = DriverService();
  final _dbHelper = DatabaseHelper.instance;
  final _locallyReadIds = <String>{};
  var _notifications = <DriverNotification>[];
  var _loading = false;
  Object? _error;
  var _submitting = false;

  int get _computedUnreadCount => _notifications.where((n) {
    if (_locallyReadIds.contains(n.id)) return false;
    return !n.isRead;
  }).length;

  @override
  void initState() {
    super.initState();
    _loadLocallyReadIds();
    _fetch();
  }

  Future<void> _loadLocallyReadIds() async {
    final stored = await _dbHelper.getSetting('locally_read_notification_ids');
    if (stored == null || stored.isEmpty) return;
    final ids = jsonDecode(stored) as List<dynamic>;
    _locallyReadIds.addAll(ids.cast<String>());
  }

  Future<void> _saveLocallyReadIds() async {
    await _dbHelper.setSetting(
      'locally_read_notification_ids',
      jsonEncode(_locallyReadIds.toList()),
    );
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _driverService.fetchNotifications(page: 1);
      if (mounted) {
        setState(() {
          _notifications = page.notifications;
          _error = null;
        });
        _locallyReadIds.removeWhere((id) {
          final match = page.notifications.where((n) => n.id == id);
          return match.isNotEmpty && match.first.isRead;
        });
        await _saveLocallyReadIds();
        widget.onUnreadCountChanged?.call(_computedUnreadCount);
      }
    } on DioException catch (e) {
      if (_isConnectionError(e)) {
        if (mounted) {
          setState(() => _error = 'No internet connection. Pull down to refresh when connected.');
        }
      } else if (mounted && !silent) {
        setState(() => _error = e.toString());
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  Future<void> _markRead(DriverNotification notification) async {
    if (_submitting) return;

    _locallyReadIds.add(notification.id);
    await _saveLocallyReadIds();
    setState(() {});
    widget.onUnreadCountChanged?.call(_computedUnreadCount);

    try {
      if (kDebugMode) {
        debugPrint('Deliverex mark read notification id: ${notification.id}');
      }
      await _driverService.markNotificationRead(notification.id);
      await _fetch(silent: true);
    } on DioException catch (error) {
      if (!_isConnectionError(error)) {
        _locallyReadIds.remove(notification.id);
        await _saveLocallyReadIds();
        await _fetch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_backendErrorMessage(error)),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (error) {
      _locallyReadIds.remove(notification.id);
      await _saveLocallyReadIds();
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) {
      if (_locallyReadIds.contains(n.id)) return false;
      return !n.isRead;
    }).toList();
    if (unread.isEmpty) return;

    for (final notification in unread) {
      _locallyReadIds.add(notification.id);
    }
    await _saveLocallyReadIds();
    setState(() {});
    widget.onUnreadCountChanged?.call(_computedUnreadCount);

    setState(() => _submitting = true);

    try {
      final ids = unread.map((n) => n.id).toList();
      if (kDebugMode) {
        debugPrint('Deliverex marking ${ids.length} notifications as read');
      }
      await _driverService.markAllNotificationsRead(ids);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (error) {
      if (!_isConnectionError(error)) {
        for (final notification in unread) {
          _locallyReadIds.remove(notification.id);
        }
        await _saveLocallyReadIds();
        await _fetch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_backendErrorMessage(error)),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (error) {
      for (final notification in unread) {
        _locallyReadIds.remove(notification.id);
      }
      await _saveLocallyReadIds();
      await _fetch();
      if (mounted) {
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

  String _backendErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
    if (data != null && data.toString().trim().isNotEmpty) {
      return data.toString();
    }
    return error.message ?? 'Unable to update notification.';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _fetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          OutlinedButton.icon(
            onPressed: _submitting || _computedUnreadCount == 0
                ? null
                : _markAllRead,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text(
              'Mark all as read',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading && _notifications.isEmpty)
            const LinearProgressIndicator()
          else if (_error != null && _notifications.isEmpty)
            DriverEmptyState(
              title: 'Unable to load alerts',
              message: _error.toString(),
              icon: Icons.cloud_off_outlined,
            )
          else if (_notifications.isEmpty)
            const DriverEmptyState(
              title: 'No alerts',
              message: 'Driver alerts from the backend will appear here.',
              icon: Icons.notifications_none_rounded,
            )
          else
            for (final notification in _notifications)
              _NotificationCard(
                notification: notification,
                isLocallyRead: _locallyReadIds.contains(notification.id),
                onRead: () => _markRead(notification),
              ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isLocallyRead,
    required this.onRead,
  });

  final DriverNotification notification;
  final bool isLocallyRead;
  final VoidCallback onRead;

  bool get _isRead => notification.isRead || isLocallyRead;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isRead ? AppColors.border : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title.ifBlank('Notification'),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notification.createdAt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    notification.createdAt,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isRead ? null : onRead,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.surfaceSoft,
              foregroundColor: Colors.white,
              disabledForegroundColor: AppColors.mutedText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(_isRead ? 'Read' : 'Mark Read'),
          ),
        ],
      ),
    );
  }
}

extension _BlankString on String {
  String ifBlank(String fallback) => isEmpty ? fallback : this;
}
