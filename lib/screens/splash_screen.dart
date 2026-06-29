import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
import 'start_screen.dart';

typedef SplashSessionRouteBuilder =
    Widget Function(BuildContext context, SessionRestoreResult restored);

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    AuthService? authService,
    SplashSessionRouteBuilder? sessionRouteBuilder,
    WidgetBuilder? startRouteBuilder,
  }) : _authService = authService,
       _sessionRouteBuilder = sessionRouteBuilder,
       _startRouteBuilder = startRouteBuilder;

  final AuthService? _authService;
  final SplashSessionRouteBuilder? _sessionRouteBuilder;
  final WidgetBuilder? _startRouteBuilder;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? AuthService();
    Timer(const Duration(seconds: 2), _restoreOrOpenStartScreen);
  }

  Future<void> _restoreOrOpenStartScreen() async {
    if (!mounted) return;

    try {
      final restored = await _authService.restoreSession();
      if (!mounted) return;

      if (restored != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) {
              final builder = widget._sessionRouteBuilder;
              if (builder != null) {
                return builder(context, restored);
              }
              return authenticatedEntryFromRestore(restored);
            },
          ),
        );
        return;
      }
    } catch (_) {
      // Startup should fail closed to the login page.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            widget._startRouteBuilder?.call(context) ?? const StartScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Text(
            'DELIVEREX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
