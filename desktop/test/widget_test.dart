// VibeMobile Desktop Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desktop/app.dart';

void main() {
  testWidgets('VibeMobile app renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: VibeMobileApp(),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify that the app title is shown
    expect(find.text('VibeMobile'), findsWidgets);
  });
}
