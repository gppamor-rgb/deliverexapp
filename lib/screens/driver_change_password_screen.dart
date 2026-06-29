import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/sizes.dart';
import '../core/transitions.dart';
import '../models/driver_user.dart';
import '../services/auth_service.dart';
import 'driver_shell_screen.dart';
import 'start_screen.dart';

class DriverChangePasswordScreen extends StatefulWidget {
  const DriverChangePasswordScreen({
    super.key,
    required this.user,
    this.restoredOffline = false,
    this.onPasswordChanged,
    AuthService? authService,
  }) : _authService = authService;

  final DriverUser user;
  final bool restoredOffline;
  final ValueChanged<DriverUser>? onPasswordChanged;
  final AuthService? _authService;

  @override
  State<DriverChangePasswordScreen> createState() =>
      _DriverChangePasswordScreenState();
}

class _DriverChangePasswordScreenState
    extends State<DriverChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthService _authService;
  var _showCurrentPassword = false;
  var _showPassword = false;
  var _showConfirmPassword = false;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? AuthService();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
      if (!mounted) return;
      final callback = widget.onPasswordChanged;
      if (callback != null) {
        callback(user);
        return;
      }
      AppTransitions.pushAndClear(context, DriverShellScreen(user: user));
      return;
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    if (_submitting) return;
    HapticFeedback.lightImpact();
    await _authService.logout();
    if (!mounted) return;
    AppTransitions.pushAndClear(context, const StartScreen());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sizes.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: Sizes.s28),
                    _PasswordCard(
                      formKey: _formKey,
                      currentPasswordController: _currentPasswordController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      showCurrentPassword: _showCurrentPassword,
                      showPassword: _showPassword,
                      showConfirmPassword: _showConfirmPassword,
                      submitting: _submitting,
                      error: _error,
                      restoredOffline: widget.restoredOffline,
                      onToggleCurrentPassword: () => setState(
                        () => _showCurrentPassword = !_showCurrentPassword,
                      ),
                      onTogglePassword: () =>
                          setState(() => _showPassword = !_showPassword),
                      onToggleConfirmPassword: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: Sizes.s16),
                    TextButton.icon(
                      onPressed: _submitting ? null : _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: Sizes.s18),
        const Text(
          'Create new password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: Sizes.s8),
        const Text(
          'Your account uses a temporary password. Set a new password to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({
    required this.formKey,
    required this.currentPasswordController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.showCurrentPassword,
    required this.showPassword,
    required this.showConfirmPassword,
    required this.submitting,
    required this.restoredOffline,
    required this.onToggleCurrentPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSubmit,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController currentPasswordController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool showCurrentPassword;
  final bool showPassword;
  final bool showConfirmPassword;
  final bool submitting;
  final bool restoredOffline;
  final VoidCallback onToggleCurrentPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSubmit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(Sizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sizes.s20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (restoredOffline) ...[
                const _Notice(
                  text:
                      'Internet connection is required to save your new password. You can continue once the connection is restored.',
                ),
                const SizedBox(height: Sizes.s16),
              ],
              _PasswordField(
                controller: currentPasswordController,
                label: 'Current temporary password',
                hint: 'Enter temporary password',
                visible: showCurrentPassword,
                enabled: !submitting,
                onToggle: onToggleCurrentPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Current password is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: Sizes.s16),
              _PasswordField(
                controller: passwordController,
                label: 'New password',
                hint: 'Enter new password',
                visible: showPassword,
                enabled: !submitting,
                onToggle: onTogglePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required.';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: Sizes.s16),
              _PasswordField(
                controller: confirmPasswordController,
                label: 'Confirm new password',
                hint: 'Confirm new password',
                visible: showConfirmPassword,
                enabled: !submitting,
                onToggle: onToggleConfirmPassword,
                onSubmitted: (_) => onSubmit(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your new password.';
                  }
                  if (value != passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              if (error != null) ...[
                const SizedBox(height: Sizes.s16),
                _ErrorMessage(error!),
              ],
              const SizedBox(height: Sizes.s22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          onSubmit();
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Save password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.visible,
    required this.enabled,
    required this.onToggle,
    required this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool visible;
  final bool enabled;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: !visible,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onSubmitted,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.s12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Sizes.radiusSm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.s12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Sizes.radiusSm),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
