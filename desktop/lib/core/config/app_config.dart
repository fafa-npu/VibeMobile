import 'dart:io';

/// Application configuration.
class AppConfig {
  static String? _cachedProjectPath;

  /// Default API port.
  static const int defaultApiPort = 8765;

  /// Default Web UI port.
  static const int defaultWebPort = 5173;

  /// Default session prefix for tmux sessions.
  static const String defaultSessionPrefix = 'vibe';

  /// Initialize the application configuration.
  /// Should be called before using any config methods.
  static Future<void> initialize() async {
    _cachedProjectPath = _findProjectPath();
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
        '$home/Documents/repos/VibeMobile',
        '$home/VibeMobile',
        '${Directory.current.path}/VibeMobile',
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

  /// Get the project root path.
  static String getProjectPath() {
    return _cachedProjectPath ?? _findProjectPath();
  }

  /// Get the web directory path.
  static String getWebPath() {
    return '${getProjectPath()}/web';
  }

  /// Get the server directory path.
  static String getServerPath() {
    return '${getProjectPath()}/server';
  }

  // ========== SSL Configuration (Centralized) ==========

  /// Get the SSL certificate file path.
  static String get sslCertFile => '${getProjectPath()}/certs/localhost.pem';

  /// Get the SSL key file path.
  static String get sslKeyFile => '${getProjectPath()}/certs/localhost-key.pem';

  /// Check if SSL certificates exist.
  static bool get hasSslCerts =>
      File(sslCertFile).existsSync() && File(sslKeyFile).existsSync();

  /// Get the protocol scheme (http or https) based on SSL availability.
  static String get httpScheme => hasSslCerts ? 'https' : 'http';

  /// Get the WebSocket scheme (ws or wss) based on SSL availability.
  static String get wsScheme => hasSslCerts ? 'wss' : 'ws';

  /// Build API base URL for a given port.
  static String apiBaseUrl(int port) => '$httpScheme://localhost:$port';

  /// Build WebSocket URL for a given port and path.
  static String wsUrl(int port, [String path = '']) =>
      '$wsScheme://localhost:$port$path';

  /// Create an HTTP client configured for self-signed certificates.
  static HttpClient createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    if (hasSslCerts) {
      // Accept self-signed certificates for local development
      client.badCertificateCallback = (cert, host, port) => true;
    }
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
