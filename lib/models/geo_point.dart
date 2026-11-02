import 'dart:math' as math;

/// A latitude/longitude pair used across the app.
///
/// Kept independent from the maps plugin so the data layer stays testable.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] ?? json['latitude'];
    final lng = json['lng'] ?? json['longitude'] ?? json['lon'];
    if (lat is! num || lng is! num) {
      throw const FormatException('Invalid coordinate payload');
    }
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  /// Format expected by the Laravel proxy (`origin` / `destination`).
  String get apiValue => '$lat,$lng';

  /// Great-circle distance in meters.
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _radians(other.lat - lat);
    final dLng = _radians(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
