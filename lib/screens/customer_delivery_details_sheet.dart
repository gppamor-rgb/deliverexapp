import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/delivery_status.dart';
import '../models/customer_portal_order.dart';

Future<bool?> showCustomerDeliveryDetailsSheet(
  BuildContext context, {
  required CustomerPortalOrder order,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomerDeliveryDetailsSheet(order: order),
  );
}

class _CustomerDeliveryDetailsSheet extends StatelessWidget {
  const _CustomerDeliveryDetailsSheet({required this.order});

  final CustomerPortalOrder order;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.56,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DELIVERY DETAILS',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                order.trackingCode.isEmpty
                                    ? 'Linked delivery'
                                    : order.trackingCode,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(label: order.statusLabel),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle('DELIVERY PROGRESS'),
                    const SizedBox(height: 16),
                    _DeliveryProgress(status: order.status),
                    const SizedBox(height: 28),
                    const _SectionTitle('OVERVIEW', icon: Icons.receipt_long),
                    _DetailRow(label: 'Tracking ID', value: order.trackingCode),
                    _DetailRow(label: 'Status', value: order.statusLabel),
                    _DetailRow(label: 'Priority', value: order.priority),
                    _DetailRow(
                      label: 'Scheduled Start',
                      value: order.scheduledStart,
                    ),
                    _DetailRow(
                      label: 'Scheduled End',
                      value: order.scheduledEnd,
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('ROUTE', icon: Icons.location_on),
                    _DetailRow(label: 'Pickup', value: order.pickupAddress),
                    _DetailRow(label: 'Drop-off', value: order.dropoffAddress),
                    const SizedBox(height: 18),
                    const _SectionTitle('PROOF OF DELIVERY'),
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Proof of delivery will appear here once the shipment is completed.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  MediaQuery.paddingOf(context).bottom + 14,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: order.trackingCode.trim().isEmpty
                            ? null
                            : () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.pin_drop_outlined),
                        label: const Text('Track Shipment'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(88, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = deliveryStatusIndex(status);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < deliveryStatusLifecycle.length; i++) ...[
            _ProgressStep(
              number: i + 1,
              label: deliveryStatusLabel(deliveryStatusLifecycle[i]),
              completed: i <= currentIndex,
              active: i == currentIndex,
            ),
            if (i != deliveryStatusLifecycle.length - 1)
              Container(
                width: 34,
                height: 3,
                margin: const EdgeInsets.only(top: 20),
                color: i < currentIndex
                    ? AppColors.primary.withValues(alpha: 0.72)
                    : AppColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.number,
    required this.label,
    required this.completed,
    required this.active,
  });

  final int number;
  final String label;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.primary : const Color(0xffdce4ef);
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Container(
            width: active ? 46 : 40,
            height: active ? 46 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: completed ? Colors.white : AppColors.mutedText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.mutedText,
              fontSize: 11,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}
