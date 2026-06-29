import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/phone_number.dart';
import '../core/sizes.dart';
import '../services/customer_auth_service.dart';
import '../widgets/driver/driver_card.dart';
import '../widgets/driver/driver_primary_button.dart';

class _NameCapitalizer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text;
    final capitalized = text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    if (capitalized == newValue.text) return newValue;
    return TextEditingValue(
      text: capitalized,
      selection: TextSelection.collapsed(offset: capitalized.length),
    );
  }
}

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController(text: philippinePhonePrefix);
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = CustomerAuthService();
  var _showPassword = false;
  var _showConfirmPassword = false;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authService.register(
        firstName: _firstNameController.text,
        middleName: _middleNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        mobile: phonePayloadValue(_mobileController.text),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Account Created'),
          content: const Text(
            'Your account has been created! Please wait for the admin to activate your account before signing in. If you have a tracking number, you can track your delivery anytime from the home page.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to create account. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up as Customer')),
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
                        'Create customer account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Register to see deliveries linked to your account. Tracking by code stays available without an account.',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: Sizes.s20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              enabled: !_submitting,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_NameCapitalizer()],
                              decoration: const InputDecoration(
                                labelText: 'First name',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: Sizes.s12),
                          Expanded(
                            child: TextFormField(
                              controller: _middleNameController,
                              enabled: !_submitting,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_NameCapitalizer()],
                              decoration: const InputDecoration(
                                labelText: 'Middle name',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _lastNameController,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [_NameCapitalizer()],
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required.';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _mobileController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [
                          PhilippinePhoneInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: '+639XXXXXXXXX',
                        ),
                        validator: (value) => validatePhilippinePhone(value),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_submitting,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_submitting,
                        obscureText: !_showConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () =>
                                  _showConfirmPassword = !_showConfirmPassword,
                            ),
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password.';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      DriverPrimaryButton(
                        label: 'Create account',
                        loading: _submitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).maybePop();
                          },
                          child: const Text(
                            'Already registered? Sign in',
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
