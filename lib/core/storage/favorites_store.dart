import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/place.dart';

class FavoritesStore {
  FavoritesStore(this._prefs);

  static const _key = 'derleng.favorites.v1';
  final SharedPreferences _prefs;

  List<Place> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Place.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore corrupted cache.
    }
    return const [];
  }

  Future<void> write(List<Place> places) => _prefs.setString(
        _key,
        jsonEncode(places.map((place) => place.toJson()).toList()),
      );
}
