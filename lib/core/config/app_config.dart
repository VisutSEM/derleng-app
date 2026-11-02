import '../../models/geo_point.dart';

/// Compile-time configuration.
///
/// Override with:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com/api
///   --dart-define=DEMO_MODE=false --dart-define=GOOGLE_MAPS_API_KEY=...`
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  /// Sample data is disabled. Always loads live data from API.
  static const bool demoMode = false;

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDiAL02T6B22dItH6Jndj0mqH_4zaup0bs',
  );

  static const String appVersion = '1.0.0';

  /// Phnom Penh — used when location services are unavailable.
  static const GeoPoint defaultLocation = GeoPoint(11.5564, 104.9282);

  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration demoLatency = Duration(milliseconds: 450);

  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;
}
