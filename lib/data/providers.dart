import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bootstrap.dart';
import '../core/network/api_client.dart';
import '../core/storage/favorites_store.dart';
import '../core/storage/recent_searches_store.dart';
import '../core/storage/session_store.dart';
import '../features/settings/settings_controller.dart';
import 'repositories/auth_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/feed_repository.dart';
import 'repositories/places_repository.dart';
import 'services/location_service.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(sharedPreferencesProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final sessionStore = ref.watch(sessionStoreProvider);
  return ApiClient(
    baseUrl: settings.apiBaseUrl,
    tokenProvider: () => sessionStore.read()?.token,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final sessionStore = ref.watch(sessionStoreProvider);
  final client = ref.watch(apiClientProvider);
  return ApiAuthRepository(client, sessionStore);
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return ApiPlacesRepository(ref.watch(apiClientProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return ApiFeedRepository(ref.watch(apiClientProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(
    store: FavoritesStore(ref.watch(sharedPreferencesProvider)),
    client: ref.watch(apiClientProvider),
    demoMode: false,
  );
});

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(ref.watch(sharedPreferencesProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
