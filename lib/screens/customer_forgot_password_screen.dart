import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/sizes.dart';
import '../services/customer_auth_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_primary_button.dart';

class CustomerForgotPasswordScreen extends StatefulWidget {
  const CustomerForgotPasswordScreen({
    super.key,
    CustomerAuthService? authService,
  }) : _authService = authService;

  final CustomerAuthService? _authService;

  @override
  State<CustomerForgotPasswordScreen> createState() =>
      _CustomerForgotPasswordScreenState();
}

class _CustomerForgotPasswordScreenState
    extends State<CustomerForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final CustomerAuthService _authService;
  var _submitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? CustomerAuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final message = await _authService.forgotPassword(
        email: _emailController.text,
      );
      if (!mounted) return;
      setState(() => _success = message);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to send reset link. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sizes.s20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: DriverCard(
                padding: const EdgeInsets.fromLTRB(
                  Sizes.s24,
                  30,
                  Sizes.s24,
                  Sizes.s24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Reset customer password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the email on your customer account. If it exists, we will send a password reset link.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: Sizes.s20),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Email is required.';
                          }
                          if (!email.contains('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _MessageBox(message: _error!, color: AppColors.danger),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 14),
                        _MessageBox(
                          message: _success!,
                          color: AppColors.success,
                        ),
                      ],
                      const SizedBox(height: 18),
                      DriverPrimaryButton(
                        label: 'Send reset link',
                        loading: _submitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Drivers: please contact your administrator to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).maybePop();
                                },
                          child: const Text(
                            'Back to sign in',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
