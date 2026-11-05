import 'package:flutter/foundation.dart';

import '../../models/geo_point.dart';

/// Compile-time configuration.
///
/// Override with:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com/api
///   --dart-define=DEMO_MODE=false --dart-define=GOOGLE_MAPS_API_KEY=...`
///
/// Or with:
/// `flutter run --dart-define-from-file=env.json`
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.8.179:8000/api',
  );

  /// Sample data is disabled. Always loads live data from API.
  static const bool demoMode = false;

  /// Google Maps API key passed via compile-time environment variable.
  /// Keep default empty so secrets are never committed to version control.
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String appVersion = '1.0.0';

  /// Phnom Penh — used when location services are unavailable.
  static const GeoPoint defaultLocation = GeoPoint(11.5564, 104.9282);

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration demoLatency = Duration(milliseconds: 450);

  /// True when a key was passed directly, or when running on mobile where native
  /// configuration (such as android/local.properties) supplies the key.
  static bool get hasGoogleMapsKey =>
      googleMapsApiKey.isNotEmpty ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));
}
