import 'dart:math' as math;

import '../../core/utils/formatters.dart';
import '../../models/geo_point.dart';
import '../../models/nearby_category.dart';
import '../../models/place.dart';
import '../../models/place_post.dart';
import '../../models/route_info.dart';
import '../../models/travel_mode.dart';

/// Sample destinations used while the Laravel API is not connected.
class DemoData {
  const DemoData._();

  static final List<Place> _customPlaces = [];

  /// All places available in the app, combining custom user-added places with demo presets.
  static List<Place> get allPlaces => [..._customPlaces, ...places];

  /// Adds a custom user-tagged place so it can be re-used and searched.
  static void addPlace(Place place) {
    if (!_customPlaces.any((p) =>
        p.id == place.id ||
        p.name.trim().toLowerCase() == place.name.trim().toLowerCase())) {
      _customPlaces.insert(0, place);
    }
  }

  /// Clears custom places.
  static void resetCustomPlaces() {
    _customPlaces.clear();
  }

  static const List<Place> places = [
    Place(
      id: 'royal-palace',
      name: 'Royal Palace',
      address: 'Samdach Sothearos Blvd, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5639, 104.9308),
      category: 'landmark',
      rating: 4.6,
      ratingCount: 18432,
    ),
    Place(
      id: 'wat-phnom',
      name: 'Wat Phnom',
      address: 'Street 96, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5762, 104.9232),
      category: 'temple',
      rating: 4.4,
      ratingCount: 9210,
    ),
    Place(
      id: 'tuol-sleng',
      name: 'Tuol Sleng Genocide Museum',
      address: 'St. 113, Boeung Keng Kang, Phnom Penh',
      location: GeoPoint(11.5494, 104.9177),
      category: 'museum',
      rating: 4.5,
      ratingCount: 14260,
    ),
    Place(
      id: 'central-market',
      name: 'Central Market',
      address: 'Street 130, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5696, 104.9210),
      category: 'market',
      rating: 4.2,
      ratingCount: 7310,
    ),
    Place(
      id: 'russian-market',
      name: 'Russian Market',
      address: 'Street 163, Toul Tom Poung, Phnom Penh',
      location: GeoPoint(11.5417, 104.9239),
      category: 'market',
      rating: 4.3,
      ratingCount: 6840,
    ),
    Place(
      id: 'aeon-mall',
      name: 'AEON Mall Phnom Penh',
      address: 'Samdach Sothearos Blvd, Chamkarmon, Phnom Penh',
      location: GeoPoint(11.5466, 104.9356),
      category: 'mall',
      rating: 4.4,
      ratingCount: 21540,
    ),
    Place(
      id: 'independence-monument',
      name: 'Independence Monument',
      address: 'Norodom Blvd, Boeung Keng Kang, Phnom Penh',
      location: GeoPoint(11.5564, 104.9282),
      category: 'landmark',
      rating: 4.5,
      ratingCount: 11290,
    ),
    Place(
      id: 'sisowath-quay',
      name: 'Sisowath Quay Riverside',
      address: 'Sisowath Quay, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5680, 104.9320),
      category: 'landmark',
      rating: 4.6,
      ratingCount: 8720,
    ),
    Place(
      id: 'national-museum',
      name: 'National Museum of Cambodia',
      address: 'Street 13, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5656, 104.9280),
      category: 'museum',
      rating: 4.5,
      ratingCount: 7410,
    ),
    Place(
      id: 'olympic-stadium',
      name: 'Olympic Stadium',
      address: 'Sihanouk Blvd, Chamkarmon, Phnom Penh',
      location: GeoPoint(11.5586, 104.9119),
      category: 'stadium',
      rating: 4.3,
      ratingCount: 4210,
    ),
    Place(
      id: 'koh-pich',
      name: 'Koh Pich (Diamond Island)',
      address: 'Koh Pich, Chamkarmon, Phnom Penh',
      location: GeoPoint(11.5475, 104.9430),
      category: 'landmark',
      rating: 4.4,
      ratingCount: 5390,
    ),
    Place(
      id: 'phnom-penh-airport',
      name: 'Phnom Penh International Airport',
      address: 'Pochentong, Phnom Penh',
      location: GeoPoint(11.5466, 104.8441),
      category: 'airport',
      rating: 4.0,
      ratingCount: 12740,
    ),
    Place(
      id: 'brown-coffee',
      name: 'Brown Coffee & Bakery',
      address: 'Street 57, Boeung Keng Kang 1, Phnom Penh',
      location: GeoPoint(11.5581, 104.9226),
      category: 'cafe',
      rating: 4.5,
      ratingCount: 3120,
    ),
    Place(
      id: 'malis-restaurant',
      name: 'Malis Restaurant',
      address: 'Norodom Blvd, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5563, 104.9218),
      category: 'restaurant',
      rating: 4.7,
      ratingCount: 4680,
    ),
    Place(
      id: 'raffles-le-royal',
      name: 'Raffles Hotel Le Royal',
      address: 'Street 92, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5669, 104.9207),
      category: 'hotel',
      rating: 4.8,
      ratingCount: 3920,
    ),
    Place(
      id: 'wat-botum-park',
      name: 'Wat Botum Park',
      address: 'Sothearos Blvd, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5605, 104.9285),
      category: 'park',
      rating: 4.4,
      ratingCount: 2610,
    ),
    Place(
      id: 'night-market',
      name: 'Phnom Penh Night Market',
      address: 'Preah Sisowath Quay, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5717, 104.9306),
      category: 'market',
      rating: 4.1,
      ratingCount: 5140,
    ),
    Place(
      id: 'friends-restaurant',
      name: 'Friends the Restaurant',
      address: 'Street 13, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5658, 104.9316),
      category: 'restaurant',
      rating: 4.6,
      ratingCount: 2740,
    ),
    Place(
      id: 'mok-mony',
      name: 'Mok Mony',
      address: 'Street 294, Boeung Keng Kang 1, Phnom Penh',
      location: GeoPoint(11.5569, 104.9170),
      category: 'restaurant',
      rating: 4.5,
      ratingCount: 1980,
    ),
    Place(
      id: 'the-shop',
      name: 'The Shop',
      address: 'Street 240, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5587, 104.9251),
      category: 'cafe',
      rating: 4.4,
      ratingCount: 1560,
    ),
    Place(
      id: 'cafe-kampuchea',
      name: 'Cafe Kampuchea',
      address: 'Street 13, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5684, 104.9301),
      category: 'cafe',
      rating: 4.3,
      ratingCount: 1120,
    ),
    Place(
      id: 'palace-gate-hotel',
      name: 'Palace Gate Hotel & Resort',
      address: 'Street 92, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5621, 104.9285),
      category: 'hotel',
      rating: 4.6,
      ratingCount: 2870,
    ),
    Place(
      id: 'himawari-hotel',
      name: 'Himawari Hotel Apartments',
      address: 'Sisowath Quay, Daun Penh, Phnom Penh',
      location: GeoPoint(11.5516, 104.9284),
      category: 'hotel',
      rating: 4.4,
      ratingCount: 1930,
    ),
  ];

