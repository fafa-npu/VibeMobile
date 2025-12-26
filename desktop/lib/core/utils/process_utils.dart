import 'dart:async';
import 'dart:io';

import '../logging/app_logger.dart';

/// Exception thrown when a process times out.
class ProcessTimeoutException implements Exception {
  final String message;
  const ProcessTimeoutException(this.message);

  @override
  String toString() => 'ProcessTimeoutException: $message';
}

/// Exception thrown when a process fails.
class ProcessFailedException implements Exception {
  final String message;
  final int exitCode;
  final String stderr;

  const ProcessFailedException({
    required this.message,
    required this.exitCode,
    this.stderr = '',
  });

  @override
  String toString() => 'ProcessFailedException: $message (exit code: $exitCode)';
}

/// Utility class for running processes with timeout protection.
class ProcessUtils {
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// Run a process with timeout protection.
  ///
  /// Returns [ProcessResult] on success.
  /// Throws [ProcessTimeoutException] if the process times out.
  /// Throws [ProcessFailedException] if the process fails.
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Duration? timeout,
    String? workingDirectory,
    Map<String, String>? environment,
    bool throwOnError = false,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;

    AppLogger.debug('ProcessUtils.run: $executable ${arguments.join(' ')}');

    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      ).timeout(effectiveTimeout);

      if (throwOnError && result.exitCode != 0) {
        throw ProcessFailedException(
          message: 'Process failed: $executable',
          exitCode: result.exitCode,
          stderr: result.stderr.toString(),
        );
      }

      return result;
    } on TimeoutException {
      AppLogger.warning('ProcessUtils: Process timed out: $executable');
      throw ProcessTimeoutException('Process timed out after ${effectiveTimeout.inSeconds}s: $executable');
    }
  }

  /// Start a long-running process.
  ///
  /// Returns the [Process] handle. Caller is responsible for consuming
  /// stdout/stderr to prevent blocking.
  static Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    AppLogger.debug('ProcessUtils.start: $executable ${arguments.join(' ')}');

    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  /// Check if a command exists.
  static Future<bool> commandExists(String command) async {
    try {
      final result = await run('which', [command], timeout: const Duration(seconds: 3));
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Kill a process by PID.
  static Future<bool> killProcess(int pid, {ProcessSignal signal = ProcessSignal.sigterm}) async {
    try {
      final result = await run('kill', ['-${signal.signalNumber}', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Find PIDs using a port.
  static Future<List<int>> findPidsOnPort(int port) async {
    try {
      final result = await run('lsof', ['-ti', ':$port']);
      if (result.exitCode != 0) return [];

      return result.stdout
          .toString()
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}

/// Extension on ProcessSignal to get signal number.
extension ProcessSignalExtension on ProcessSignal {
  int get signalNumber {
    switch (this) {
      case ProcessSignal.sigterm:
        return 15;
      case ProcessSignal.sigkill:
        return 9;
      case ProcessSignal.sigint:
        return 2;
      case ProcessSignal.sighup:
        return 1;
      default:
        return 15;
    }
  }
}
