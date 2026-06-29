import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/sizes.dart';
import '../core/transitions.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
import 'customer_forgot_password_screen.dart';
import 'tracking_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  var _showPassword = false;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }

      AppTransitions.pushReplace(
        context,
        authenticatedEntryFor(user: result.user),
      );
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final headerHeight = compact ? 196.0 : 292.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      width: double.infinity,
                      child: const _BrandHeader(),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: _LoginPanel(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        showPassword: _showPassword,
                        submitting: _submitting,
                        error: _error,
                        onTogglePassword: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                        onLogin: _login,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeaderPainter(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 260;
          final logoSize = compact ? 76.0 : 118.0;
          final logoRadius = compact ? 24.0 : 34.0;
          final innerRadius = compact ? 18.0 : 26.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              Sizes.s24,
              compact ? Sizes.s16 : Sizes.s28,
              Sizes.s24,
              0,
            ),
            child: Column(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(logoRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? Sizes.s6 : Sizes.s10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(innerRadius),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? Sizes.s12 : Sizes.s28),
                Text(
                  'Deliverex',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 28 : 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: compact ? Sizes.s6 : Sizes.s10),
                Text(
                  'Providential 628 Site Preparation Services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff1e3a8a), AppColors.primary, Color(0xff2563eb)],
      ).createShader(rect);

    canvas.drawRect(rect, background);

    final softShape = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width * 0.92, 18), 145, softShape);
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.88),
      132,
      softShape,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.showPassword,
    required this.submitting,
    required this.onTogglePassword,
    required this.onLogin,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool showPassword;
  final bool submitting;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 520),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(34),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.s24,
              Sizes.s32,
              Sizes.s24,
              Sizes.s32,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: Sizes.s8),
                  const Text(
                    'Sign in to your account to continue.',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: Sizes.s24),
                  const _FieldLabel('Email Address'),
                  const SizedBox(height: Sizes.s10),
                  TextFormField(
                    controller: emailController,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Sizes.s20),
                  const _FieldLabel('Password'),
                  const SizedBox(height: Sizes.s10),
                  TextFormField(
                    controller: passwordController,
                    enabled: !submitting,
                    obscureText: !showPassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: submitting ? null : onTogglePassword,
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => onLogin(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: submitting
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              AppTransitions.push(
                                context,
                                const CustomerForgotPasswordScreen(),
                              );
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.only(top: Sizes.s4),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: Sizes.s12),
                    Container(
                      padding: const EdgeInsets.all(Sizes.s12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(Sizes.radiusSm),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Sizes.s18),
                  SizedBox(
                    height: 58,
                    child: FilledButton(
                      onPressed: submitting
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              onLogin();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.62,
                        ),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 7,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      ),
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
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: Sizes.s18),
                  const _DividerLabel(label: 'or continue without an account'),
                  const SizedBox(height: Sizes.s16),
                  SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: submitting
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              AppTransitions.push(
                                context,
                                const TrackingScreen(),
                              );
                            },
                      icon: const Icon(Icons.inventory_2_outlined, size: 22),
                      label: const Text('Track a Delivery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff1e3a8a),
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
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
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: AppColors.mutedText,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        const Divider(color: AppColors.border),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: Sizes.s8),
          child: Text(label, textAlign: TextAlign.center, style: labelStyle),
        ),
      ],
    );
  }
}
