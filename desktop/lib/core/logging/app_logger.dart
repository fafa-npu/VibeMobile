import 'package:logger/logger.dart';

/// Application logger with configurable output.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  static final List<String> _logHistory = [];
  static const int _maxHistorySize = 1000;

  /// Get log history for display in UI.
  static List<String> get history => List.unmodifiable(_logHistory);

  /// Get a copy of the log history.
  static List<String> getHistory() => List<String>.from(_logHistory);

  static void _addToHistory(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    _logHistory.add('[$timestamp] $level: $message');
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }
  }

  /// Log debug message.
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _addToHistory('DEBUG', message);
  }

  /// Log info message.
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _addToHistory('INFO', message);
  }

  /// Log warning message.
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _addToHistory('WARN', message);
  }

  /// Log error message.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _addToHistory('ERROR', message);
  }

  /// Log fatal error message.
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    _addToHistory('FATAL', message);
  }

  /// Clear log history.
  static void clearHistory() {
    _logHistory.clear();
  }
}
