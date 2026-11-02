import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app.dart';
import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/utils/formatters.dart';
import 'package:frontend/core/utils/polyline.dart';
import 'package:frontend/data/demo/demo_data.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/data/services/location_service.dart';
import 'package:frontend/features/explore/explore_controller.dart';
import 'package:frontend/models/app_settings.dart';
import 'package:frontend/models/app_user.dart';
import 'package:frontend/models/geo_point.dart';
import 'package:frontend/models/nearby_category.dart';

const _testUser = AppUser(
  id: 'test-user',
  email: 'sokha.chan@derleng.app',
  name: 'Sokha Chan',
);

class _FakeLocationService extends LocationService {
  @override
  Future<GeoPoint?> current({
    bool requestPermission = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return null;
  }
}

class _MountainViewLocationService extends LocationService {
  @override
  Future<GeoPoint?> current({
    bool requestPermission = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const GeoPoint(37.4219983, -122.084);
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AppUser? user,
}) async {
  tester.view.physicalSize = const Size(500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionProvider.overrideWithValue(
          user == null ? null : AuthSession(user: user, token: 'test-token'),
        ),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(demoMode: true),
        ),
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
      ],
      child: const DerlengApp(),
    ),
  );
  // Let the demo feed finish its simulated request.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _openExplore(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.explore_outlined));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Use demo account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Use demo account'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Sign in'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DemoData.resetPosts();
  });

  testWidgets('shows the sign-in screen when signed out', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Derleng'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('demo sign-in opens the home feed', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester);
    // Let the demo feed finish loading.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Viral right now'), findsOneWidget);
    expect(find.text('Trending posts'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('home view displays user profile photo and quick post prompt',
      (tester) async {
    await _pumpApp(
      tester,
      user: const AppUser(
        id: 'test-user',
        email: 'sokha.chan@derleng.app',
        name: 'Sokha Chan',
        photoUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      ),
    );

    // Verify greeting and share place prompt are visible on Home
    expect(find.text('Hi Sokha, find your next story'), findsOneWidget);
    expect(find.text('Share a place you love, Sokha…'), findsOneWidget);

    // Tapping the avatar in the header navigates to the Profile tab
    await tester.tap(find.byTooltip('Go to Profile'));
    await tester.pumpAndSettle();

    expect(find.text('MY STORIES'), findsOneWidget);
    expect(find.text('Edit photo'), findsOneWidget);
  });

  testWidgets('home feed saves a trending place', (tester) async {
    await _pumpApp(tester, user: _testUser);

    expect(find.textContaining('Sunrise over the Royal Palace'), findsOneWidget);
    // Verifies author initials "SC" for Sokha Chan when no profile photo is present
    expect(find.text('SC'), findsWidgets);

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(find.text('Saved Royal Palace'), findsOneWidget);
    expect(find.text('Saved'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Saved'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved places'), findsOneWidget);
    expect(find.text('Royal Palace'), findsWidgets);
  });

  testWidgets(
      'tapping a post card opens detail screen with Get Directions and comments',
      (tester) async {
    await _pumpApp(tester, user: _testUser);

    expect(find.textContaining('Sunrise over the Royal Palace'), findsOneWidget);

    // Tap on the post card caption to open post detail
    await tester.tap(find.textContaining('Sunrise over the Royal Palace'));
    await tester.pumpAndSettle();

    // Verify detail screen elements
    expect(find.text('Get Directions'), findsOneWidget);
    expect(find.text('Driving'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Moto/Bike'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Maps App'), findsOneWidget);
    expect(find.textContaining('Comments ('), findsOneWidget);
    expect(find.text('Add a comment…'), findsOneWidget);

    // Type a new comment and submit
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a comment…'),
      "Can't wait to visit this weekend!",
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text("Can't wait to visit this weekend!"), findsOneWidget);

    // Tap Get Directions button
    await tester.tap(find.text('Get Directions'));
    await tester.pumpAndSettle();

    // Verify it navigates and opens route on explore map
    expect(find.text('Start navigation'), findsOneWidget);
    expect(find.text('Royal Palace'), findsWidgets);
  });

  testWidgets('user can post and share a place to the home feed',
      (tester) async {
    await _pumpApp(tester, user: _testUser);

    expect(find.text('Post place'), findsOneWidget);
    await tester.tap(find.text('Post place'));
    await tester.pumpAndSettle();

    expect(find.text('New post'), findsOneWidget);
    expect(find.text("Your placed ..."), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'The morning monks walk near Wat Phnom was truly unforgettable!',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('The morning monks walk'), findsOneWidget);
  });

  testWidgets(
      'user can add a new tag place with custom category and tag it to post',
      (tester) async {
    await _pumpApp(tester, user: _testUser);

    expect(find.text('Post place'), findsOneWidget);
    await tester.tap(find.text('Post place'));
    await tester.pumpAndSettle();

    // The location pill initially shows Royal Palace
    expect(find.text('Royal Palace'), findsWidgets);

    // Tap the location pill to open the place picker bottom sheet
    await tester.tap(find.text('Royal Palace').first);
    await tester.pumpAndSettle();

    expect(find.text('Tag a place'), findsOneWidget);
    expect(find.text('Add new tag place'), findsOneWidget);

    // Tap "Add new tag place" tile
    await tester.tap(find.text('Add new tag place'));
    await tester.pumpAndSettle();

    expect(find.text('Add new tag place'), findsOneWidget);
    expect(find.text('Place title *'), findsOneWidget);
    expect(find.text('Category *'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Coffee / Cafe'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Temple / Pagoda'), findsOneWidget);

    // Enter place title in the bottom sheet
    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first,
      'Bayon Ancient Temple Gate',
    );
    await tester.pumpAndSettle();

    // Select category chip "Temple / Pagoda"
    await tester.tap(find.widgetWithText(ChoiceChip, 'Temple / Pagoda'));
    await tester.pumpAndSettle();

    // Tap Save & Tag Place button
    await tester.tap(find.text('Save & Tag Place'));
    await tester.pumpAndSettle();

    // Verify the composer location pill updated to the new place
    expect(find.text('Bayon Ancient Temple Gate'), findsOneWidget);

    // Enter post caption
    await tester.enterText(
      find.byType(TextField).first,
      'Exploring the mysterious faces at Angkor Thom!',
    );
    await tester.pumpAndSettle();

    // Submit post
    await tester.tap(find.text('Next'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify new post appears in feed with the custom tagged place
    expect(find.text('Bayon Ancient Temple Gate'), findsWidgets);
    expect(
      find.textContaining('Exploring the mysterious faces'),
      findsOneWidget,
    );
  });

  testWidgets('post cards adapt to vertical and landscape orientations',
      (tester) async {
    await _pumpApp(tester, user: _testUser);

    // Verify presence of vertical video badge ("Reel") on feed
    expect(find.text('Reel'), findsWidgets);

    // Scroll down until the vertical portrait photo badge is visible
    await tester.scrollUntilVisible(
      find.text('Portrait'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Portrait'), findsOneWidget);

    // Open post creation dialog and verify orientation toggle
    await tester.tap(find.text('Post place'));
    await tester.pumpAndSettle();

    expect(find.text('Vertical'), findsOneWidget);

    // Tap orientation toggle to switch to landscape
    await tester.tap(find.text('Vertical'));
    await tester.pumpAndSettle();

    expect(find.text('Landscape'), findsOneWidget);

    // Tap back to vertical
    await tester.tap(find.text('Landscape'));
    await tester.pumpAndSettle();

    expect(find.text('Vertical'), findsOneWidget);
  });

  testWidgets(
      'profile displays user post history, supports editing, and deleting',
      (tester) async {
    await _pumpApp(tester, user: _testUser);

    // Switch to Profile tab
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify user profile header, stats, and 'MY STORIES' post history
    expect(find.text('Sokha Chan'), findsOneWidget);
    expect(find.text('MY STORIES'), findsOneWidget);
    expect(find.textContaining('Sunrise over the Royal Palace'), findsOneWidget);

    // Tap Edit button on the post card
    await tester.tap(find.byTooltip('Edit story'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Place Story'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Enter updated caption
    await tester.enterText(
      find.byType(TextField).first,
      'Updated golden morning at the Royal Palace!',
    );
    await tester.pumpAndSettle();

    // Tap Save changes
    await tester.tap(find.text('Save changes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify the post history displays the updated text
    expect(
      find.textContaining('Updated golden morning at the Royal Palace!'),
      findsOneWidget,
    );

    // Tap Delete button on the post card
    await tester.tap(find.byTooltip('Delete story'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this post?'), findsOneWidget);

    // Confirm deletion
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify post is removed and empty state is shown
    expect(
      find.textContaining('Updated golden morning at the Royal Palace!'),
      findsNothing,
    );
    expect(find.text('No stories shared yet'), findsOneWidget);
  });

  testWidgets('profile allows user to change profile photo', (tester) async {
    await _pumpApp(tester, user: _testUser);

    // Switch to Profile tab
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload photo'), findsOneWidget);

    // Tap Upload photo button to open photo options sheet
    await tester.tap(find.text('Upload photo'));
    await tester.pumpAndSettle();

    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Choose sample avatar'), findsOneWidget);
    expect(find.text('Web image URL'), findsOneWidget);

    // Tap Web image URL option
    await tester.tap(find.text('Web image URL'));
    await tester.pumpAndSettle();

    expect(find.text('Image URL'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'https://picsum.photos/seed/traveler-visut/400/400',
    );
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Profile photo updated!'), findsOneWidget);
    expect(find.text('Edit photo'), findsOneWidget);
  });

  testWidgets('searching a place shows suggestions and a route sheet',
      (tester) async {
    await _pumpApp(tester, user: _testUser);
    await _openExplore(tester);

    await tester.enterText(find.byType(TextField).first, 'Wat');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Wat Phnom'), findsOneWidget);

    await tester.tap(find.text('Wat Phnom'));
    await tester.pumpAndSettle();

    expect(find.text('Start navigation'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('nearby categories list places around the map', (tester) async {
    await _pumpApp(tester, user: _testUser);
    await _openExplore(tester);

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby restaurants'), findsOneWidget);
    expect(find.text('Malis Restaurant'), findsOneWidget);
  });

  test('demo search matches names and categories', () {
    expect(DemoData.search('wat').first.name, 'Wat Phnom');
    expect(DemoData.search('museum').isNotEmpty, isTrue);
    expect(DemoData.search('a').isEmpty, isTrue);
    expect(DemoData.search('zzzz').isEmpty, isTrue);
  });

  test('demo nearby filters by category and sorts by distance', () {
    const center = GeoPoint(11.5564, 104.9282);
    final restaurants = DemoData.nearby(
      center: center,
      category: NearbyCategory.restaurant,
    );

    expect(restaurants, isNotEmpty);
    expect(
      restaurants.every((place) => place.category == 'restaurant'),
      isTrue,
    );
    expect(restaurants.map((place) => place.name), contains('Malis Restaurant'));

    final distances = restaurants
        .map((place) => place.location.distanceTo(center))
        .toList();
    for (var index = 1; index < distances.length; index++) {
      expect(distances[index], greaterThanOrEqualTo(distances[index - 1]));
    }
  });

  test('demo feed ranks posts by trending score', () {
    final posts = DemoData.trendingPosts();

    expect(posts, isNotEmpty);
    expect(posts.first.place.name, 'Royal Palace');
    expect(posts.any((post) => post.isVideo), isTrue);
    for (var index = 1; index < posts.length; index++) {
      expect(
        posts[index].trendingScore,
        lessThanOrEqualTo(posts[index - 1].trendingScore),
      );
    }
  });

  test('demo mode pins location to Phnom Penh', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(demoMode: true),
        ),
        locationServiceProvider.overrideWithValue(
          _MountainViewLocationService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final point = await container.read(exploreProvider.notifier).locate();

    expect(point, AppConfig.defaultLocation);
    expect(container.read(exploreProvider).me, AppConfig.defaultLocation);
  });

  test('polyline decoding restores coordinates', () {
    // "???" style encoded polyline for (11.5564, 104.9282).
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, isNotEmpty);
    expect(points.first.lat, closeTo(38.5, 0.5));
  });

  test('formatters produce readable labels', () {
    expect(formatDistance(850), '850 m');
    expect(formatDistance(2400), '2.4 km');
    expect(formatDuration(45), '<1 min');
    expect(formatDuration(720), '12 min');
    expect(formatDuration(3900), '1 h 05 min');
    expect(parseDistanceMeters('1.2 km'), 1200);
    expect(parseDurationSeconds('25 min'), 1500);
    expect(formatCompactCount(980), '980');
    expect(formatCompactCount(1240), '1.2K');
    expect(formatCompactCount(18000), '18K');
    expect(
      formatRelativeTime(
        DateTime(2026, 10, 31, 10),
        now: DateTime(2026, 10, 31, 10, 5),
      ),
      '5 min ago',
    );
  });
}
