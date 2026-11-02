import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/bootstrap.dart';
import 'package:frontend/data/services/road_routing_service.dart';
import 'package:frontend/features/explore/explore_controller.dart';
import 'package:frontend/models/geo_point.dart';
import 'package:frontend/models/place.dart';
import 'package:frontend/models/route_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('In-App Navigation Tests', () {
    test('RouteStep produces correct icons and formatters', () {
      const stepLeft = RouteStep(
        instruction: 'Turn left onto Street 240',
        distanceMeters: 450,
        durationSeconds: 120,
        location: GeoPoint(11.5564, 104.9282),
        maneuverType: 'turn',
        modifier: 'left',
      );
      expect(stepLeft.icon, Icons.turn_left_rounded);
      expect(stepLeft.distanceLabel, '450 m');

      const stepArrive = RouteStep(
        instruction: 'Arrive at Royal Palace',
        distanceMeters: 0,
        durationSeconds: 0,
        location: GeoPoint(11.5635, 104.9315),
        maneuverType: 'arrive',
      );
      expect(stepArrive.icon, Icons.flag_rounded);

      const stepRoundabout = RouteStep(
        instruction: 'Enter roundabout',
        distanceMeters: 200,
        durationSeconds: 60,
        location: GeoPoint(11.5500, 104.9200),
        maneuverType: 'roundabout',
      );
      expect(stepRoundabout.icon, Icons.roundabout_right_rounded);
    });

    test('generateFallbackSteps always produces departure and arrival steps', () {
      final points = [
        const GeoPoint(11.5500, 104.9200),
        const GeoPoint(11.5550, 104.9250),
        const GeoPoint(11.5600, 104.9300),
      ];
      final steps = RoadRoutingService.generateFallbackSteps(
        points,
        points.last,
      );

      expect(steps.length, greaterThanOrEqualTo(2));
      expect(steps.first.maneuverType, 'depart');
      expect(steps.last.maneuverType, 'arrive');
    });

    test('ExploreController starts and stops in-app navigation', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      const place = Place(
        id: 'palace_1',
        name: 'Royal Palace',
        category: 'Heritage',
        address: 'Samdach Sothearos Blvd',
        location: GeoPoint(11.5635, 104.9315),
      );

      final controller = container.read(exploreProvider.notifier);
      controller.selectPlace(place, fetchRoute: false);

      expect(container.read(exploreProvider).selected, place);
      expect(container.read(exploreProvider).isNavigating, false);

      // Start in-app navigation
      controller.startNavigation();
      expect(container.read(exploreProvider).isNavigating, true);
      expect(container.read(exploreProvider).currentStepIndex, 0);

      // Stop navigation
      controller.stopNavigation();
      expect(container.read(exploreProvider).isNavigating, false);
      expect(container.read(exploreProvider).currentStepIndex, 0);
    });
  });
}
