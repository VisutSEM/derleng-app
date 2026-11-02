import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/features/home/feed_controller.dart';
import 'package:frontend/features/home/widgets/post_card.dart';
import 'package:frontend/features/home/widgets/post_detail_screen.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:frontend/models/geo_point.dart';
import 'package:frontend/models/place.dart';
import 'package:frontend/models/place_post.dart';

void main() {
  group('New Post Reactions Behavior Tests', () {
    const testPlace = Place(
      id: 'place-test-1',
      name: 'Angkor Sunset Viewpoint',
      category: 'attraction',
      address: 'Siem Reap, Cambodia',
      location: GeoPoint(13.4125, 103.8670),
    );

    test('New post model has 0 default reactions and clean state', () {
      final newPost = PlacePost(
        id: 'new-post-test',
        authorName: 'New Explorer',
        caption: 'First time visiting Angkor Wat at golden hour!',
        place: testPlace,
        createdAt: DateTime.now(),
        reactions: const {},
        userReaction: null,
        likes: 0,
      );

      // Verify defaults
      expect(newPost.likes, equals(0));
      expect(newPost.reactions, isEmpty);
      expect(newPost.totalReactions, equals(0));
      expect(newPost.userReaction, isNull);

      // Reacting with ❤️
      final reacted = newPost.toggleReaction('❤️');
      expect(reacted.likes, equals(1));
      expect(reacted.totalReactions, equals(1));
      expect(reacted.userReaction, equals('❤️'));
      expect(reacted.reactions['❤️'], equals(1));

      // Another user (traveler) reacting with 🔥
      final travelerReaction = Map<String, int>.from(reacted.reactions);
      travelerReaction['🔥'] = (travelerReaction['🔥'] ?? 0) + 1;
      final withTraveler = reacted.copyWith(
        reactions: travelerReaction,
      likes: travelerReaction.values.fold<int>(0, (s, c) => s + c),
      );
      expect(withTraveler.likes, equals(2));
      expect(withTraveler.totalReactions, equals(2));
    });

    testWidgets(
        'New post hides reaction count label by default (0), then loads 1 on user reaction and 2 on new traveler reaction',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final newPost = PlacePost(
        id: 'post-new-user-1',
        authorName: 'New Explorer',
        caption: 'Unforgettable moments at Angkor Wat!',
        place: testPlace,
        createdAt: DateTime.now(),
        reactions: const {},
        userReaction: null,
        likes: 0,
      );

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
                  body: PostCard(
                    post: newPost,
                    rank: 1,
                    onOpenPlace: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      container.read(feedProvider.notifier).addPost(newPost);
      await tester.pump();

      // 1. New post by default has 0 reactions -> NO reaction count number ("0") is displayed
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // 2. Current user reacts -> loads and displays count number "1"
      container.read(feedProvider.notifier).toggleReaction(newPost.id, '❤️');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // 3. New one user (traveler) reacts -> loads and updates count number to "2"
      container.read(feedProvider.notifier).addTravelerReaction(newPost.id, '🔥');
      await tester.pump();

      expect(find.text('2'), findsOneWidget);

      // 4. Switching reaction to 👍 updates cleanly
      container.read(feedProvider.notifier).toggleReaction(newPost.id, '👍');
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        'PostDetailScreen hides 0 reaction count for new post and updates on user reaction',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final newPost = PlacePost(
        id: 'post-new-user-2',
        authorName: 'New Explorer',
        caption: 'Beautiful ruins in Siem Reap',
        place: testPlace,
        createdAt: DateTime.now(),
        reactions: const {},
        userReaction: null,
        likes: 0,
      );

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
                    post: newPost,
                    onOpenPlace: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      container.read(feedProvider.notifier).addPost(newPost);
      await tester.pump(const Duration(milliseconds: 100));

      // For new post, count label "0" is not rendered
      expect(find.text('0'), findsNothing);

      // User reacts to the post
      container.read(feedProvider.notifier).toggleReaction(newPost.id, '❤️');
      await tester.pump();

      // Now "1" is loaded and visible
      expect(find.text('1'), findsWidgets);
      expect(container.read(feedProvider).likeCount(newPost), equals(1));

      // Another user reacts
      container.read(feedProvider.notifier).addTravelerReaction(newPost.id, '🔥');
      await tester.pump();

      // Count is loaded and updated to "2"
      expect(find.text('2'), findsWidgets);
      expect(container.read(feedProvider).likeCount(newPost), equals(2));

      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
