import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/notifications/notifications_controller.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Notifications feature tests', () {
    test('NotificationsController updates unread count and items correctly', () {
      final container = ProviderContainer(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(demoMode: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(notificationsProvider);
      expect(state.items, isNotEmpty);
      final initialUnread = state.unreadCount;
      expect(initialUnread, greaterThan(0));

      final firstUnread = state.items.firstWhere((item) => !item.isRead);
      container.read(notificationsProvider.notifier).markAsRead(firstUnread.id);
      expect(container.read(notificationsProvider).unreadCount,
          equals(initialUnread - 1));

      container.read(notificationsProvider.notifier).markAllAsRead();
      expect(container.read(notificationsProvider).unreadCount, equals(0));

      container.read(notificationsProvider.notifier).addNotification(
            title: 'New travel alert',
            message: 'A place is trending now!',
            type: NotificationType.trending,
          );
      expect(container.read(notificationsProvider).unreadCount, equals(1));
      expect(container.read(notificationsProvider).items.first.title,
          equals('New travel alert'));

      final addedId = container.read(notificationsProvider).items.first.id;
      container.read(notificationsProvider.notifier).delete(addedId);
      expect(container.read(notificationsProvider).unreadCount, equals(0));

      container.read(notificationsProvider.notifier).clearAll();
      expect(container.read(notificationsProvider).items, isEmpty);
    });

    testWidgets('Home screen displays notification bell with unread badge',
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
            initialSettingsProvider.overrideWithValue(
              const AppSettings(demoMode: true),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                onOpenPlace: (_) {},
                onExplore: () {},
              ),
            ),
          ),
        ),
      );

      // Allow demo feed simulated delay
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Find notification button
      final notifButton = find.byTooltip('Notifications');
      expect(notifButton, findsOneWidget);

      // Verify unread badge is present
      expect(find.byType(Badge), findsOneWidget);

      // Tap notification bell to open NotificationsSheet
      await tester.tap(notifButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify NotificationsSheet is displayed
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Piseth Seng liked your story'), findsOneWidget);
      expect(find.textContaining('Unread'), findsOneWidget);

      // Tap Mark all read
      final markAllReadButton = find.text('Mark all read');
      expect(markAllReadButton, findsOneWidget);
      await tester.tap(markAllReadButton);
      await tester.pumpAndSettle();

      // Filter by Unread chip
      final unreadChip = find.textContaining('Unread');
      expect(unreadChip, findsOneWidget);
      await tester.tap(unreadChip);
      await tester.pumpAndSettle();

      expect(find.text('No unread notifications'), findsOneWidget);
    });
  });
}
