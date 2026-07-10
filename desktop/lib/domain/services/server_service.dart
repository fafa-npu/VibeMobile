import 'dart:async';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../core/config/app_config.dart';

/// Callback for server service status updates.
typedef ServerServiceStatusCallback = void Function(bool isRunning, String? error);

/// Service for managing the backend API server (Node.js).
class ServerService {
  Process? _serverProcess;
  bool _isRunning = false;
  final String _projectPath;
  int? _startedPid;
  Timer? _healthCheckTimer;
  bool _processExited = false; // Track if process has exited
  static const _healthCheckTimeout = Duration(seconds: 3);

  ServerService({required String projectPath}) : _projectPath = projectPath;

  bool get isRunning => _isRunning;
  int? get pid => _startedPid;

  /// Start the backend server.
  /// Returns immediately after starting the process.
  /// Use [onStatusChange] to receive status updates.
  Future<void> start(int port, {ServerServiceStatusCallback? onStatusChange}) async {
    if (_isRunning) {
      onStatusChange?.call(true, null);
      return;
    }

    AppLogger.info('ServerService: Starting Node.js server on port $port');

    // First, kill any existing process on the port to avoid "address already in use"
    await forceKillPort(port);
    // Give the OS a moment to release the port
    await Future.delayed(const Duration(milliseconds: 500));

    _processExited = false; // Reset exit flag

    try {
      // Determine server path and command
      String serverDir;
      String serverCmd;

      // Priority 1: Bundled server in app bundle
      final bundledServerPath = AppConfig.getBundledServerPath();
      if (bundledServerPath != null && await File('$bundledServerPath/server.cjs').exists()) {
        serverDir = bundledServerPath;
        serverCmd = 'node server.cjs';
        AppLogger.info('ServerService: Running bundled server from app bundle');
      }
      // Priority 2: Built server in web/dist
      else {
        final webDir = '$_projectPath/web';
        final builtServerPath = '$webDir/dist/server.cjs';

        if (await File(builtServerPath).exists()) {
          // Production: run built server
          serverDir = webDir;
          serverCmd = 'node dist/server.cjs';
          AppLogger.info('ServerService: Running production build from web/dist');
        } else {
          // Development: run with tsx
          serverDir = webDir;
          serverCmd = 'npx tsx server/index.ts';
          AppLogger.info('ServerService: Running development mode');
        }
      }

      // Set environment variables (HTTP by default, Cloudflare handles HTTPS)
      final environment = AppConfig.processEnvironment
        ..addAll({
          'PORT': port.toString(),
          'HOST': '0.0.0.0',
        });

      AppLogger.info('ServerService: Server directory: $serverDir');
      AppLogger.info('ServerService: Server command: $serverCmd');

      _serverProcess = await Process.start(
        '/bin/bash',
        ['-c', 'exec $serverCmd'],
        workingDirectory: serverDir,
        environment: environment,
      );

      // Consume stdout/stderr to prevent blocking
      _serverProcess!.stdout.listen(
        (data) {
          final output = String.fromCharCodes(data).trim();
          if (output.isEmpty) return;
          // Log key status messages
          if (output.contains('VibeMobile server running') ||
              output.contains('Started monitoring')) {
            AppLogger.info('Server: Started successfully');
          } else if (output.toLowerCase().contains('error')) {
            AppLogger.warning('Server stdout: $output');
          }
        },
        onError: (error) => AppLogger.warning('Server stdout error: $error'),
      );

      _serverProcess!.stderr.listen(
        (data) {
          final output = String.fromCharCodes(data).trim();
          if (output.isEmpty) return;
          // Only log real errors
          if (output.toLowerCase().contains('error') ||
              output.toLowerCase().contains('exception') ||
              output.toLowerCase().contains('failed')) {
            AppLogger.warning('Server stderr: $output');
          }
        },
        onError: (error) => AppLogger.warning('Server stderr error: $error'),
      );

      // Listen for process exit - this takes priority over health check
      _serverProcess!.exitCode.then((code) {
        AppLogger.info('ServerService: Server exited with code $code');
        _processExited = true; // Mark as exited
        _isRunning = false;
        _serverProcess = null;
        _startedPid = null;
        _healthCheckTimer?.cancel();
        _healthCheckTimer = null;
        // Always report the exit, even if health check thought we were running
        onStatusChange?.call(false, code != 0 ? 'Server exited with code $code' : null);
      });

      // Start health check polling in background (non-blocking)
      _startHealthCheckPolling(port, onStatusChange);
    } catch (e, stack) {
      AppLogger.error('ServerService: Failed to start server', e, stack);
      onStatusChange?.call(false, e.toString());
    }
  }

  /// Poll for health check without blocking the UI.
  void _startHealthCheckPolling(int port, ServerServiceStatusCallback? onStatusChange) {
    var attempts = 0;
    const maxAttempts = 20; // 10 seconds max

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
        AppLogger.error('ServerService: Server failed to start - timeout');
        _serverProcess?.kill();
        _serverProcess = null;
        onStatusChange?.call(false, 'Server failed to start - timeout');
        return;
      }

      final healthy = await healthCheck(port);
      // Only mark as running if health check passes AND process hasn't exited
      if (healthy && !_processExited && _serverProcess != null) {
        timer.cancel();
        _healthCheckTimer = null;
        _isRunning = true;
        _startedPid = _serverProcess?.pid;
        AppLogger.info('ServerService: Server started successfully');
        onStatusChange?.call(true, null);
      }
    });
  }

  /// Stop the backend server.
  Future<void> stop(int port) async {
    AppLogger.info('ServerService: Stopping server');

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    if (_serverProcess != null) {
      // First try graceful shutdown with SIGTERM
      _serverProcess!.kill(ProcessSignal.sigterm);

      // Wait briefly for graceful shutdown (non-blocking timer handles it)
      await Future.delayed(const Duration(seconds: 2));

      // Force kill if process still exists
      try {
        _serverProcess?.kill(ProcessSignal.sigkill);
      } catch (e) {
        // Process might already be dead
      }

      _serverProcess = null;
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
    AppLogger.info('ServerService: Server stopped');
  }

  /// Check if server is responding.
  Future<bool> healthCheck(int port) async {
    final client = AppConfig.createHttpClient();
    client.connectionTimeout = const Duration(seconds: 2);

    try {
      final url = '${AppConfig.apiBaseUrl(port)}/health';
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(_healthCheckTimeout);
      final response = await request.close().timeout(_healthCheckTimeout);
      // 200 means healthy, 401 means server is running but needs auth
      final isHealthy = response.statusCode == 200 || response.statusCode == 401;
      await response.drain<void>();
      return isHealthy;
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
      AppLogger.debug('ServerService.healthCheck error: $e');
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
          AppLogger.debug('ServerService: Killing process $pid on port $port');
          await Process.run('kill', ['-9', pid])
              .timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Dispose resources.
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    if (_serverProcess != null) {
      _serverProcess!.kill();
      _serverProcess = null;
    }
  }
}
