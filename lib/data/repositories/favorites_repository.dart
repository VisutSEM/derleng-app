import '../../core/network/api_client.dart';
import '../../core/storage/favorites_store.dart';
import '../../models/place.dart';

/// Local-first favorites with best-effort sync to the Laravel API.
///
/// In demo mode nothing leaves the device. In live mode the local cache is the
/// source of truth for the UI so saving still works offline.
class FavoritesRepository {
  FavoritesRepository({
    required this.store,
    required this.client,
    required this.demoMode,
  });

  final FavoritesStore store;
  final ApiClient client;
  final bool demoMode;

  List<Place> cached() => store.read();

  Future<List<Place>> fetch() async {
    if (demoMode) return cached();
    try {
      final data = await client.get('/favorites');
      final raw = data is Map ? data['data'] : data;
      if (raw is! List) return cached();
      final places = <Place>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          places.add(Place.fromJson(Map<String, dynamic>.from(item)));
        } on Object {
          // ignore malformed entry
        }
      }
      await store.write(places);
      return places;
    } on Object {
      return cached();
    }
  }

  Future<void> add(Place place) async {
    final current = cached();
    if (current.any((item) => item.id == place.id)) return;
    await store.write([place, ...current]);
    if (demoMode) return;
    try {
      await client.post('/favorites', data: place.toJson());
    } on Object {
      // Kept locally; will retry on the next full sync.
    }
  }

  Future<void> remove(String placeId) async {
    final updated = cached().where((item) => item.id != placeId).toList();
    await store.write(updated);
    if (demoMode) return;
    try {
      await client.delete('/favorites/$placeId');
    } on Object {
      // Kept locally removed; the API will reconcile on the next sync.
    }
  }
}