  /// Default community posts powering the Home feed.
  static final List<PlacePost> _defaultPosts = [
    PlacePost(
      id: 'post-royal-palace-sunrise',
      authorName: 'Sokha Chan',
      caption:
          'Sunrise over the Royal Palace — the quietest hour in the whole city.',
      place: _place('royal-palace'),
      imageUrl: 'https://picsum.photos/seed/derleng-palace/900/600',
      aspectRatio: 16 / 10,
      likes: 2840,
      comments: 128,
      saves: 412,
      trendingScore: 98,
      createdAt: DateTime.utc(2026, 10, 31, 5, 40),
    ),
    PlacePost(
      id: 'post-wat-phnom-evening',
      authorName: 'Dara Kim',
      caption:
          'Golden hour at Wat Phnom. Watch the bats leave the tower at dusk 🦇',
      place: _place('wat-phnom'),
      imageUrl: 'https://picsum.photos/seed/derleng-wat-phnom/900/600',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      aspectRatio: 9 / 16,
      likes: 1980,
      comments: 96,
      saves: 305,
      trendingScore: 92,
      createdAt: DateTime.utc(2026, 10, 30, 17, 20),
    ),
    PlacePost(
      id: 'post-night-market-food',
      authorName: 'Bopha Ly',
      caption:
          'Street food crawl at the Night Market. Start with the grilled squid, thank me later.',
      place: _place('night-market'),
      imageUrl: 'https://picsum.photos/seed/derleng-night-market/900/600',
      aspectRatio: 4 / 5,
      likes: 1520,
      comments: 74,
      saves: 268,
      trendingScore: 88,
      createdAt: DateTime.utc(2026, 10, 30, 20, 5),
    ),
    PlacePost(
      id: 'post-sisowath-sunset',
      authorName: 'Rithy Meas',
      caption:
          'Sisowath Quay at sunset, with the Mekong turning pink. Take a slow walk.',
      place: _place('sisowath-quay'),
      imageUrl: 'https://picsum.photos/seed/derleng-sisowath/900/600',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      aspectRatio: 16 / 9,
      likes: 1310,
      comments: 58,
      saves: 214,
      trendingScore: 86,
      createdAt: DateTime.utc(2026, 10, 29, 18, 15),
    ),
    PlacePost(
      id: 'post-the-shop-brunch',
      authorName: 'Maly Sok',
      caption:
          'Slow Saturday brunch at The Shop. The passion fruit tart is a must.',
      place: _place('the-shop'),
      imageUrl: 'https://picsum.photos/seed/derleng-the-shop/900/600',
      aspectRatio: 16 / 10,
      likes: 940,
      comments: 41,
      saves: 176,
      trendingScore: 81,
      createdAt: DateTime.utc(2026, 10, 29, 10, 30),
    ),
    PlacePost(
      id: 'post-palace-gate-rooftop',
      authorName: 'Vannak Chum',
      caption:
          'Rooftop views from Palace Gate. Best spot for a night-time skyline photo.',
      place: _place('palace-gate-hotel'),
      imageUrl: 'https://picsum.photos/seed/derleng-palace-gate/900/600',
      aspectRatio: 4 / 5,
      likes: 780,
      comments: 33,
      saves: 148,
      trendingScore: 77,
      createdAt: DateTime.utc(2026, 10, 28, 21, 10),
    ),
    PlacePost(
      id: 'post-wat-botum-run',
      authorName: 'Chanthy Nou',
      caption:
          'Morning run loop around Wat Botum Park. Shade, fresh air, and coffee after.',
      place: _place('wat-botum-park'),
      imageUrl: 'https://picsum.photos/seed/derleng-wat-botum/900/600',
      aspectRatio: 16 / 10,
      likes: 610,
      comments: 27,
      saves: 119,
      trendingScore: 74,
      createdAt: DateTime.utc(2026, 10, 28, 6, 45),
    ),
  ];

