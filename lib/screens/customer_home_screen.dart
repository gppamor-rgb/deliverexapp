import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/delivery_status.dart';
import '../models/customer_portal_order.dart';
import '../models/driver_user.dart';
import '../services/customer_portal_service.dart';
import '../widgets/driver/driver_card.dart';
import 'customer_delivery_details_sheet.dart';
import 'tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    required this.user,
    this.portalService,
    this.onLinkDelivery,
    this.onTrack,
    this.onViewDeliveries,
  });

  final DriverUser user;
  final CustomerPortalService? portalService;
  final VoidCallback? onLinkDelivery;
  final VoidCallback? onTrack;
  final VoidCallback? onViewDeliveries;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late final CustomerPortalService _portalService;
  late Future<List<CustomerPortalOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _portalService = widget.portalService ?? CustomerPortalService();
    _ordersFuture = _portalService.fetchOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = _portalService.fetchOrders();
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<CustomerPortalOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          final orders = snapshot.data ?? const <CustomerPortalOrder>[];
          final active = orders.where((order) => order.isActive).toList();
          final completed = orders.where((order) => order.isCompleted).toList();
          final inTransit = active.where((order) {
            final status = canonicalDeliveryStatus(order.status);
            return status == deliveryStatusEnRouteToPickup ||
                status == deliveryStatusArrivedAtPickup ||
                status == deliveryStatusEnRouteToDestination ||
                status == deliveryStatusArrived;
          }).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome, ${widget.user.name.split(' ').first}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage linked deliveries and track current progress.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 15),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.link_rounded,
                      label: 'Link Delivery',
                      onTap: widget.onLinkDelivery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.pin_drop_outlined,
                      label: 'Track by ID',
                      onTap: widget.onTrack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const _LoadingCard()
              else if (snapshot.hasError)
                _ErrorCard(onRetry: _refresh)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: active.length,
                        label: 'ACTIVE',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        value: inTransit,
                        label: 'IN TRANSIT',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: completed.length,
                        label: 'COMPLETED',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        value: orders.length,
                        label: 'LINKED',
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'ACTIVE DELIVERIES',
                  actionLabel: active.isEmpty ? null : 'View all',
                  onAction: widget.onViewDeliveries,
                ),
                const SizedBox(height: 12),
                if (active.isEmpty)
                  _EmptyDashboardCard(
                    onLinkDelivery: widget.onLinkDelivery,
                    onTrack: widget.onTrack,
                  )
                else
                  ...active
                      .take(3)
                      .map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CustomerOrderCard(order: order),
                        ),
                      ),
                const SizedBox(height: 14),
                _SectionHeader(
                  title: 'RECENT DELIVERIES',
                  actionLabel: completed.isEmpty ? null : 'History',
                  onAction: widget.onViewDeliveries,
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty)
                  const DriverCard(
                    child: Text(
                      'Completed linked deliveries will appear here.',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  )
                else
                  ...completed
                      .take(2)
                      .map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CustomerOrderCard(order: order),
                        ),
                      ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({
    super.key,
    required this.order,
    this.onTrackShipment,
  });

  final CustomerPortalOrder order;
  final ValueChanged<CustomerPortalOrder>? onTrackShipment;

  Future<void> _showDetails(BuildContext context) async {
    final shouldTrack = await showCustomerDeliveryDetailsSheet(
      context,
      order: order,
    );
    if (shouldTrack != true || !context.mounted) {
      return;
    }

    final callback = onTrackShipment;
    if (callback != null) {
      callback(order);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(prefillTracking: order.trackingCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.trackingCode.isEmpty
                      ? 'Linked delivery'
                      : order.trackingCode,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.statusLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.trip_origin_rounded,
            label: 'Pickup',
            value: order.pickupAddress,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.flag_rounded,
            label: 'Drop-off',
            value: order.dropoffAddress,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.event_rounded,
            label: 'Schedule',
            value: order.schedule,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showDetails(context),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard({this.onLinkDelivery, this.onTrack});

  final VoidCallback? onLinkDelivery;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 46,
            color: AppColors.mutedText.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 10),
          const Text(
            'No linked deliveries yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Link a delivery with its Tracking ID or track one without saving it to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onLinkDelivery,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Link Delivery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTrack,
                  icon: const Icon(Icons.pin_drop_outlined),
                  label: const Text('Track by ID'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const DriverCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          const SizedBox(height: 8),
          const Text(
            'Unable to load linked deliveries.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
