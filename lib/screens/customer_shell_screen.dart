import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/driver_user.dart';
import '../widgets/chatbot_chathead.dart';
import '../widgets/customer/customer_bottom_nav.dart';
import '../widgets/driver/driver_app_header.dart';
import 'customer_deliveries_screen.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_services_screen.dart';
import 'tracking_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key, required this.user});

  final DriverUser user;

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  var _index = 0;

  late final _screens = [
    CustomerHomeScreen(user: widget.user),
    TrackingScreen(showBackButton: false),
    CustomerDeliveriesScreen(user: widget.user),
    const CustomerServicesScreen(),
    CustomerProfileScreen(user: widget.user),
  ];

  static const _titles = [
    'Home',
    'Track',
    'My Deliveries',
    'Services',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            if (_index != 1) DriverAppHeader(title: _titles[_index]),
            Expanded(child: _screens[_index]),
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
