import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/transitions.dart';
import '../models/driver_user.dart';
import '../services/auth_service.dart';
import '../widgets/driver/driver_card.dart';
import 'start_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.user,
    AuthService? authService,
  }) : _authService = authService;

  final DriverUser user;
  final AuthService? _authService;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final AuthService _authService;
  var _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? AuthService();
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _authService.logout();
      if (!mounted) {
        return;
      }
      AppTransitions.pushAndClear(context, const StartScreen());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Profile'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: AppColors.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverCard(
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        _initials(widget.user.name),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.user.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Customer',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              DriverCard(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    _ProfileAction(
                      icon: Icons.link_rounded,
                      title: 'Link Delivery',
                      subtitle: 'Connect a delivery to your account.',
                      color: AppColors.primary,
                      onTap: () => Navigator.of(context).maybePop('link'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(_loggingOut ? 'Logging out...' : 'Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
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
