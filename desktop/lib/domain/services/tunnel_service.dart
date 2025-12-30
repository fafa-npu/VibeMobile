import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../core/config/app_config.dart';

/// Callback type for tunnel events.
typedef TunnelReadyCallback = void Function(String url);
typedef TunnelDisconnectedCallback = void Function();
typedef TunnelErrorCallback = void Function(String error);

/// Service for managing Cloudflare Tunnel.
class TunnelService {
  Process? _tunnelProcess;
  bool _isConnected = false;
  String? _publicUrl;
  StreamSubscription? _stderrSubscription;
  bool _isStarting = false;
  Timer? _startTimeout;
  static const _processTimeout = Duration(seconds: 10);

  bool get isConnected => _isConnected;
  bool get isStarting => _isStarting;
  String? get publicUrl => _publicUrl;

  /// Callback for when tunnel URL is available.
  TunnelReadyCallback? onTunnelReady;

  /// Callback for when tunnel disconnects.
  TunnelDisconnectedCallback? onTunnelDisconnected;

  /// Callback for tunnel errors.
  TunnelErrorCallback? onTunnelError;

  /// Check if cloudflared is installed.
  Future<bool> isCloudflaredInstalled() async {
    try {
      final result = await Process.run('which', ['cloudflared'])
          .timeout(_processTimeout);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get cloudflared version.
  Future<String?> getVersion() async {
    try {
      final result = await Process.run('cloudflared', ['--version'])
          .timeout(_processTimeout);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is logged in to Cloudflare.
  Future<bool> isLoggedIn() async {
    final certPath = '${Platform.environment['HOME']}/.cloudflared/cert.pem';
    return File(certPath).existsSync();
  }

  /// Start cloudflared login process.
  Future<bool> login() async {
    try {
      final result = await Process.run('cloudflared', ['tunnel', 'login'])
          .timeout(const Duration(minutes: 5));
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Start a quick tunnel (no configuration needed).
  /// Uses HTTPS origin if SSL certificates are available.
  Future<bool> startQuickTunnel(int port, {String? proxyUrl}) async {
    if (_isConnected || _isStarting) return _isConnected;

    _isStarting = true;
    String? lastError;

    // Use centralized config to determine origin URL
    final originUrl = AppConfig.apiBaseUrl(port);
    AppLogger.info('TunnelService: Starting quick tunnel for $originUrl');

    // Setup timeout timer (30 seconds)
    _startTimeout = Timer(const Duration(seconds: 30), () {
      if (_isStarting) {
        AppLogger.warning('TunnelService: Startup timeout');
        _cancelStarting();
        onTunnelError?.call('Tunnel 启动超时，请检查网络连接或代理设置');
      }
    });

    try {
      // Set up environment with proxy if provided
      final environment = Map<String, String>.from(Platform.environment);
      if (proxyUrl != null && proxyUrl.isNotEmpty) {
        environment['HTTPS_PROXY'] = proxyUrl;
        environment['HTTP_PROXY'] = proxyUrl;
        AppLogger.info('TunnelService: Using proxy: $proxyUrl');
      }

      // Build cloudflared arguments
      final args = ['tunnel', '--url', originUrl];

      _tunnelProcess = await Process.start(
        'cloudflared',
        args,
        environment: environment,
      );

      // Parse output to find the public URL
      // 只提取 URL 和错误，不打印全部输出（避免日志风暴）
      _stderrSubscription = _tunnelProcess!.stderr
          .transform(utf8.decoder)
          .listen(
        (data) {
          // 删除: AppLogger.debug('cloudflared: $data');
          // cloudflared 输出非常多，会造成日志风暴

          // cloudflared outputs to stderr
          final urlMatch = RegExp(r'https://[\w-]+\.trycloudflare\.com')
              .firstMatch(data);
          if (urlMatch != null && !_isConnected) {
            _publicUrl = urlMatch.group(0);
            _isConnected = true;
            _isStarting = false;
            _startTimeout?.cancel();
            _startTimeout = null;
            AppLogger.info('TunnelService: Connected at $_publicUrl');
            onTunnelReady?.call(_publicUrl!);
          }

          // Check for common errors - 只记录错误
          if (data.contains('failed to request quick Tunnel') ||
              data.contains('EOF') ||
              data.contains('connection refused')) {
            lastError = 'Cloudflare 连接失败，请检查网络或配置代理';
            AppLogger.warning('TunnelService: $lastError');
          }
        },
        onError: (error) {
          AppLogger.warning('cloudflared stderr error: $error');
          lastError = error.toString();
        },
        cancelOnError: false,
      );

      // Handle process exit
      _tunnelProcess!.exitCode.then((exitCode) {
        AppLogger.info('TunnelService: cloudflared exited with code $exitCode');
        final wasStarting = _isStarting;
        _cleanup();

        if (wasStarting && exitCode != 0) {
          onTunnelError?.call(lastError ?? 'cloudflared 启动失败 (code: $exitCode)');
        } else {
          onTunnelDisconnected?.call();
        }
      });

      // Wait briefly to check if process exits immediately
      await Future.delayed(const Duration(milliseconds: 500));

      if (_tunnelProcess == null) {
        _isStarting = false;
        _startTimeout?.cancel();
        _startTimeout = null;
        return false;
      }

      return true;
    } catch (e, stack) {
      AppLogger.error('TunnelService: Failed to start cloudflared', e, stack);
      _isStarting = false;
      _startTimeout?.cancel();
      _startTimeout = null;
      _cleanup();
      onTunnelError?.call('无法启动 cloudflared: $e');
      return false;
    }
  }

  void _cleanup() {
    _stderrSubscription?.cancel();
    _stderrSubscription = null;
    _startTimeout?.cancel();
    _startTimeout = null;
    _isConnected = false;
    _isStarting = false;
    _publicUrl = null;
    _tunnelProcess = null;
  }

  void _cancelStarting() {
    if (!_isStarting) return;

    AppLogger.info('TunnelService: Cancelling tunnel startup');
    _startTimeout?.cancel();
    _startTimeout = null;
    _stderrSubscription?.cancel();
    _stderrSubscription = null;

    if (_tunnelProcess != null) {
      _tunnelProcess!.kill();
      _tunnelProcess = null;
    }

    _isStarting = false;
    _isConnected = false;
    _publicUrl = null;
  }

  /// Cancel the current tunnel startup process.
  void cancelStarting() {
    if (_isStarting) {
      _cancelStarting();
      onTunnelError?.call('Tunnel 启动已取消');
    }
  }

  /// Start a named tunnel (requires prior configuration).
  /// Uses the tunnel's configured hostname from ~/.cloudflared/config.yml
  /// or the hostname parameter if provided.
  Future<bool> startNamedTunnel(String tunnelName, {String? hostname}) async {
    if (_isConnected || _isStarting) return _isConnected;

    _isStarting = true;
    AppLogger.info('TunnelService: Starting named tunnel: $tunnelName');

    // Setup timeout timer (30 seconds)
    _startTimeout = Timer(const Duration(seconds: 30), () {
      if (_isStarting) {
        AppLogger.warning('TunnelService: Named tunnel startup timeout');
        _cancelStarting();
        onTunnelError?.call('Named tunnel 启动超时');
      }
    });

    try {
      _tunnelProcess = await Process.start(
        'cloudflared',
        ['tunnel', 'run', tunnelName],
      );

      // Monitor stderr for connection status
      _stderrSubscription = _tunnelProcess!.stderr
          .transform(utf8.decoder)
          .listen(
        (data) {
          // Check for successful connection indicators
          if (data.contains('Connection') && data.contains('registered') ||
              data.contains('Registered tunnel connection')) {
            if (!_isConnected) {
              _isConnected = true;
              _isStarting = false;
              _startTimeout?.cancel();
              _startTimeout = null;

              // Use provided hostname or construct from tunnel name
              if (hostname != null && hostname.isNotEmpty) {
                _publicUrl = hostname.startsWith('http') ? hostname : 'https://$hostname';
              } else {
                _publicUrl = 'https://$tunnelName.your-domain.com';
              }

              AppLogger.info('TunnelService: Named tunnel connected at $_publicUrl');
              onTunnelReady?.call(_publicUrl!);
            }
          }

          // Check for errors
          if (data.contains('error') || data.contains('failed')) {
            AppLogger.warning('TunnelService: Named tunnel error: $data');
          }
        },
        onError: (error) {
          AppLogger.warning('TunnelService: Named tunnel stderr error: $error');
        },
        cancelOnError: false,
      );

      // Handle process exit
      _tunnelProcess!.exitCode.then((exitCode) {
        AppLogger.info('TunnelService: Named tunnel exited with code $exitCode');
        final wasStarting = _isStarting;
        _cleanup();

        if (wasStarting && exitCode != 0) {
          onTunnelError?.call('Named tunnel 启动失败 (code: $exitCode)');
        } else {
          onTunnelDisconnected?.call();
        }
      });

      return true;
    } catch (e, stack) {
      AppLogger.error('TunnelService: Failed to start named tunnel', e, stack);
      _isStarting = false;
      _startTimeout?.cancel();
      _startTimeout = null;
      _cleanup();
      onTunnelError?.call('无法启动 named tunnel: $e');
      return false;
    }
  }

  /// Stop the tunnel.
  Future<void> stop() async {
    AppLogger.info('TunnelService: Stopping tunnel');
    _startTimeout?.cancel();
    _startTimeout = null;
    _stderrSubscription?.cancel();
    _stderrSubscription = null;
    if (_tunnelProcess != null) {
      _tunnelProcess!.kill();
      _tunnelProcess = null;
    }
    _isConnected = false;
    _isStarting = false;
    _publicUrl = null;
  }

  /// List available tunnels.
  Future<List<String>> listTunnels() async {
    try {
      final result = await Process.run('cloudflared', ['tunnel', 'list'])
          .timeout(_processTimeout);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        // Skip header line
        return lines.skip(1).map((line) {
          final parts = line.split(RegExp(r'\s+'));
          return parts.length > 1 ? parts[1] : '';
        }).where((name) => name.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Dispose resources.
  void dispose() {
    stop();
  }
}
