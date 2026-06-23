import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/transitions.dart';
import '../widgets/driver/driver_card.dart';
import 'tracking_screen.dart';

class CustomerServicesScreen extends StatelessWidget {
  const CustomerServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Construction logistics you can coordinate and track',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Deliverex supports operational logistics for construction and site delivery requirements — from material hauling to proof-of-delivery verification.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ServiceButton(
                    icon: Icons.support_agent_rounded,
                    label: 'Contact Support',
                    color: AppColors.primary,
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'deliverex.support@gmail.com',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServiceButton(
                    icon: Icons.search_rounded,
                    label: 'Track Delivery',
                    color: AppColors.accent,
                    onTap: () => AppTransitions.push(
                      context,
                      const TrackingScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _ServiceCard(
              icon: Icons.precision_manufacturing_rounded,
              title: 'Material Hauling',
              description:
                  'Transportation of construction materials such as aggregates, sand, gravel, and related resources.',
            ),
            const SizedBox(height: 10),
            const _ServiceCard(
              icon: Icons.local_shipping_rounded,
              title: 'Delivery and Transport',
              description:
                  'Coordination and execution of deliveries using company drivers and vehicles.',
            ),
            const SizedBox(height: 10),
            const _ServiceCard(
              icon: Icons.construction_rounded,
              title: 'Site Preparation Support',
              description:
                  'Logistics support for site preparation and construction activities.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Get in touch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Contact Information',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Reach our support team for delivery inquiries, service requests, and account assistance.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            DriverCard(
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: 'deliverex.support@gmail.com',
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'deliverex.support@gmail.com',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: '(+63) 995-582-0222',
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'tel',
                        path: '+639955820222',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: DriverCard(
        padding: const EdgeInsets.all(0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.mutedText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}
