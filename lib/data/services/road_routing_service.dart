import 'dart:convert';
import 'package:dio/dio.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/polyline.dart';
import '../../models/geo_point.dart';
import '../../models/route_info.dart';
import '../../models/travel_mode.dart';

/// Direct road routing service that calculates real road-following paths
/// (turn-by-turn geometry) across streets, intersections, and avenues.
class RoadRoutingService {
  const RoadRoutingService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'DerlengApp/1.0',
      },
    ),
  );

  /// Calculates a route following the real road network between [origin] and [destination].
  static Future<RouteInfo?> calculateRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async {
    final profile = switch (mode) {
      TravelMode.walking => 'foot',
      TravelMode.bicycling => 'bike',
      _ => 'driving',
    };

    final url =
        'https://router.project-osrm.org/route/v1/$profile/'
        '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
        '?overview=full&geometries=polyline&steps=true';

    try {
      final response = await _dio.get<dynamic>(url);
      final dynamic raw = response.data;
      final Map<String, dynamic> data;
      if (raw is String) {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      } else {
        return null;
      }

      if (data['code'] == 'Ok') {
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = Map<String, dynamic>.from(routes.first as Map);
          final polyline = firstRoute['geometry'] as String?;
          if (polyline != null && polyline.trim().isNotEmpty) {
            final points = decodePolyline(polyline.trim());
            if (points.length > 2) {
              final distanceMeters =
                  (firstRoute['distance'] as num?)?.round() ?? 0;
              final durationSeconds =
                  (firstRoute['duration'] as num?)?.round() ?? 0;

              final steps = _parseSteps(firstRoute, origin, destination);

              return RouteInfo(
                points: points,
                distanceLabel: formatDistance(distanceMeters),
                durationLabel: formatDuration(durationSeconds),
                distanceMeters: distanceMeters,
                durationSeconds: durationSeconds,
                mode: mode,
                steps: steps.isNotEmpty
                    ? steps
                    : generateFallbackSteps(points, destination),
              );
            }
          }
        }
      }
    } catch (_) {
      // Returns null on network error so caller can use fallback
    }

    return null;
  }

  static List<RouteStep> _parseSteps(
    Map<String, dynamic> firstRoute,
    GeoPoint origin,
    GeoPoint destination,
  ) {
    final steps = <RouteStep>[];
    final legs = firstRoute['legs'] as List?;
    if (legs == null || legs.isEmpty) return steps;

    for (final leg in legs) {
      if (leg is! Map) continue;
      final legMap = Map<String, dynamic>.from(leg);
      final rawSteps = legMap['steps'] as List?;
      if (rawSteps == null) continue;

      for (final raw in rawSteps) {
        if (raw is! Map) continue;
        final step = Map<String, dynamic>.from(raw);
        final dist = (step['distance'] as num?)?.round() ?? 0;
        final dur = (step['duration'] as num?)?.round() ?? 0;
        final name = (step['name'] as String?)?.trim() ?? '';
        final maneuver = step['maneuver'] is Map
            ? Map<String, dynamic>.from(step['maneuver'] as Map)
            : const <String, dynamic>{};

        final type = (maneuver['type'] as String?)?.trim().toLowerCase() ?? 'turn';
        final modifier = (maneuver['modifier'] as String?)?.trim().toLowerCase();
        final loc = maneuver['location'] as List?;
        final stepPoint = (loc != null && loc.length >= 2)
            ? GeoPoint((loc[1] as num).toDouble(), (loc[0] as num).toDouble())
            : destination;

        final instruction = _buildStepInstruction(type, modifier, name);
        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMeters: dist,
            durationSeconds: dur,
            location: stepPoint,
            streetName: name.isNotEmpty ? name : null,
            maneuverType: type,
            modifier: modifier,
          ),
        );
      }
    }
    return steps;
  }

  static String _buildStepInstruction(String type, String? modifier, String name) {
    final modText = modifier != null ? modifier.replaceAll('_', ' ') : '';
    final street = name.isNotEmpty ? 'onto $name' : '';

    if (type.contains('depart')) {
      return name.isNotEmpty ? 'Head out on $name' : 'Head toward destination';
    }
    if (type.contains('arrive')) {
      return name.isNotEmpty ? 'Arrive at $name' : 'Arrive at destination';
    }
    if (type.contains('roundabout') || type.contains('rotary')) {
      return street.isNotEmpty
          ? 'At roundabout, take exit $street'
          : 'Enter roundabout and take exit';
    }
    if (type.contains('uturn') || modText.contains('uturn')) {
      return 'Make a U-turn ${street.isNotEmpty ? street : ""}'.trim();
    }
    if (type.contains('new name') || type.contains('continue')) {
      return street.isNotEmpty ? 'Continue $street' : 'Continue straight';
    }
    if (modText.isNotEmpty) {
      final formattedMod = modText[0].toUpperCase() + modText.substring(1);
      return street.isNotEmpty ? '$formattedMod $street' : formattedMod;
    }
    return street.isNotEmpty ? 'Turn $street' : 'Continue on route';
  }

  /// Generates meaningful guidance steps for polyline routes when OSRM steps are missing.
  static List<RouteStep> generateFallbackSteps(
    List<GeoPoint> points,
    GeoPoint destination,
  ) {
    if (points.isEmpty) return const [];
    if (points.length <= 2) {
      return [
        RouteStep(
          instruction: 'Head toward destination',
          distanceMeters: (points.first.distanceTo(destination)).round(),
          durationSeconds: 60,
          location: points.first,
          maneuverType: 'depart',
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          distanceMeters: 0,
          durationSeconds: 0,
          location: destination,
          maneuverType: 'arrive',
        ),
      ];
    }

    final steps = <RouteStep>[];
    steps.add(
      RouteStep(
        instruction: 'Head toward destination',
        distanceMeters: (points.first.distanceTo(points[1])).round(),
        durationSeconds: 60,
        location: points.first,
        maneuverType: 'depart',
      ),
    );

    final midIndex = points.length ~/ 2;
    steps.add(
      RouteStep(
        instruction: 'Continue along route',
        distanceMeters: (points.first.distanceTo(points[midIndex])).round(),
        durationSeconds: 180,
        location: points[midIndex],
        maneuverType: 'continue',
      ),
    );

    steps.add(
      RouteStep(
        instruction: 'Arrive at destination',
        distanceMeters: 0,
        durationSeconds: 0,
        location: destination,
        maneuverType: 'arrive',
      ),
    );

    return steps;
  }
}