  /// Community posts powering the Home feed while the API is offline.
  static List<PlacePost> posts = List.of(_defaultPosts);

  /// Restores default demo posts for testing or resetting session.
  static void resetPosts() {
    posts = List.of(_defaultPosts);
  }

  /// Most viral posts first.
  static List<PlacePost> trendingPosts({int limit = 20}) {
    final sorted = [...posts]
      ..sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return sorted.take(limit).toList(growable: false);
  }

  static Place _place(String id) => places.firstWhere(
        (place) => place.id == id,
        orElse: () => places.first,
      );

  static List<Place> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    final terms = normalized.split(RegExp(r'\s+'));
    return allPlaces.where((place) {
      final haystack =
          '${place.name} ${place.address} ${place.category ?? ''}'.toLowerCase();
      return terms.every(haystack.contains);
    }).toList(growable: false);
  }

  /// Places matching [category], closest to [center] first.
  ///
  /// When nothing is inside [radiusMeters] the nearest matches are still
  /// returned, so the demo never shows an empty discovery list.
  static List<Place> nearby({
    required GeoPoint center,
    required NearbyCategory category,
    double radiusMeters = 4000,
  }) {
    final matches = places
        .where((place) => category.demoCategories.contains(place.category))
        .toList(growable: false)
      ..sort(
        (a, b) => a.location
            .distanceTo(center)
            .compareTo(b.location.distanceTo(center)),
      );

    final withinRadius = matches
        .where((place) => place.location.distanceTo(center) <= radiusMeters)
        .toList(growable: false);
    return withinRadius.isNotEmpty ? withinRadius : matches.take(6).toList();
  }

  static RouteInfo route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) {
    final straight = origin.distanceTo(destination);
    final detour = switch (mode) {
      TravelMode.driving => 1.34,
      TravelMode.walking => 1.16,
      TravelMode.transit => 1.42,
      TravelMode.bicycling => 1.22,
    };
    final speed = switch (mode) {
      TravelMode.driving => 9.0,
      TravelMode.walking => 1.35,
      TravelMode.transit => 6.0,
      TravelMode.bicycling => 4.0,
    };
    final meters = math.max(120, (straight * detour).round());
    final seconds = math.max(60, (meters / speed).round());

    return RouteInfo(
      points: _curvedRoute(origin, destination),
      distanceLabel: formatDistance(meters),
      durationLabel: formatDuration(seconds),
      distanceMeters: meters,
      durationSeconds: seconds,
      mode: mode,
    );
  }

  /// Produces a smooth, slightly curved line so the demo route does not look
  /// like a ruler. Mirrors the shape of the polyline returned by the API.
  static List<GeoPoint> _curvedRoute(GeoPoint a, GeoPoint b) {
    const steps = 56;
    final dLat = b.lat - a.lat;
    final dLng = b.lng - a.lng;
    final length = math.sqrt(dLat * dLat + dLng * dLng);
    if (length == 0) return [a, b];

    final bend = math.min(0.22, length * 0.16);
    final perpLat = -dLng / length * bend;
    final perpLng = dLat / length * bend;

    return List<GeoPoint>.generate(steps + 1, (index) {
      final t = index / steps;
      final wave = math.sin(math.pi * t);
      final ripple = math.sin(math.pi * 3 * t) * 0.12;
      final offset = (wave + ripple) * (index == 0 || index == steps ? 0 : 1);
      return GeoPoint(
        a.lat + dLat * t + perpLat * offset,
        a.lng + dLng * t + perpLng * offset,
      );
    });
  }
}
