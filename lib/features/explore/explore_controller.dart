import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../data/providers.dart';
import '../../models/geo_point.dart';
import '../../models/nearby_category.dart';
import '../../models/place.dart';
import '../../models/route_info.dart';
import '../../models/travel_mode.dart';
import '../favorites/favorites_controller.dart';
import '../settings/settings_controller.dart';

class ExploreState {
  const ExploreState({
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.searchError,
    this.showResults = false,
    this.selected,
    this.route,
    this.routeLoading = false,
    this.routeError,
    this.mode = TravelMode.driving,
    this.me,
    this.recent = const [],
    this.locationFallback = false,
    this.nearbyCategory,
    this.nearby = const [],
    this.nearbyLoading = false,
    this.nearbyError,
    this.isNavigating = false,
    this.currentStepIndex = 0,
  });

  final String query;
  final List<Place> results;
  final bool searching;
  final String? searchError;
  final bool showResults;
  final Place? selected;
  final RouteInfo? route;
  final bool routeLoading;
  final String? routeError;
  final TravelMode mode;
  final GeoPoint? me;
  final List<Place> recent;
  final bool locationFallback;
  final NearbyCategory? nearbyCategory;
  final List<Place> nearby;
  final bool nearbyLoading;
  final String? nearbyError;
  final bool isNavigating;
  final int currentStepIndex;

  static const Object _unset = Object();

