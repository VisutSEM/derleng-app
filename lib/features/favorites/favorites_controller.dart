import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/place.dart';

class FavoritesController extends Notifier<List<Place>> {
  @override
  List<Place> build() {
    final repository = ref.watch(favoritesRepositoryProvider);
    final initial = repository.cached();
    Future<void>.microtask(_refresh);
    return initial;
  }

  bool isFavorite(String placeId) =>
      state.any((place) => place.id == placeId);

  Future<void> add(Place place) async {
    await ref.read(favoritesRepositoryProvider).add(place);
    if (!ref.mounted) return;
    state = ref.read(favoritesRepositoryProvider).cached();
  }

  Future<void> remove(String placeId) async {
    await ref.read(favoritesRepositoryProvider).remove(placeId);
    if (!ref.mounted) return;
    state = ref.read(favoritesRepositoryProvider).cached();
  }

  Future<void> toggle(Place place) {
    return isFavorite(place.id) ? remove(place.id) : add(place);
  }

  Future<void> _refresh() async {
    final repository = ref.read(favoritesRepositoryProvider);
    final fresh = await repository.fetch();
    if (!ref.mounted) return;
    if (!listEquals(fresh, state)) state = fresh;
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, List<Place>>(FavoritesController.new);
