import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root application widget.
class TYApp extends StatelessWidget {
  const TYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '天演',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
