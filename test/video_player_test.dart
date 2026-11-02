import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/core/utils/media_launcher.dart';
import 'package:frontend/core/widgets/app_video_player_modal.dart';
import 'package:frontend/data/demo/demo_data.dart';
import 'package:frontend/features/home/widgets/post_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Video launch and playback tests', () {
    testWidgets(
        'launchMediaUrlSafely handles empty or invalid strings gracefully',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final res = await launchMediaUrlSafely(context, '');
                    expect(res, isFalse);
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
    });

    testWidgets('AppVideoPlayerModal displays error UI cleanly for missing file',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayerModal(
              videoUrl: '/invalid/path/to/missing_video.mp4',
              title: 'Wat Phnom Evening',
              authorName: 'Dara Kim',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Wat Phnom Evening'), findsOneWidget);
      expect(find.text('Story by Dara Kim'), findsOneWidget);
      expect(find.text('Could not play video'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('Tapping play button on PostCard triggers AppVideoPlayerModal',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final videoPost = DemoData.trendingPosts().firstWhere((p) => p.isVideo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PostCard(
                  post: videoPost,
                  rank: 1,
                  onOpenPlace: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Allow demo feed simulated latency timer to complete
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Find the play button icon
      final playButton = find.byIcon(Icons.play_arrow_rounded);
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Check that the modal opened with the place name and author
      expect(find.text(videoPost.place.name), findsWidgets);
      expect(find.text('Story by ${videoPost.authorName}'), findsOneWidget);

      // Dismiss modal to cleanly dispose player & timers
      if (find.byIcon(Icons.close_rounded).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      }
    });
  });
}
