import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';

/// Log entry model.
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

/// Log filter options.
enum LogLevel {
  all,
  debug,
  info,
  warning,
  error,
}

/// Logs state.
class LogsState {
  final List<LogEntry> logs;
  final LogLevel filter;
  final bool autoScroll;

  const LogsState({
    required this.logs,
    this.filter = LogLevel.all,
    this.autoScroll = true,
  });

  const LogsState.initial()
      : logs = const [],
        filter = LogLevel.all,
        autoScroll = true;

  LogsState copyWith({
    List<LogEntry>? logs,
    LogLevel? filter,
    bool? autoScroll,
  }) {
    return LogsState(
      logs: logs ?? this.logs,
      filter: filter ?? this.filter,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }

  List<LogEntry> get filteredLogs {
    if (filter == LogLevel.all) return logs;

    return logs.where((log) {
      switch (filter) {
        case LogLevel.error:
          return log.level == 'ERROR';
        case LogLevel.warning:
          return log.level == 'ERROR' || log.level == 'WARNING';
        case LogLevel.info:
          return log.level == 'ERROR' || log.level == 'WARNING' || log.level == 'INFO';
        case LogLevel.debug:
        case LogLevel.all:
          return true;
      }
    }).toList();
  }
}

/// Provider for logs state management.
class LogsNotifier extends StateNotifier<LogsState> {
  LogsNotifier() : super(const LogsState.initial()) {
    _loadLogs();
  }

  void _loadLogs() {
    final history = AppLogger.getHistory();
    final entries = history.map((line) {
      // Parse log line format: [TIMESTAMP] LEVEL: message
      final timestampMatch = RegExp(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\]').firstMatch(line);
      final levelMatch = RegExp(r'\] (\w+):').firstMatch(line);

      DateTime timestamp;
      try {
        timestamp = timestampMatch != null
            ? DateTime.parse(timestampMatch.group(1)!.replaceFirst(' ', 'T'))
            : DateTime.now();
      } catch (e) {
        timestamp = DateTime.now();
      }

      final level = levelMatch?.group(1) ?? 'INFO';
      final messageStart = line.indexOf(':', line.indexOf(']') + 1);
      final message = messageStart > 0 ? line.substring(messageStart + 1).trim() : line;

      return LogEntry(
        timestamp: timestamp,
        level: level,
        message: message,
      );
    }).toList();

    state = state.copyWith(logs: entries);
  }

  /// Refresh logs from history.
  void refresh() {
    _loadLogs();
  }

  /// Set filter level.
  void setFilter(LogLevel level) {
    state = state.copyWith(filter: level);
  }

  /// Toggle auto-scroll.
  void setAutoScroll(bool value) {
    state = state.copyWith(autoScroll: value);
  }

  /// Clear all logs.
  void clearLogs() {
    AppLogger.clearHistory();
    state = state.copyWith(logs: []);
  }
}

/// Provider for LogsNotifier.
final logsProvider = StateNotifierProvider<LogsNotifier, LogsState>((ref) {
  return LogsNotifier();
});
