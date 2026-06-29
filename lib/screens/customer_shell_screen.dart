import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/transitions.dart';
import '../models/driver_user.dart';
import '../widgets/chatbot_chathead.dart';
import '../widgets/customer/customer_bottom_nav.dart';
import 'customer_deliveries_screen.dart';
import 'customer_history_screen.dart';
import 'customer_home_screen.dart';
import 'customer_link_delivery_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_support_screen.dart';
import 'tracking_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key, required this.user});

  final DriverUser user;

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  var _index = 0;
  var _refreshKey = 0;

  static const _titles = [
    'Dashboard',
    'Track',
    'Deliveries',
    'History',
    'Support',
  ];

  void _goToTrack() {
    setState(() => _index = 1);
  }

  void _goToDeliveries() {
    setState(() => _index = 2);
  }

  Future<void> _openLinkDelivery() async {
    final linked = await Navigator.of(
      context,
    ).push<bool>(AppTransitions.slideUp(const CustomerLinkDeliveryScreen()));
    if (linked == true && mounted) {
      setState(() {
        _refreshKey++;
        _index = 2;
      });
    }
  }

  Future<void> _openProfile() async {
    final result = await Navigator.of(context).push<String>(
      AppTransitions.slideUp(CustomerProfileScreen(user: widget.user)),
    );
    if (result == 'link' && mounted) {
      await _openLinkDelivery();
    }
  }

  Widget _screenForIndex(int index) {
    return switch (index) {
      0 => CustomerHomeScreen(
        key: ValueKey('customer-dashboard-$_refreshKey'),
        user: widget.user,
        onLinkDelivery: _openLinkDelivery,
        onTrack: _goToTrack,
        onViewDeliveries: _goToDeliveries,
      ),
      1 => const TrackingScreen(showBackButton: false),
      2 => CustomerDeliveriesScreen(
        key: ValueKey('customer-deliveries-$_refreshKey'),
        user: widget.user,
        onLinkDelivery: _openLinkDelivery,
        onTrack: _goToTrack,
      ),
      3 => CustomerHistoryScreen(
        key: ValueKey('customer-history-$_refreshKey'),
      ),
      _ => CustomerSupportScreen(user: widget.user),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            if (_index != 1)
              _CustomerHeader(
                title: _titles[_index],
                user: widget.user,
                onProfileTap: _openProfile,
                onLinkDelivery: _openLinkDelivery,
              ),
            Expanded(child: _screenForIndex(_index)),
          ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNav(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
      floatingActionButton: const ChatbotChathead(),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.title,
    required this.user,
    required this.onProfileTap,
    required this.onLinkDelivery,
  });

  final String title;
  final DriverUser user;
  final VoidCallback onProfileTap;
  final VoidCallback onLinkDelivery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Link Delivery',
            onPressed: onLinkDelivery,
            icon: const Icon(Icons.link_rounded, color: AppColors.text),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: 'Customer Profile',
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _initials(user.name),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'CP';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
