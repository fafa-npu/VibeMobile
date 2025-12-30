import 'dart:io';

/// Application configuration.
class AppConfig {
  static String? _cachedProjectPath;
  static String? _cachedBundlePath;

  /// Default API port.
  static const int defaultApiPort = 8765;

  /// Default Web UI port.
  static const int defaultWebPort = 5173;

  /// Default session prefix for tmux sessions.
  static const String defaultSessionPrefix = 'vibe';

  /// Initialize the application configuration.
  /// Should be called before using any config methods.
  static Future<void> initialize() async {
    _cachedBundlePath = _findBundlePath();
    _cachedProjectPath = _findProjectPath();
  }

  /// Find the app bundle path (for bundled server files).
  static String? _findBundlePath() {
    final executable = Platform.resolvedExecutable;

    // Check if running from a .app bundle
    // Path looks like: /path/to/VibeMobile.app/Contents/MacOS/VibeMobile
    if (executable.contains('.app/Contents/MacOS/')) {
      final appPath = executable.substring(0, executable.indexOf('.app/') + 4);
      return appPath;
    }

    return null;
  }

  static String _findProjectPath() {
    final scriptPath = Platform.script.path;

    if (scriptPath.contains('desktop')) {
      // Running in development
      return scriptPath.substring(0, scriptPath.indexOf('desktop'));
    } else {
      // Running as built app - try to find VibeMobile directory
      final home = Platform.environment['HOME'] ?? '/Users';
      final possiblePaths = [
        '$home/VibeMobile',
        '${Directory.current.path}/VibeMobile',
        '${Directory.current.path}',
      ];

      for (final path in possiblePaths) {
        if (Directory(path).existsSync()) {
          return path;
        }
      }

      // Fallback
      return '$home/VibeMobile';
    }
  }

  /// Check if running from an app bundle.
  static bool get isRunningFromBundle => _cachedBundlePath != null;

  /// Get the app bundle path (null if not running from bundle).
  static String? get bundlePath => _cachedBundlePath ?? _findBundlePath();

  /// Get the bundled server directory path.
  /// Returns path to server files inside the app bundle, or null if not bundled.
  static String? getBundledServerPath() {
    final bundle = bundlePath;
    if (bundle == null) return null;

    final serverPath = '$bundle/Contents/Resources/server';
    if (Directory(serverPath).existsSync()) {
      return serverPath;
    }
    return null;
  }

  /// Get the project root path.
  static String getProjectPath() {
    return _cachedProjectPath ?? _findProjectPath();
  }

  /// Get the web directory path (for development or external server).
  static String getWebPath() {
    return '${getProjectPath()}/web';
  }

  /// Get the effective server path - bundled server takes priority.
  static String getEffectiveServerPath() {
    // First check for bundled server in app bundle
    final bundledPath = getBundledServerPath();
    if (bundledPath != null) {
      return bundledPath;
    }

    // Fall back to external web/dist directory
    return '${getProjectPath()}/web';
  }

  /// Check if bundled server exists.
  static bool hasBundledServer() {
    final bundledPath = getBundledServerPath();
    if (bundledPath == null) return false;

    return File('$bundledPath/server.cjs').existsSync();
  }

  /// Get the server directory path.
  static String getServerPath() {
    return '${getProjectPath()}/server';
  }

  // ========== SSL Configuration (Optional - Cloudflare Tunnel handles HTTPS) ==========

  /// Get the SSL certificate file path (optional).
  static String get sslCertFile => '${getProjectPath()}/certs/localhost.pem';

  /// Get the SSL key file path (optional).
  static String get sslKeyFile => '${getProjectPath()}/certs/localhost-key.pem';

  /// Check if SSL certificates exist (optional feature).
  static bool get hasSslCerts =>
      File(sslCertFile).existsSync() && File(sslKeyFile).existsSync();

  /// Get the protocol scheme - always use http for local server.
  /// Cloudflare Tunnel handles HTTPS termination for remote access.
  static String get httpScheme => 'http';

  /// Get the WebSocket scheme - always use ws for local server.
  /// Cloudflare Tunnel handles WSS termination for remote access.
  static String get wsScheme => 'ws';

  /// Build API base URL for a given port.
  static String apiBaseUrl(int port) => '$httpScheme://localhost:$port';

  /// Build WebSocket URL for a given port and path.
  static String wsUrl(int port, [String path = '']) =>
      '$wsScheme://localhost:$port$path';

  /// Create an HTTP client (no SSL handling needed for local connections).
  static HttpClient createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    return client;
  }

  // ========== End SSL Configuration ==========

  /// Check if the project directory exists.
  static bool projectExists() {
    return Directory(getProjectPath()).existsSync();
  }

  /// Check if web directory exists.
  static bool webExists() {
    return Directory(getWebPath()).existsSync();
  }

  /// Check if server directory exists.
  static bool serverExists() {
    return Directory(getServerPath()).existsSync();
  }

  /// Get the home directory.
  static String get homeDirectory {
    return Platform.environment['HOME'] ?? '/Users';
  }

  /// Check if running on macOS.
  static bool get isMacOS => Platform.isMacOS;

  /// Check if running on Windows.
  static bool get isWindows => Platform.isWindows;

  /// Check if running on Linux.
  static bool get isLinux => Platform.isLinux;
}
