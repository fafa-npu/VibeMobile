import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/logging/app_logger.dart';
import 'core/router/app_router.dart';

/// Main application widget with Riverpod and go_router.
class VibeMobileApp extends StatefulWidget {
  const VibeMobileApp({super.key});

  @override
  State<VibeMobileApp> createState() => _VibeMobileAppState();
}

class _VibeMobileAppState extends State<VibeMobileApp>
    with WidgetsBindingObserver, WindowListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.debug('VibeMobileApp: Lifecycle state changed to $state');
    super.didChangeAppLifecycleState(state);
  }

  @override
  void onWindowFocus() {
    AppLogger.debug('VibeMobileApp: Window focused');
    // Force a rebuild to ensure UI is responsive after regaining focus
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowBlur() {
    AppLogger.debug('VibeMobileApp: Window blurred');
  }

  @override
  void onWindowRestore() {
    AppLogger.debug('VibeMobileApp: Window restored');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VibeMobile',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
    );
  }
}
