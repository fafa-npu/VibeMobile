import 'dart:async';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../core/config/app_config.dart';

/// Callback for web service status updates.
typedef WebServiceStatusCallback = void Function(bool isRunning, String? error);

/// Service for managing the Web UI dev server (Vite).
class WebService {
  Process? _webProcess;
  bool _isRunning = false;
  final String _projectPath;
  int? _startedPid;
  Timer? _healthCheckTimer;
  bool _processExited = false; // Track if process has exited
  static const _healthCheckTimeout = Duration(seconds: 3);

  WebService({required String projectPath}) : _projectPath = projectPath;

  bool get isRunning => _isRunning;
  int? get pid => _startedPid;

  /// Start the Vite dev server.
  /// Returns immediately after starting the process.
  /// Use [onStatusChange] to receive status updates.
  Future<void> start(int port, {WebServiceStatusCallback? onStatusChange}) async {
    if (_isRunning) {
      onStatusChange?.call(true, null);
      return;
    }

    AppLogger.info('WebService: Starting Vite dev server on port $port');

    // First, kill any existing process on the port to avoid "address already in use"
    await forceKillPort(port);
    // Give the OS a moment to release the port
    await Future.delayed(const Duration(milliseconds: 500));

    _processExited = false; // Reset exit flag

    try {
      // Use 'exec' to replace bash with node process
      _webProcess = await Process.start(
        '/bin/bash',
        [
          '-c',
          'cd web && exec npm run dev -- --port $port --host',
        ],
        workingDirectory: _projectPath,
      );

      // Consume stdout/stderr to prevent blocking
      // 只记录关键状态，不逐段全量 debug（避免日志风暴）
      _webProcess!.stdout.listen(
        (data) {
          final output = String.fromCharCodes(data).trim();
          if (output.isEmpty) return;
          // 只记录关键状态
          if (output.contains('ready in') ||
              output.contains('Local:') ||
              output.contains('VITE')) {
            AppLogger.info('Web: Vite server ready');
          } else if (output.toLowerCase().contains('error')) {
            AppLogger.warning('Web stdout: $output');
          }
          // 其他输出静默消费，不打印
        },
        onError: (error) => AppLogger.warning('Web stdout error: $error'),
      );

      _webProcess!.stderr.listen(
        (data) {
          final output = String.fromCharCodes(data).trim();
          if (output.isEmpty) return;
          // stderr 只记录真正的错误
          if (output.toLowerCase().contains('error') ||
              output.toLowerCase().contains('failed')) {
            AppLogger.warning('Web stderr: $output');
          }
          // 其他 stderr 输出静默消费
        },
        onError: (error) => AppLogger.warning('Web stderr error: $error'),
      );

      // Listen for process exit - this takes priority over health check
      _webProcess!.exitCode.then((code) {
        AppLogger.info('WebService: Vite exited with code $code');
        _processExited = true; // Mark as exited
        _isRunning = false;
        _webProcess = null;
        _startedPid = null;
        _healthCheckTimer?.cancel();
        _healthCheckTimer = null;
        // Always report the exit, even if health check thought we were running
        onStatusChange?.call(false, code != 0 ? 'Vite exited with code $code' : null);
      });

      // Start health check polling in background (non-blocking)
      _startHealthCheckPolling(port, onStatusChange);
    } catch (e, stack) {
      AppLogger.error('WebService: Failed to start Vite', e, stack);
      onStatusChange?.call(false, e.toString());
    }
  }

  /// Poll for health check without blocking the UI.
  void _startHealthCheckPolling(int port, WebServiceStatusCallback? onStatusChange) {
    var attempts = 0;
    const maxAttempts = 30; // 15 seconds max

    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      attempts++;

      // If process already exited, stop polling
      if (_processExited) {
        timer.cancel();
        _healthCheckTimer = null;
        return;
      }

      if (attempts > maxAttempts) {
        timer.cancel();
        _healthCheckTimer = null;
        AppLogger.error('WebService: Vite failed to start - timeout');
        _webProcess?.kill();
        _webProcess = null;
        onStatusChange?.call(false, 'Vite failed to start - timeout');
        return;
      }

      final healthy = await healthCheck(port);
      // Only mark as running if health check passes AND process hasn't exited
      if (healthy && !_processExited && _webProcess != null) {
        timer.cancel();
        _healthCheckTimer = null;
        _isRunning = true;
        _startedPid = _webProcess?.pid;
        AppLogger.info('WebService: Vite dev server started successfully');
        onStatusChange?.call(true, null);
      }
    });
  }

  /// Stop the Vite dev server.
  Future<void> stop() async {
    AppLogger.info('WebService: Stopping Vite dev server');

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    if (_webProcess != null) {
      // First try graceful shutdown with SIGTERM
      _webProcess!.kill(ProcessSignal.sigterm);

      // Wait up to 3 seconds for graceful shutdown
      await Future.delayed(const Duration(seconds: 2));

      // Force kill if still running
      try {
        _webProcess!.kill(ProcessSignal.sigkill);
      } catch (e) {
        // Process might already be dead
      }

      _webProcess = null;
    } else if (_startedPid != null) {
      // If we have the PID but lost the process reference, kill by PID
      try {
        await Process.run('kill', ['-15', _startedPid.toString()])
            .timeout(const Duration(seconds: 5));
        await Future.delayed(const Duration(seconds: 1));
        await Process.run('kill', ['-9', _startedPid.toString()])
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        // Ignore errors - process might already be dead
      }
    }

    _isRunning = false;
    _startedPid = null;
    _processExited = false;
    AppLogger.info('WebService: Vite dev server stopped');
  }

  /// Check if Vite dev server is responding.
  Future<bool> healthCheck(int port) async {
    final client = AppConfig.createHttpClient();
    client.connectionTimeout = const Duration(seconds: 2);

    try {
      // Web UI uses its own port but same SSL config
      final scheme = AppConfig.httpScheme;
      final request = await client
          .getUrl(Uri.parse('$scheme://localhost:$port/'))
          .timeout(_healthCheckTimeout);
      final response = await request.close().timeout(_healthCheckTimeout);
      await response.drain<void>();
      // Vite returns 200 for the root page
      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on OSError {
      return false;
    } on HandshakeException {
      // SSL handshake error - server might not be ready yet
      return false;
    } catch (e) {
      AppLogger.debug('WebService.healthCheck error: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Force kill any process on the specified port.
  Future<void> forceKillPort(int port) async {
    try {
      final result = await Process.run('lsof', ['-ti', ':$port'])
          .timeout(const Duration(seconds: 5));
      final pids = result.stdout.toString().trim().split('\n');
      for (final pid in pids) {
        if (pid.isNotEmpty) {
          AppLogger.debug('WebService: Killing process $pid on port $port');
          await Process.run('kill', ['-9', pid])
              .timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if npm dependencies are installed.
  bool hasNodeModules() {
    return Directory('$_projectPath/web/node_modules').existsSync();
  }

  /// Install npm dependencies.
  Future<bool> installDependencies() async {
    AppLogger.info('WebService: Installing npm dependencies');
    try {
      final result = await Process.run(
        'npm',
        ['install'],
        workingDirectory: '$_projectPath/web',
      ).timeout(const Duration(minutes: 5));

      if (result.exitCode == 0) {
        AppLogger.info('WebService: npm install completed');
        return true;
      } else {
        AppLogger.error('WebService: npm install failed: ${result.stderr}');
        return false;
      }
    } catch (e, stack) {
      AppLogger.error('WebService: npm install error', e, stack);
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    if (_webProcess != null) {
      _webProcess!.kill();
      _webProcess = null;
    }
  }
}
