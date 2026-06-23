import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    this.isSyncing = false,
    this.onSyncTap,
  });

  final bool isOnline;
  final int pendingCount;
  final bool isSyncing;
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
        : isSyncing || pendingCount > 0
            ? Icons.sync_rounded
            : Icons.cloud_done_rounded;

    return Icon(iconData, color: Colors.white, size: 20);
  }

  Widget get _label {
    String text;

    if (!isOnline) {
      text = pendingCount > 0
          ? 'Offline · $pendingCount update${pendingCount == 1 ? '' : 's'} pending'
          : 'Offline · No internet connection';
    } else if (isSyncing) {
      text = 'Syncing updates...';
    } else if (pendingCount > 0) {
      text = '$pendingCount update${pendingCount == 1 ? '' : 's'} pending sync';
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
    if (isSyncing) return AppColors.primary;
    if (pendingCount > 0) return AppColors.primary.withValues(alpha: 0.85);
    return AppColors.success.withValues(alpha: 0.85);
  }

  bool get _showSyncButton {
    if (isSyncing) return false;
    return pendingCount > 0 && isOnline;
  }
}
