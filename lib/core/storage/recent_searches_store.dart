import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/place.dart';

class RecentSearchesStore {
  RecentSearchesStore(this._prefs);

  static const _key = 'derleng.recent.v1';
  static const _limit = 6;

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
      // Ignore corrupted history.
    }
    return const [];
  }

  Future<List<Place>> add(Place place) async {
    final updated = <Place>[
      place,
      ...read().where((item) => item.id != place.id),
    ].take(_limit).toList(growable: false);
    await _write(updated);
    return updated;
  }

  Future<void> clear() => _prefs.remove(_key);

  Future<void> _write(List<Place> places) => _prefs.setString(
        _key,
        jsonEncode(places.map((place) => place.toJson()).toList()),
      );
}