  ExploreState copyWith({
    String? query,
    List<Place>? results,
    bool? searching,
    Object? searchError = _unset,
    bool? showResults,
    Object? selected = _unset,
    Object? route = _unset,
    bool? routeLoading,
    Object? routeError = _unset,
    TravelMode? mode,
    Object? me = _unset,
    List<Place>? recent,
    bool? locationFallback,
    Object? nearbyCategory = _unset,
    List<Place>? nearby,
    bool? nearbyLoading,
    Object? nearbyError = _unset,
    bool? isNavigating,
    int? currentStepIndex,
  }) {
    return ExploreState(
      query: query ?? this.query,
      results: results ?? this.results,
      searching: searching ?? this.searching,
      searchError: identical(searchError, _unset)
          ? this.searchError
          : searchError as String?,
      showResults: showResults ?? this.showResults,
      selected: identical(selected, _unset)
          ? this.selected
          : selected as Place?,
      route: identical(route, _unset) ? this.route : route as RouteInfo?,
      routeLoading: routeLoading ?? this.routeLoading,
      routeError: identical(routeError, _unset)
          ? this.routeError
          : routeError as String?,
      mode: mode ?? this.mode,
      me: identical(me, _unset) ? this.me : me as GeoPoint?,
      recent: recent ?? this.recent,
      locationFallback: locationFallback ?? this.locationFallback,
      nearbyCategory: identical(nearbyCategory, _unset)
          ? this.nearbyCategory
          : nearbyCategory as NearbyCategory?,
      nearby: nearby ?? this.nearby,
      nearbyLoading: nearbyLoading ?? this.nearbyLoading,
      nearbyError: identical(nearbyError, _unset)
          ? this.nearbyError
          : nearbyError as String?,
      isNavigating: isNavigating ?? this.isNavigating,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}

class ExploreController extends Notifier<ExploreState> {
  Timer? _debounce;
  int _searchToken = 0;
  int _routeToken = 0;
  int _nearbyToken = 0;

  @override
  ExploreState build() {
    ref.onDispose(() => _debounce?.cancel());
    return ExploreState(
      recent: ref.watch(recentSearchesStoreProvider).read(),
    );
  }

  void updateQuery(String value) {
    _debounce?.cancel();
    _nearbyToken++;
    final query = value.trim();

    if (query.length < 2) {
      _searchToken++;
      state = state.copyWith(
        query: value,
        results: const [],
        searching: false,
        searchError: null,
        showResults: true,
        nearbyCategory: null,
        nearby: const [],
        nearbyLoading: false,
        nearbyError: null,
      );
      return;
    }

    state = state.copyWith(
      query: value,
      searching: true,
      searchError: null,
      showResults: true,
      nearbyCategory: null,
      nearby: const [],
      nearbyLoading: false,
      nearbyError: null,
    );
    _debounce = Timer(AppConfig.searchDebounce, () => _search(query));
  }

  void retrySearch() {
    final query = state.query.trim();
    if (query.length < 2) return;
    _debounce?.cancel();
    state = state.copyWith(searching: true, searchError: null, showResults: true);
    unawaited(_search(query));
  }

  void setResultsVisible(bool visible) {
    if (state.showResults == visible) return;
    state = state.copyWith(showResults: visible);
  }

  void dismissResults() {
    _nearbyToken++;
    state = state.copyWith(
      showResults: false,
      results: const [],
      nearbyCategory: null,
      nearby: const [],
      nearbyLoading: false,
      nearbyError: null,
    );
  }

  /// Where "near me" is measured from (device GPS).
  GeoPoint _discoveryCenter(GeoPoint fallback) => fallback;

  /// Selects (or toggles off) a nearby category around [center].
  void toggleNearby(NearbyCategory category, {required GeoPoint center}) {
    _debounce?.cancel();
    _searchToken++;
    _nearbyToken++;
    final anchor = _discoveryCenter(center);

    if (state.nearbyCategory == category) {
      state = state.copyWith(
        nearbyCategory: null,
        nearby: const [],
        nearbyLoading: false,
        nearbyError: null,
        showResults: false,
      );
      return;
    }

    state = state.copyWith(
      nearbyCategory: category,
      nearby: const [],
      nearbyLoading: true,
      nearbyError: null,
      query: '',
      results: const [],
      searching: false,
      searchError: null,
      showResults: true,
      me: anchor,
    );
    unawaited(_loadNearby(category, anchor));
  }

  void retryNearby({required GeoPoint center}) {
    final category = state.nearbyCategory;
    if (category == null) return;
    final anchor = _discoveryCenter(center);
    state = state.copyWith(nearbyLoading: true, nearbyError: null, me: anchor);
    unawaited(_loadNearby(category, anchor));
  }

  void selectPlace(Place place, {bool fetchRoute = true}) {
    _debounce?.cancel();
    _searchToken++;
    _nearbyToken++;
    state = state.copyWith(
      selected: place,
      query: place.name,
      results: const [],
      searching: false,
      searchError: null,
      showResults: false,
      route: null,
      routeError: null,
      routeLoading: fetchRoute,
      nearbyCategory: null,
      nearby: const [],
      nearbyLoading: false,
      nearbyError: null,
      isNavigating: false,
      currentStepIndex: 0,
    );
    unawaited(_remember(place));
    if (fetchRoute) unawaited(_loadRoute(place));
  }

  void clearSelection() {
    _routeToken++;
    _debounce?.cancel();
    _nearbyToken++;
    state = state.copyWith(
      selected: null,
      route: null,
      routeLoading: false,
      routeError: null,
      query: '',
      results: const [],
      searching: false,
      showResults: false,
      nearbyCategory: null,
      nearby: const [],
      nearbyLoading: false,
      nearbyError: null,
      isNavigating: false,
      currentStepIndex: 0,
    );
  }

  void startNavigation() {
    if (state.selected == null) return;
    state = state.copyWith(
      isNavigating: true,
      currentStepIndex: 0,
      showResults: false,
    );
  }

  void stopNavigation() {
    state = state.copyWith(
      isNavigating: false,
      currentStepIndex: 0,
    );
  }

  void setStepIndex(int index) {
    final route = state.route;
    if (route == null || route.steps.isEmpty) return;
    final clamped = index.clamp(0, route.steps.length - 1);
    if (clamped == state.currentStepIndex) return;
    state = state.copyWith(currentStepIndex: clamped);
  }

  void nextStep() {
    setStepIndex(state.currentStepIndex + 1);
  }

  void previousStep() {
    setStepIndex(state.currentStepIndex - 1);
  }

  void setMode(TravelMode mode) {
    if (mode == state.mode) return;
    final selected = state.selected;
    state = state.copyWith(
      mode: mode,
      route: null,
      routeError: null,
      routeLoading: selected != null,
    );
    if (selected != null) unawaited(_loadRoute(selected));
  }

  void refreshRoute() {
    final selected = state.selected;
    if (selected == null) return;
    state = state.copyWith(routeLoading: true, routeError: null, route: null);
    unawaited(_loadRoute(selected));
  }

  Future<void> toggleFavorite(Place place) =>
      ref.read(favoritesProvider.notifier).toggle(place);

  Future<void> clearRecent() async {
    await ref.read(recentSearchesStoreProvider).clear();
    if (!ref.mounted) return;
    state = state.copyWith(recent: const []);
  }

  /// Locates the device. Returns the real position, or `null` when the app
  /// fell back to the default city center.
  Future<GeoPoint?> locate({bool requestPermission = true}) async {
    // Demo data is a Phnom Penh sample, so pin the demo "you" to the city
    // instead of the device GPS. Otherwise distances and demo routes are
    // measured from wherever the device happens to be (e.g. an emulator
    // defaulting to Mountain View).
    if (ref.read(settingsProvider).demoMode) {
      state = state.copyWith(
        me: AppConfig.defaultLocation,
        locationFallback: false,
      );
      return AppConfig.defaultLocation;
    }

    final point = await ref
        .read(locationServiceProvider)
        .current(requestPermission: requestPermission);
    if (!ref.mounted) return null;
    state = state.copyWith(
      me: point ?? AppConfig.defaultLocation,
      locationFallback: point == null,
    );
    return point;
  }

  Future<void> _search(String query) async {
    final token = ++_searchToken;
    try {
      final results = await ref.read(placesRepositoryProvider).search(query);
      if (!ref.mounted || token != _searchToken) return;
      state = state.copyWith(
        results: results,
        searching: false,
        searchError: null,
      );
    } on ApiException catch (error) {
      if (!ref.mounted || token != _searchToken) return;
      state = state.copyWith(
        results: const [],
        searching: false,
        searchError: error.message,
      );
    } on Object {
      if (!ref.mounted || token != _searchToken) return;
      state = state.copyWith(
        results: const [],
        searching: false,
        searchError: 'Search failed. Please try again.',
      );
    }
  }

  Future<void> _loadNearby(NearbyCategory category, GeoPoint center) async {
    final token = ++_nearbyToken;
    try {
      final places = await ref.read(placesRepositoryProvider).nearby(
            center: center,
            category: category,
          );
      if (!ref.mounted || token != _nearbyToken) return;
      state = state.copyWith(
        nearby: places,
        nearbyLoading: false,
        nearbyError: null,
      );
    } on ApiException catch (error) {
      if (!ref.mounted || token != _nearbyToken) return;
      state = state.copyWith(
        nearby: const [],
        nearbyLoading: false,
        nearbyError: error.message,
      );
    } on Object {
      if (!ref.mounted || token != _nearbyToken) return;
      state = state.copyWith(
        nearby: const [],
        nearbyLoading: false,
        nearbyError: 'Could not load nearby places. Please try again.',
      );
    }
  }

  Future<void> _loadRoute(Place place) async {
    final token = ++_routeToken;
    final origin = state.me ?? AppConfig.defaultLocation;
    try {
      final route = await ref.read(placesRepositoryProvider).directions(
            origin: origin,
            destination: place.location,
            mode: state.mode,
          );
      if (!ref.mounted || token != _routeToken) return;
      state = state.copyWith(
        route: route,
        routeLoading: false,
        routeError: null,
      );
    } on ApiException catch (error) {
      if (!ref.mounted || token != _routeToken) return;
      state = state.copyWith(
        routeLoading: false,
        routeError: error.message,
        route: null,
      );
    } on Object {
      if (!ref.mounted || token != _routeToken) return;
      state = state.copyWith(
        routeLoading: false,
        routeError: 'Could not get directions. Try another mode.',
        route: null,
      );
    }
  }

  Future<void> _remember(Place place) async {
    final store = ref.read(recentSearchesStoreProvider);
    final updated = await store.add(place);
    if (!ref.mounted) return;
    state = state.copyWith(recent: updated);
  }
}

final exploreProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);
