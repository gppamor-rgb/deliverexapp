import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/transitions.dart';
import '../models/driver_user.dart';
import '../services/customer_portal_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_primary_button.dart';
import 'tracking_screen.dart';

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({
    super.key,
    required this.user,
    this.portalService,
  });

  final DriverUser user;
  final CustomerPortalService? portalService;

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerPortalService _portalService;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _portalService = widget.portalService ?? CustomerPortalService();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: '+63');
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launch(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open this action on your device.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _portalService.submitInquiry(
        name: _nameController.text,
        email: _emailController.text,
        phone: _normalizedPhone,
        subject: _subjectController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      _phoneController.text = '+63';
      _subjectController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry submitted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on CustomerPortalException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _normalizedPhone {
    final phone = _phoneController.text.trim();
    return phone == '+63' ? '' : phone;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Support',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Get help with tracking, linked deliveries, and account access.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SupportAction(
                icon: Icons.email_outlined,
                label: 'Email Support',
                onTap: () => _launch(
                  Uri(
                    scheme: 'mailto',
                    path: 'deliverex.support@gmail.com',
                    queryParameters: const {
                      'subject': 'Deliverex Support Inquiry',
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SupportAction(
                icon: Icons.pin_drop_outlined,
                label: 'Track Delivery',
                onTap: () =>
                    AppTransitions.push(context, const TrackingScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DriverCard(
          child: Column(
            children: [
              _ContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: 'deliverex.support@gmail.com',
                onTap: () => _launch(
                  Uri(
                    scheme: 'mailto',
                    path: 'deliverex.support@gmail.com',
                    queryParameters: const {
                      'subject': 'Deliverex Support Inquiry',
                    },
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              _ContactRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: '(+63) 995-582-0222',
                onTap: () => _launch(Uri(scheme: 'tel', path: '+639955820222')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InquiryForm(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          phoneController: _phoneController,
          subjectController: _subjectController,
          messageController: _messageController,
          error: _error,
          submitting: _submitting,
          onSubmit: _submitInquiry,
        ),
        const SizedBox(height: 18),
        const _HelpCard(
          icon: Icons.confirmation_number_outlined,
          title: 'Tracking ID',
          description:
              'Use the Tracking ID from your delivery confirmation to view public tracking details.',
        ),
        const SizedBox(height: 10),
        const _HelpCard(
          icon: Icons.link_rounded,
          title: 'Link Delivery',
          description:
              'Link a delivery to your account when its Tracking ID matches your customer email.',
        ),
        const SizedBox(height: 10),
        const _HelpCard(
          icon: Icons.lock_reset_rounded,
          title: 'Account Help',
          description:
              'Use Forgot Password on the login page for customer password reset emails.',
        ),
      ],
    );
  }
}

class _InquiryForm extends StatelessWidget {
  const _InquiryForm({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.subjectController,
    required this.messageController,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit an inquiry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _InquiryField(
              controller: nameController,
              label: 'Name',
              readOnly: true,
            ),
            const SizedBox(height: 14),
            _InquiryField(
              controller: emailController,
              label: 'Email',
              readOnly: true,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _InquiryField(
              controller: phoneController,
              label: 'Phone',
              hintText: '+63 9XX XXX XXXX',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _InquiryField(
              controller: subjectController,
              label: 'Subject',
              hintText: 'How can we help?',
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Subject is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _InquiryField(
              controller: messageController,
              label: 'Message',
              hintText: 'Describe your concern...',
              maxLines: 5,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Message is required.';
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 18),
            DriverPrimaryButton(
              label: 'Submit inquiry',
              loading: submitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _InquiryField extends StatelessWidget {
  const _InquiryField({
    required this.controller,
    required this.label,
    this.hintText,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: readOnly ? AppColors.surfaceSoft : AppColors.surface,
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: DriverCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
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

class _HelpCard extends StatelessWidget {
  const _HelpCard({
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
                    fontWeight: FontWeight.w900,
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
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
