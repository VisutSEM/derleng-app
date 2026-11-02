import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/polyline.dart';
import '../../models/geo_point.dart';
import '../../models/nearby_category.dart';
import '../../models/place.dart';
import '../../models/route_info.dart';
import '../../models/travel_mode.dart';
import '../demo/demo_data.dart';
import '../services/road_routing_service.dart';

abstract class PlacesRepository {
  Future<List<Place>> search(String query);

  Future<List<Place>> nearby({
    required GeoPoint center,
    required NearbyCategory category,
    double radiusMeters = 4000,
  });

  Future<RouteInfo> directions({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  });
}

/// Talks to the Laravel proxy described in `derleng_tasks.md`:
/// `GET /places/search?q=...`, `GET /places/nearby?lat=..&lng=..&category=..`
/// and `GET /directions?origin=..&destination=..&mode=..`.
class ApiPlacesRepository implements PlacesRepository {
  ApiPlacesRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Place>> search(String query) async {
    final data = await _client.get('/places/search', query: {'q': query});
    return _parsePlaces(data);
  }

  @override
  Future<List<Place>> nearby({
    required GeoPoint center,
    required NearbyCategory category,
    double radiusMeters = 4000,
  }) async {
    final data = await _client.get('/places/nearby', query: {
      'lat': center.lat,
      'lng': center.lng,
      'category': category.apiValue,
      'radius': radiusMeters.round(),
    });
    return _parsePlaces(data);
  }

  static List<Place> _parsePlaces(dynamic data) {
    final raw = data is Map ? data['data'] : data;
    if (raw is! List) return const [];

    final places = <Place>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        places.add(Place.fromJson(Map<String, dynamic>.from(item)));
      } on Object {
        // Skip malformed entries instead of failing the whole request.
      }
    }
    return places;
  }

  @override
  Future<RouteInfo> directions({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async {
    // 1. Try backend directions endpoint first
    try {
      final data = await _client.get('/directions', query: {
        'origin': origin.apiValue,
        'destination': destination.apiValue,
        'mode': mode.apiValue,
      });
      final map = data is Map
          ? (data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : Map<String, dynamic>.from(data))
          : <String, dynamic>{};

      final points = _decodePoints(map, origin, destination);
      final distanceMeters = (map['distance_meters'] as num?)?.toInt() ??
          parseDistanceMeters(map['distance']?.toString());
      final durationSeconds = (map['duration_seconds'] as num?)?.toInt() ??
          parseDurationSeconds(map['duration']?.toString());

      // If backend returned real road geometry following the way, use it!
      if (points.length > 2) {
        return RouteInfo(
          points: points,
          distanceLabel:
              map['distance']?.toString() ?? formatDistance(distanceMeters),
          durationLabel:
              map['duration']?.toString() ?? formatDuration(durationSeconds),
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          mode: TravelMode.fromApi(map['mode'] ?? mode.apiValue),
          steps: RoadRoutingService.generateFallbackSteps(points, destination),
        );
      }
    } catch (_) {
      // Backend error or timeout; seamlessly fall back to RoadRoutingService
    }

    // 2. Calculate route following the real road network (turn-by-turn)
    final roadRoute = await RoadRoutingService.calculateRoute(
      origin: origin,
      destination: destination,
      mode: mode,
    );
    if (roadRoute != null && roadRoute.points.length > 2) {
      return roadRoute;
    }

    // 3. Last-resort fallback straight line
    final directDistance = origin.distanceTo(destination).round();
    final directDuration = (directDistance / 11.1).round();
    final fallbackPoints = [origin, destination];
    return RouteInfo(
      points: fallbackPoints,
      distanceLabel: formatDistance(directDistance),
      durationLabel: formatDuration(directDuration),
      distanceMeters: directDistance,
      durationSeconds: directDuration,
      mode: mode,
      steps: RoadRoutingService.generateFallbackSteps(
        fallbackPoints,
        destination,
      ),
    );
  }

  List<GeoPoint> _decodePoints(
    Map<String, dynamic> map,
    GeoPoint origin,
    GeoPoint destination,
  ) {
    final polyline = map['polyline'];
    if (polyline is String && polyline.trim().isNotEmpty) {
      final decoded = decodePolyline(polyline.trim());
      if (decoded.length > 1) return decoded;
    }

    final rawPoints = map['points'];
    if (rawPoints is List) {
      final points = <GeoPoint>[];
      for (final item in rawPoints) {
        if (item is Map) {
          try {
            points.add(GeoPoint.fromJson(Map<String, dynamic>.from(item)));
          } on Object {
            // ignore malformed point
          }
        } else if (item is List && item.length >= 2) {
          final lat = item[0];
          final lng = item[1];
          if (lat is num && lng is num) {
            points.add(GeoPoint(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      if (points.length > 1) return points;
    }

    // Never leave the map without a line: fall back to a straight segment.
    return [origin, destination];
  }
}

/// Serves realistic sample data while the backend is unavailable.
class DemoPlacesRepository implements PlacesRepository {
  DemoPlacesRepository({this.latency = AppConfig.demoLatency});

  final Duration latency;

  @override
  Future<List<Place>> search(String query) async {
    await Future<void>.delayed(latency);
    return DemoData.search(query);
  }

  @override
  Future<List<Place>> nearby({
    required GeoPoint center,
    required NearbyCategory category,
    double radiusMeters = 4000,
  }) async {
    await Future<void>.delayed(latency);
    return DemoData.nearby(
      center: center,
      category: category,
      radiusMeters: radiusMeters,
    );
  }

  @override
  Future<RouteInfo> directions({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async {
    await Future<void>.delayed(latency);
    if (origin == destination) {
      throw const ApiException('You are already at this destination.');
    }
    final roadRoute = await RoadRoutingService.calculateRoute(
      origin: origin,
      destination: destination,
      mode: mode,
    );
    if (roadRoute != null && roadRoute.points.length > 2) {
      return roadRoute;
    }
    return DemoData.route(
      origin: origin,
      destination: destination,
      mode: mode,
    );
  }
}
