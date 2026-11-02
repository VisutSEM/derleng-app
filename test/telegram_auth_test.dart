import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/features/auth/auth_controller.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/auth/register_screen.dart';
import 'package:frontend/features/auth/widgets/telegram_auth_dialog.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Telegram Sign In Tests', () {
    test('AuthController signInWithTelegram authenticates user successfully',
        () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(demoMode: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final success =
          await container.read(authProvider.notifier).signInWithTelegram(
                username: 'visut_traveler',
                name: 'Sem Visut',
              );

      expect(success, isTrue);
      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, isTrue);
      expect(authState.user?.name, equals('Sem Visut'));
      expect(authState.user?.provider, equals('telegram'));
      expect(authState.user?.email, contains('visut_traveler'));
    });

    testWidgets('LoginScreen renders Continue with Telegram button and opens dialog',
        (tester) async {
      tester.view.physicalSize = const Size(550, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final telegramButton = find.text('Continue with Telegram');
      expect(telegramButton, findsOneWidget);

      await tester.tap(telegramButton);
      await tester.pumpAndSettle();

      // Verify TelegramAuthDialog is open
      expect(find.byType(TelegramAuthDialog), findsOneWidget);
      expect(find.text('Connect Telegram'), findsOneWidget);
      expect(find.text('Telegram Username'), findsOneWidget);

      // Tap cancel to close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(TelegramAuthDialog), findsNothing);
    });

    testWidgets('RegisterScreen renders Sign up with Telegram button',
        (tester) async {
      tester.view.physicalSize = const Size(550, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign up with Telegram'), findsOneWidget);
    });
  });
}
