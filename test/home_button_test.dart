import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/shell/home_shell.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:frontend/models/app_user.dart';

void main() {
  group('Home Button Scroll & Refresh Tests', () {
    const testUser = AppUser(
      id: 'test-user',
      email: 'tester@derleng.app',
      name: 'Tester Sokha',
    );

    testWidgets(
        'Tapping Home tab when scrolled down scrolls smoothly to top, and when at top triggers RefreshIndicator',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(demoMode: true),
            ),
          ],
          child: const MaterialApp(
            home: HomeShell(),
          ),
        ),
      );

      // Allow demo feed to load
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Find scrollable
      final scrollableFinder = find.byType(Scrollable).first;
      ScrollableState scrollable = tester.state(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Scroll down by 500 pixels
      await tester.drag(scrollableFinder, const Offset(0, -500));
      await tester.pumpAndSettle();

      scrollable = tester.state(scrollableFinder);
      expect(scrollable.position.pixels, greaterThan(300.0));

      // Floating scroll-to-top button should also appear
      expect(find.byTooltip('Home (Scroll to top)'), findsOneWidget);

      // 1. Tap the NavigationBar Home button while scrolled down -> smoothly scrolls back to 0.0
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      scrollable = tester.state(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // 2. Tap the NavigationBar Home button while already at top -> triggers RefreshIndicator
      await tester.tap(find.text('Home'));
      await tester.pump();

      // RefreshIndicator is activated
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });
  });
}
