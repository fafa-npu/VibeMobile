import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  AppLogger.info('VibeMobile: Starting application');

  // Initialize app configuration
  try {
    await AppConfig.initialize();
    AppLogger.info('VibeMobile: Project path: ${AppConfig.getProjectPath()}');
  } catch (e, stack) {
    AppLogger.error('VibeMobile: Failed to initialize config', e, stack);
  }

  // Initialize window manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 700),
    minimumSize: Size(700, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  AppLogger.info('VibeMobile: Launching app');

  runApp(
    const ProviderScope(
      child: VibeMobileApp(),
    ),
  );
}
