import 'dart:io';

/// Platform-specific utilities.
class PlatformUtils {
  /// Get the default terminal application on macOS.
  static String get defaultTerminal {
    // Check if iTerm is installed
    if (Directory('/Applications/iTerm.app').existsSync()) {
      return 'iTerm';
    }
    return 'Terminal';
  }

  /// Check if tmux is installed.
  static Future<bool> isTmuxInstalled() async {
    try {
      final result = await Process.run('which', ['tmux']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if cloudflared is installed.
  static Future<bool> isCloudflaredInstalled() async {
    try {
      final result = await Process.run('which', ['cloudflared']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if npm is installed.
  static Future<bool> isNpmInstalled() async {
    try {
      final result = await Process.run('which', ['npm']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if Python virtual environment exists.
  static bool venvExists(String projectPath) {
    return Directory('$projectPath/.venv').existsSync();
  }

  /// Check if node_modules exists for web.
  static bool nodeModulesExists(String webPath) {
    return Directory('$webPath/node_modules').existsSync();
  }

  /// Open a URL in the default browser.
  static Future<bool> openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', [url]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        final result = await Process.run('start', [url], runInShell: true);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the cloudflared certificate path.
  static String get cloudflaredCertPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.cloudflared/cert.pem';
  }

  /// Check if logged in to Cloudflare.
  static bool isCloudflareLoggedIn() {
    return File(cloudflaredCertPath).existsSync();
  }
}
