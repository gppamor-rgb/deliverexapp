import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/splash_screen.dart';

class DeliverexDriverApp extends StatelessWidget {
  const DeliverexDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deliverex Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
