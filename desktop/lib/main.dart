import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const VibeMobileApp());
}

class VibeMobileApp extends StatefulWidget {
  const VibeMobileApp({super.key});

  @override
  State<VibeMobileApp> createState() => _VibeMobileAppState();
}

class _VibeMobileAppState extends State<VibeMobileApp> {
  final _appProvider = AppProvider();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Get the project path (parent of desktop folder)
    final scriptPath = Platform.script.path;
    String projectPath;

    if (scriptPath.contains('desktop')) {
      // Running in development
      projectPath = scriptPath.substring(0, scriptPath.indexOf('desktop'));
    } else {
      // Running as built app - use default path
      projectPath = '${Platform.environment['HOME']}/Documents/repos/VibeMobile';
    }

    await _appProvider.init(projectPath);

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appProvider,
      child: MaterialApp(
        title: 'VibeMobile',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: _initialized
            ? const HomeScreen()
            : const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在初始化...'),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
