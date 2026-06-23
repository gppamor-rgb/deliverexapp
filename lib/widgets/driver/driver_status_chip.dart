import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/driver_assignment.dart';

class DriverStatusChip extends StatelessWidget {
  const DriverStatusChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _colorFor(label);
    final displayLabel = driverStatusLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _colorFor(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('complete') || normalized.contains('done')) {
      return AppColors.success;
    }
    if (normalized.contains('pending') || normalized.contains('pickup')) {
      return AppColors.warning;
    }
    if (normalized.contains('cancel') || normalized.contains('failed')) {
      return AppColors.danger;
    }
    return AppColors.primary;
  }
}
