import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/customer_portal_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_primary_button.dart';

class CustomerLinkDeliveryScreen extends StatefulWidget {
  const CustomerLinkDeliveryScreen({super.key, this.portalService});

  final CustomerPortalService? portalService;

  @override
  State<CustomerLinkDeliveryScreen> createState() =>
      _CustomerLinkDeliveryScreenState();
}

class _CustomerLinkDeliveryScreenState
    extends State<CustomerLinkDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trackingController = TextEditingController();
  late final CustomerPortalService _portalService;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _portalService = widget.portalService ?? CustomerPortalService();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final message = await _portalService.linkDelivery(
        _trackingController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } on CustomerPortalException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to link delivery. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Link Delivery'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DriverCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connect a delivery to your account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the Tracking ID from a delivery created with your account email.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _trackingController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Tracking ID',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Tracking ID is required.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    DriverPrimaryButton(
                      label: 'Link Delivery',
                      icon: Icons.link_rounded,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
