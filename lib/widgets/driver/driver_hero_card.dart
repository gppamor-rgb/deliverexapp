import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'driver_summary_pill.dart';

class DriverHeroCard extends StatelessWidget {
  const DriverHeroCard({
    super.key,
    required this.driverName,
    required this.today,
    required this.pending,
    required this.completed,
  });

  final String driverName;
  final int today;
  final int pending;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $driverName',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pending > 0
                ? 'You have $pending active deliver${pending == 1 ? 'y' : 'ies'} today.'
                : 'No active deliveries right now.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              DriverSummaryPill(
                value: '$today',
                label: 'Today',
                icon: Icons.local_shipping_outlined,
              ),
              SizedBox(width: 10),
              DriverSummaryPill(
                value: '$pending',
                label: 'Pending',
                icon: Icons.schedule_outlined,
              ),
              SizedBox(width: 10),
              DriverSummaryPill(
                value: '$completed',
                label: 'Done',
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
