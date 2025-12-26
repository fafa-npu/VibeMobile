import 'package:logger/logger.dart';

/// Application logger with configurable output.
///
/// 默认日志级别为 info，可通过 [setDebugMode] 启用 debug 模式。
/// 这样可以避免日志风暴导致 UI 卡顿。
class AppLogger {
  static bool _debugModeEnabled = false;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,  // 关闭 emoji 减少开销
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.info,  // 默认 info，不是 debug
  );

  static final List<String> _logHistory = [];
  static const int _maxHistorySize = 500;  // 减少历史大小

  /// Get log history for display in UI.
  static List<String> get history => List.unmodifiable(_logHistory);

  /// Get a copy of the log history.
  static List<String> getHistory() => List<String>.from(_logHistory);

  /// 是否启用了 debug 模式
  static bool get isDebugMode => _debugModeEnabled;

  /// 启用/禁用 debug 模式
  ///
  /// 在 debug 模式下，所有 debug 级别的日志都会被打印。
  /// 默认关闭以避免日志风暴。
  static void setDebugMode(bool enabled) {
    _debugModeEnabled = enabled;
    if (enabled) {
      info('Debug mode enabled');
    }
  }

  static void _addToHistory(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    _logHistory.add('[$timestamp] $level: $message');
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }
  }

  /// Log debug message.
  ///
  /// 只有在 debug 模式启用时才会打印到控制台。
  /// 但始终会添加到历史记录中（用于日志查看器）。
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    // 始终添加到历史，但只在 debug 模式打印
    _addToHistory('DEBUG', message);
    if (_debugModeEnabled) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
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
