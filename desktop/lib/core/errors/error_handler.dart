import 'dart:async';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import 'failures.dart';

/// Global error handler for the application.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Stream controller for error events.
  final StreamController<Failure> _errorController = StreamController<Failure>.broadcast();

  /// Stream of error events for UI to listen to.
  Stream<Failure> get errors => _errorController.stream;

  /// Handle a failure.
  void handleFailure(Failure failure) {
    AppLogger.error(failure.message, failure.error, failure.stackTrace);
    _errorController.add(failure);
  }

  /// Handle an exception and convert to failure.
  Failure handleException(Object error, [StackTrace? stackTrace, String? context]) {
    final message = context != null ? '$context: $error' : error.toString();
    final failure = UnknownFailure(message, error, stackTrace);
    handleFailure(failure);
    return failure;
  }

  /// Run an async operation with error handling.
  Future<T?> runAsync<T>(
    Future<T> Function() operation, {
    String? context,
    Failure Function(Object error, StackTrace? stackTrace)? onError,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final failure = onError?.call(error, stackTrace) ??
          UnknownFailure(context ?? error.toString(), error, stackTrace);
      handleFailure(failure);
      return null;
    }
  }

  /// Run a sync operation with error handling.
  T? runSync<T>(
    T Function() operation, {
    String? context,
    Failure Function(Object error, StackTrace? stackTrace)? onError,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      final failure = onError?.call(error, stackTrace) ??
          UnknownFailure(context ?? error.toString(), error, stackTrace);
      handleFailure(failure);
      return null;
    }
  }

  /// Set up global error handling for Flutter.
  void setupGlobalErrorHandling() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'Flutter error: ${details.exception}',
        details.exception,
        details.stack,
      );
      // In debug mode, also print to console
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.fatal('Unhandled error: $error', error, stack);
      return true; // Prevent crash
    };
  }

  /// Dispose resources.
  void dispose() {
    _errorController.close();
  }
}
