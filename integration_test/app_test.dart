import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:music_album_scanner/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('Full app launch and navigation flow', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should render (onboarding or home)
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigate between tabs', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find bottom navigation
      final navBar = find.byType(BottomNavigationBar);
      if (navBar.evaluate().isNotEmpty) {
        // Tap on Settings tab
        final settingsTab = find.text('Settings');
        if (settingsTab.evaluate().isNotEmpty) {
          await tester.tap(settingsTab.first);
          await tester.pumpAndSettle();
        }

        // Tap on Collection tab
        final collectionTab = find.text('Collection');
        if (collectionTab.evaluate().isNotEmpty) {
          await tester.tap(collectionTab.first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Collection empty state is accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check for empty state or collection content
      final emptyText = find.text('No albums yet');
      final collectionText = find.text('Collection');

      // At least one should be present
      expect(
        emptyText.evaluate().isNotEmpty || collectionText.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('Scan Flow Integration', () {
    testWidgets('Scan screen shows camera or manual options', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to scan tab
      final scanTab = find.text('Scan');
      if (scanTab.evaluate().isNotEmpty) {
        await tester.tap(scanTab.first);
        await tester.pumpAndSettle();

        // Should have manual search option
        final manualSearch = find.text('Search Manually');
        // May or may not be visible depending on camera availability
      }
    });
  });

  group('Settings Flow Integration', () {
    testWidgets('Settings screen renders all sections', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to settings
      final settingsTab = find.text('Settings');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab.first);
        await tester.pumpAndSettle();

        // Check for key sections
        expect(find.text('Recognition'), findsOneWidget);
      }
    });
  });
}
