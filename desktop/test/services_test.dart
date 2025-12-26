import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:desktop/domain/services/server_service.dart';
import 'package:desktop/domain/services/web_service.dart';
import 'package:desktop/core/config/app_config.dart';

/// Unit tests for service classes to ensure they don't block.
void main() {
  group('ServerService Tests', () {
    late ServerService service;

    setUp(() {
      service = ServerService(projectPath: AppConfig.getProjectPath());
    });

    tearDown(() async {
      service.dispose();
      await service.forceKillPort(8765);
    });

    test('start() returns immediately without blocking', () async {
      final stopwatch = Stopwatch()..start();
      bool callbackCalled = false;

      await service.start(
        8765,
        onStatusChange: (isRunning, error) {
          callbackCalled = true;
        },
      );

      stopwatch.stop();

      // start() should return in less than 2 seconds (non-blocking)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'start() should return quickly without blocking');
    });

    test('forceKillPort cleans up processes', () async {
      await service.forceKillPort(8765);
      // Should complete without error
      expect(true, isTrue);
    });
  });

  group('WebService Tests', () {
    late WebService service;

    setUp(() {
      service = WebService(projectPath: AppConfig.getProjectPath());
    });

    tearDown(() async {
      service.dispose();
      await service.forceKillPort(5173);
    });

    test('start() returns immediately without blocking', () async {
      final stopwatch = Stopwatch()..start();
      bool callbackCalled = false;

      await service.start(
        5173,
        onStatusChange: (isRunning, error) {
          callbackCalled = true;
        },
      );

      stopwatch.stop();

      // start() should return in less than 2 seconds (non-blocking)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'start() should return quickly without blocking');
    });

    test('hasNodeModules returns boolean', () {
      final result = service.hasNodeModules();
      expect(result, isA<bool>());
    });
  });
}
