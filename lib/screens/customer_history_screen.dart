import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/customer_portal_order.dart';
import '../services/customer_portal_service.dart';
import '../widgets/driver/driver_card.dart';
import 'customer_home_screen.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key, this.portalService});

  final CustomerPortalService? portalService;

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const DriverCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (snapshot.hasError)
                DriverCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to load delivery history.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (orders.isEmpty)
                const DriverCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AppColors.mutedText,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No delivery history yet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Linked deliveries will be grouped here by current and completed status.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                )
              else ...[
                _HistorySection(title: 'Active', orders: active),
                const SizedBox(height: 18),
                _HistorySection(title: 'Completed', orders: completed),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.title, required this.orders});

  final String title;
  final List<CustomerPortalOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${orders.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          DriverCard(
            child: Text(
              title == 'Active'
                  ? 'No active linked deliveries.'
                  : 'No completed linked deliveries.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
          )
        else
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CustomerOrderCard(order: order),
            ),
      ],
    );
  }
}
