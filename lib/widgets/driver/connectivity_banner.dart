import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    this.isSyncing = false,
    this.hasError = false,
    this.errorMessage,
    this.onSyncTap,
  });

  final bool isOnline;
  final int pendingCount;
  final bool isSyncing;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onSyncTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 6, 20, 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: _backgroundColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _statusIcon,
              const SizedBox(width: 8),
              Expanded(child: _label),
              if (_showPendingBadge) _PendingBadge(count: pendingCount),
              if (_showSyncButton)
                GestureDetector(
                  onTap: onSyncTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSyncing ? 'SYNCING...' : 'SYNC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (hasError && errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isSyncing) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget get _statusIcon {
    final iconData = !isOnline
        ? Icons.cloud_off_rounded
        : hasError
            ? Icons.warning_amber_rounded
            : isSyncing
                ? Icons.sync_rounded
                : Icons.cloud_done_rounded;

    return Icon(iconData, color: Colors.white, size: 20);
  }

  Widget get _label {
    String text;

    if (!isOnline) {
      text = 'Offline';
    } else if (isSyncing) {
      text = 'Syncing updates...';
    } else if (hasError) {
      text = 'Sync failed — tap to retry';
    } else {
      text = 'Connected';
    }

    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  Color get _backgroundColor {
    if (!isOnline) return AppColors.warning;
    if (hasError) return AppColors.danger;
    if (isSyncing) return AppColors.primary;
    if (pendingCount > 0) return AppColors.primary.withValues(alpha: 0.85);
    return AppColors.success.withValues(alpha: 0.85);
  }

  bool get _showPendingBadge {
    if (isSyncing) return false;
    return pendingCount > 0;
  }

  bool get _showSyncButton {
    if (isSyncing) return false;
    if (_showPendingBadge && !hasError) return false;
    return (pendingCount > 0 || hasError) && isOnline;
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count pending',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
