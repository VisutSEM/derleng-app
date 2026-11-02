import 'geo_point.dart';
import 'route_step.dart';
import 'travel_mode.dart';

export 'route_step.dart';

/// Normalized route payload from `GET /directions`.
class RouteInfo {
  const RouteInfo({
    required this.points,
    required this.distanceLabel,
    required this.durationLabel,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.mode,
    this.steps = const [],
  });

  final List<GeoPoint> points;
  final String distanceLabel;
  final String durationLabel;
  final int distanceMeters;
  final int durationSeconds;
  final TravelMode mode;
  final List<RouteStep> steps;

  bool get hasPoints => points.length > 1;
}

