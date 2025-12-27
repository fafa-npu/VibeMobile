import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desktop/main.dart' as app;
import 'package:desktop/presentation/providers/server_provider.dart';
import 'package:desktop/presentation/providers/session_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VibeMobile Desktop Integration Tests', () {
    testWidgets('App launches without freezing', (WidgetTester tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app launched
      expect(find.text('VibeMobile'), findsOneWidget);

      // Verify main UI elements are present (unified server card)
      expect(find.text('Server'), findsOneWidget);
    });

    testWidgets('Start Server without UI freeze', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap "Start Server" button
      final startServerButton = find.text('Start Server');
      if (startServerButton.evaluate().isNotEmpty) {
        await tester.tap(startServerButton);

        // Should NOT freeze - pump frames for a few seconds
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // UI should still be responsive
        expect(find.byType(CircularProgressIndicator), findsAny);
      }
    });

    testWidgets('Navigate to Settings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap settings icon
      final settingsIcon = find.byIcon(Icons.settings);
      expect(settingsIcon, findsOneWidget);

      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      // Verify settings screen is shown
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Navigate to Devices', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find and tap devices icon
      final devicesIcon = find.byIcon(Icons.devices);
      expect(devicesIcon, findsOneWidget);

      await tester.tap(devicesIcon);
      await tester.pumpAndSettle();

      // Verify devices screen is shown
      expect(find.text('Devices'), findsOneWidget);
    });
  });
}
