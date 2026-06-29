import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/customer_portal_order.dart';
import '../models/driver_user.dart';
import '../services/customer_portal_service.dart';
import '../widgets/driver/driver_card.dart';
import 'customer_home_screen.dart';

class CustomerDeliveriesScreen extends StatefulWidget {
  const CustomerDeliveriesScreen({
    super.key,
    required this.user,
    this.portalService,
    this.onLinkDelivery,
    this.onTrack,
  });

  final DriverUser user;
  final CustomerPortalService? portalService;
  final VoidCallback? onLinkDelivery;
  final VoidCallback? onTrack;

  @override
  State<CustomerDeliveriesScreen> createState() =>
      _CustomerDeliveriesScreenState();
}

class _CustomerDeliveriesScreenState extends State<CustomerDeliveriesScreen> {
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
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const _LoadingCard()
              else if (snapshot.hasError)
                _ErrorCard(onRetry: _refresh)
              else if (orders.isEmpty)
                _EmptyDeliveriesCard(
                  onLinkDelivery: widget.onLinkDelivery,
                  onTrack: widget.onTrack,
                )
              else ...[
                const Text(
                  'All linked deliveries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Deliveries connected to your customer account.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 14),
                for (final order in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CustomerOrderCard(order: order),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyDeliveriesCard extends StatelessWidget {
  const _EmptyDeliveriesCard({this.onLinkDelivery, this.onTrack});

  final VoidCallback? onLinkDelivery;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: AppColors.mutedText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No linked deliveries',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use a Tracking ID to link a delivery to your customer account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
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
            'Unable to load deliveries.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
