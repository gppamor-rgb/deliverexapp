import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/driver_assignment.dart';
import 'driver_card.dart';
import 'driver_status_chip.dart';

class DriverJobCard extends StatelessWidget {
  const DriverJobCard({super.key, required this.job, this.onTap});

  final DriverAssignment job;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    job.publicId,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  DriverStatusChip(label: job.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              _JobMeta(icon: Icons.place_outlined, text: job.dropoffAddress),
              const SizedBox(height: 8),
              _JobMeta(icon: Icons.event_outlined, text: job.schedule),
              const SizedBox(height: 8),
              _JobMeta(
                icon: Icons.directions_car_outlined,
                text: job.vehicleLabel,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobMeta extends StatelessWidget {
  const _JobMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
