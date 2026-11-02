import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/data/demo/demo_data.dart';
import 'package:frontend/features/home/widgets/post_detail_screen.dart';
import 'package:frontend/features/notifications/notifications_controller.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Comment and Reaction Feature Tests', () {
    test('PostComment toggleReaction correctly adds and removes user reaction', () {
      final comment = PostComment(
        id: 'c-test',
        authorName: 'Sokha Chan',
        text: 'Great spot!',
        createdAt: DateTime.now(),
        reactions: {'❤️': 2, '👍': 1},
      );

      // React with ❤️
      final reacted = comment.toggleReaction('❤️');
      expect(reacted.userReaction, equals('❤️'));
      expect(reacted.reactions['❤️'], equals(3));

      // Toggle off the same ❤️
      final unreacted = reacted.toggleReaction('❤️');
      expect(unreacted.userReaction, isNull);
      expect(unreacted.reactions['❤️'], equals(2));

      // Switch to 🔥
      final switched = reacted.toggleReaction('🔥');
      expect(switched.userReaction, equals('🔥'));
      expect(switched.reactions['❤️'], equals(2));
      expect(switched.reactions['🔥'], equals(1));
    });

    testWidgets('PostDetailScreen displays comment reactions and simulates traveler comment',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'derleng_session':
            '{"user":{"id":"test-user","email":"tester@derleng.app","name":"Traveler Tester"},"token":"demo-token"}',
      });
      final preferences = await SharedPreferences.getInstance();

      final post = DemoData.trendingPosts().first;
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(demoMode: true),
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: PostDetailScreen(
                    post: post,
                    onOpenPlace: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check comments section header and buttons
      expect(find.textContaining('Comments ('), findsOneWidget);
      expect(find.text('Simulate traveler'), findsOneWidget);
      expect(find.text('React'), findsWidgets);
      expect(find.text('Reply'), findsWidgets);

      final initialNotificationsCount =
          container.read(notificationsProvider).items.length;

      // Tap on the first "React" button to open the emoji picker
      await tester.tap(find.text('React').first);
      await tester.pumpAndSettle();

      // Emoji picker should be visible
      expect(find.text('🔥'), findsWidgets);

      // Tap the '🔥' emoji to react
      await tester.tap(find.text('🔥').first);
      await tester.pumpAndSettle();

      // Verify notification was loaded into notificationsProvider
      final updatedNotifs = container.read(notificationsProvider).items;
      expect(updatedNotifs.length, equals(initialNotificationsCount + 1));
      expect(updatedNotifs.first.type, equals(NotificationType.like));
      expect(updatedNotifs.first.title, contains('reacted with 🔥'));

      // Tap "Simulate traveler" button to simulate another user commenting
      await tester.tap(find.text('Simulate traveler'));
      await tester.pumpAndSettle();

      // Verify that another traveler's comment was added and notification loaded
      final notifsAfterTraveler = container.read(notificationsProvider).items;
      expect(notifsAfterTraveler.length, equals(initialNotificationsCount + 2));
      expect(notifsAfterTraveler.first.type, equals(NotificationType.comment));
      expect(notifsAfterTraveler.first.title, contains('commented on this post'));
    });
  });
}
