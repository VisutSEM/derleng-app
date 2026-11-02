import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/core/widgets/app_image_preview_modal.dart';
import 'package:frontend/core/widgets/app_video_player_modal.dart';
import 'package:frontend/data/demo/demo_data.dart';
import 'package:frontend/features/home/widgets/post_detail_screen.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Image Preview & Zoom in Post Detail Screen', () {
    testWidgets(
        'AppImagePreviewModal renders title, author, and zoom toolbar controls',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppImagePreviewModal(
              imageUrl: 'https://example.com/test_photo.jpg',
              title: 'Royal Palace Golden Pavilion',
              authorName: 'Sokha Traveler',
              caption: 'Peaceful morning sunrise reflection.',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Royal Palace Golden Pavilion'), findsOneWidget);
      expect(find.text('Photo by Sokha Traveler'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);

      // Tap Zoom in
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should now show zoomed scale higher than 100%
      expect(find.text('100%'), findsNothing);
      expect(find.text('Reset'), findsOneWidget);

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets(
        'PostDetailScreen: tapping image post opens zoomable AppImagePreviewModal',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final imagePost =
          DemoData.trendingPosts().firstWhere((p) => !p.isVideo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            home: PostDetailScreen(
              post: imagePost,
              rank: 1,
              onOpenPlace: (_) {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Ensure the "Zoom" badge is visible
      expect(find.text('Zoom'), findsOneWidget);

      // Tap on the image media area
      await tester.tap(find.text('Zoom'));
      await tester.pump(const Duration(milliseconds: 300));

      // AppImagePreviewModal should be open
      expect(find.byType(AppImagePreviewModal), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);

      // Close modal
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppImagePreviewModal), findsNothing);
    });

    testWidgets(
        'PostDetailScreen: tapping video post plays video via AppVideoPlayerModal',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final videoPost = DemoData.trendingPosts().firstWhere((p) => p.isVideo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(demoMode: true),
            ),
          ],
          child: MaterialApp(
            home: PostDetailScreen(
              post: videoPost,
              rank: 2,
              onOpenPlace: (_) {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Video should have a Play button
      expect(find.text('Play'), findsOneWidget);

      // Tap on Play button
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 300));

      // AppVideoPlayerModal should be open
      expect(find.byType(AppVideoPlayerModal), findsOneWidget);
    });

    testWidgets(
        'PostDetailScreen: horizontal swipe scrolls through list of images and videos',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final post = DemoData.trendingPosts().first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(demoMode: true),
            ),
          ],
          child: MaterialApp(
            home: PostDetailScreen(
              post: post,
              rank: 1,
              onOpenPlace: (_) {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Should show initial media item indicator "1/..."
      expect(find.textContaining('1/'), findsOneWidget);

      // Swipe left on the media carousel to scroll to item 2
      await tester.fling(find.byType(PageView).first, const Offset(-400, 0), 1000);
      await tester.pump(const Duration(milliseconds: 350));

      // Should now show item 2 indicator "2/..."
      expect(find.textContaining('2/'), findsOneWidget);
    });
  });
}
