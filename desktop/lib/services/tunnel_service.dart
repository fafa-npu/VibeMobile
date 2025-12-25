import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Service for managing Cloudflare Tunnel.
class TunnelService {
  Process? _tunnelProcess;
  bool _isConnected = false;
  String? _publicUrl;

  bool get isConnected => _isConnected;
  String? get publicUrl => _publicUrl;

  /// Check if cloudflared is installed.
  Future<bool> isCloudflaredInstalled() async {
    try {
      final result = await Process.run('which', ['cloudflared']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get cloudflared version.
  Future<String?> getVersion() async {
    try {
      final result = await Process.run('cloudflared', ['--version']);
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
      final result = await Process.run('cloudflared', ['tunnel', 'login']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Start a quick tunnel (no configuration needed).
  Future<bool> startQuickTunnel(int port) async {
    if (_isConnected) return true;

    try {
      _tunnelProcess = await Process.start(
        'cloudflared',
        ['tunnel', '--url', 'http://localhost:$port'],
      );

      // Parse output to find the public URL
      final completer = Completer<bool>();

      _tunnelProcess!.stderr.transform(utf8.decoder).listen((data) {
        // cloudflared outputs to stderr
        final urlMatch = RegExp(r'https://[\w-]+\.trycloudflare\.com')
            .firstMatch(data);
        if (urlMatch != null) {
          _publicUrl = urlMatch.group(0);
          _isConnected = true;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });

      _tunnelProcess!.exitCode.then((_) {
        _isConnected = false;
        _publicUrl = null;
        _tunnelProcess = null;
      });

      // Wait for connection or timeout
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => _isConnected,
      );
    } catch (e) {
      return false;
    }
  }

  /// Start a named tunnel (requires prior configuration).
  Future<bool> startNamedTunnel(String tunnelName) async {
    if (_isConnected) return true;

    try {
      _tunnelProcess = await Process.start(
        'cloudflared',
        ['tunnel', 'run', tunnelName],
      );

      // Wait a bit for connection
      await Future.delayed(const Duration(seconds: 5));
      _isConnected = true;

      _tunnelProcess!.exitCode.then((_) {
        _isConnected = false;
        _tunnelProcess = null;
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the tunnel.
  Future<void> stop() async {
    if (_tunnelProcess != null) {
      _tunnelProcess!.kill();
      _tunnelProcess = null;
    }
    _isConnected = false;
    _publicUrl = null;
  }

  /// List available tunnels.
  Future<List<String>> listTunnels() async {
    try {
      final result = await Process.run('cloudflared', ['tunnel', 'list']);
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
}
