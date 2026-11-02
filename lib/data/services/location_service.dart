import 'package:geolocator/geolocator.dart';

import '../../models/geo_point.dart';

class LocationService {
  /// Returns the device position, or `null` when location is unavailable.
  ///
  /// When [requestPermission] is false only an already-granted permission is
  /// used, which keeps the first app launch free of permission prompts.
  Future<GeoPoint?> current({
    bool requestPermission = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on Object {
      // Unsupported platform, denied permission or timeout — callers fall back.
      return null;
    }
  }
}
