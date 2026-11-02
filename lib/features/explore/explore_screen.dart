import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../core/config/app_config.dart';
import '../../core/utils/ui.dart';
import '../../models/geo_point.dart';
import '../../models/nearby_category.dart';
import '../../models/place.dart';
import '../../models/route_info.dart';
import '../favorites/favorites_controller.dart';
import 'explore_controller.dart';
import 'widgets/map_canvas.dart';
import 'widgets/map_view.dart';
import 'widgets/navigation_hud.dart';
import 'widgets/nearby_bar.dart';
import 'widgets/place_sheet.dart';
import 'widgets/search_bar.dart';
import 'widgets/search_results.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MapCanvasController _canvas = MapCanvasController(
    center: AppConfig.defaultLocation,
    zoom: 13.5,
  );

  gmaps.GoogleMapController? _googleMap;
  gmaps.MapType _mapType = gmaps.MapType.normal;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate(requestPermission: false, silent: true);
    });
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _searchController.dispose();
    _canvas.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
    if (_searchFocus.hasFocus) {
      ref.read(exploreProvider.notifier).setResultsVisible(true);
    }
  }

  void _focusOn(GeoPoint point, double zoom) {
    _canvas.moveTo(point, zoom: zoom);
    final map = _googleMap;
    if (map != null) {
      map.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(toGoogleLatLng(point), zoom),
      );
    }
  }

  Future<void> _locate({
    bool requestPermission = true,
    bool silent = false,
  }) async {
    if (_locating) return;
    setState(() => _locating = true);
    final point = await ref
        .read(exploreProvider.notifier)
        .locate(requestPermission: requestPermission);
    if (!mounted) return;
    setState(() => _locating = false);
    if (point != null) {
      _focusOn(point, 15);
    } else if (!silent) {
      showAppSnackBar(
        context,
        'Location unavailable — showing central Phnom Penh.',
      );
    }
  }

  void _zoomBy(double delta) {
    final map = _googleMap;
    if (map != null) {
      map.animateCamera(
        delta > 0 ? gmaps.CameraUpdate.zoomIn() : gmaps.CameraUpdate.zoomOut(),
      );
      return;
    }
    _canvas.moveTo(_canvas.center, zoom: _canvas.zoom + delta);
  }

  void _selectPlace(Place place) {
    _searchFocus.unfocus();
    ref.read(exploreProvider.notifier).selectPlace(place);
  }

  void _handleMapTap() {
    _searchFocus.unfocus();
    ref.read(exploreProvider.notifier).dismissResults();
  }

  void _cancelSearch() {
    _searchController.clear();
    final controller = ref.read(exploreProvider.notifier);
    controller.updateQuery('');
    controller.dismissResults();
    _searchFocus.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(exploreProvider.notifier).updateQuery('');
    _searchFocus.requestFocus();
  }

  void _toggleNearby(NearbyCategory category, GeoPoint? me) {
    _searchFocus.unfocus();
    _searchController.clear();
    ref.read(exploreProvider.notifier).toggleNearby(
          category,
          center: me ?? _canvas.center,
        );
  }

  void _fitRoute(List<GeoPoint> points) {
    if (points.length < 2) return;
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLng = points.first.lng;
    var maxLng = points.first.lng;
    for (final point in points) {
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
      minLng = math.min(minLng, point.lng);
      maxLng = math.max(maxLng, point.lng);
    }

    final center = GeoPoint((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final size = MediaQuery.sizeOf(context);
    final spanLng = math.max(maxLng - minLng, 0.002);
    final spanLat = math.max(maxLat - minLat, 0.002);
    final latScale = math.cos(center.lat * math.pi / 180).abs();

    final zoomX =
        math.log(size.width * 0.85 * 360 / (spanLng * 256)) / math.ln2;
    final zoomY = math.log(
          size.height * 0.85 * 360 * math.max(latScale, 0.2) / (spanLat * 256),
        ) /
        math.ln2;
    final zoom = math.min(zoomX, zoomY).clamp(11.0, 16.5).toDouble();
    final map = _googleMap;
    if (map != null) {
      try {
        final bounds = gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLat, minLng),
          northeast: gmaps.LatLng(maxLat, maxLng),
        );
        map.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 72));
        _canvas.moveTo(center, zoom: zoom);
        return;
      } catch (_) {}
    }
    _focusOn(center, zoom);
  }

  void _startNavigation(Place place) {
    ref.read(exploreProvider.notifier).startNavigation();
    _recenterOnUser(isNavigating: true);
  }

  void _recenterOnUser({bool isNavigating = false}) {
    final state = ref.read(exploreProvider);
    final userLoc =
        state.me ?? state.selected?.location ?? AppConfig.defaultLocation;
    final map = _googleMap;

    if (map != null) {
      double bearing = 0.0;
      final route = state.route;
      if (isNavigating && route != null && route.points.length > 1) {
        final nextTarget =
            route.points.length > 2 ? route.points[1] : route.points.last;
        bearing = _calculateBearing(userLoc, nextTarget);
      }

      map.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: toGoogleLatLng(userLoc),
            zoom: isNavigating ? 17.5 : 16.0,
            tilt: isNavigating ? 45.0 : 0.0,
            bearing: bearing,
          ),
        ),
      );
    } else {
      _canvas.moveTo(userLoc, zoom: isNavigating ? 16.5 : 15.5);
    }
  }

  double _calculateBearing(GeoPoint start, GeoPoint end) {
    final startLat = start.lat * (math.pi / 180.0);
    final startLng = start.lng * (math.pi / 180.0);
    final endLat = end.lat * (math.pi / 180.0);
    final endLng = end.lng * (math.pi / 180.0);

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final bearing = math.atan2(y, x) * (180.0 / math.pi);
    return (bearing + 360.0) % 360.0;
  }

  void _focusOnCurrentStep() {
    final state = ref.read(exploreProvider);
    final route = state.route;
    if (route == null || route.steps.isEmpty) return;
    final step =
        route.steps[state.currentStepIndex.clamp(0, route.steps.length - 1)];
    final map = _googleMap;
    if (map != null) {
      map.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: toGoogleLatLng(step.location),
            zoom: 17.5,
            tilt: 40.0,
          ),
        ),
      );
    } else {
      _canvas.moveTo(step.location, zoom: 16.5);
    }
  }

  String _mapTypeTitle(gmaps.MapType type) {
    switch (type) {
      case gmaps.MapType.satellite:
        return 'Satellite';
      case gmaps.MapType.hybrid:
        return 'Hybrid';
      case gmaps.MapType.terrain:
        return 'Terrain';
      case gmaps.MapType.normal:
      default:
        return 'Default';
    }
  }

  void _showMapTypePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;

        final types = [
          {
            'type': gmaps.MapType.normal,
            'title': 'Default',
            'desc': 'Standard road map with clear labels',
            'icon': Icons.map_rounded,
            'color': const Color(0xFF2563EB),
          },
          {
            'type': gmaps.MapType.satellite,
            'title': 'Satellite',
            'desc': 'High-resolution aerial satellite imagery',
            'icon': Icons.satellite_alt_rounded,
            'color': const Color(0xFF059669),
          },
          {
            'type': gmaps.MapType.hybrid,
            'title': 'Hybrid',
            'desc': 'Satellite view with street names and labels',
            'icon': Icons.public_rounded,
            'color': const Color(0xFF7C3AED),
          },
          {
            'type': gmaps.MapType.terrain,
            'title': 'Terrain',
            'desc': 'Topography with mountains and elevation',
            'icon': Icons.terrain_rounded,
            'color': const Color(0xFFD97706),
          },
        ];

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Map Type',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: types.map((item) {
                      final itemType = item['type'] as gmaps.MapType;
                      final isSelected = _mapType == itemType;
                      final color = item['color'] as Color;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() => _mapType = itemType);
                          Navigator.of(ctx).pop();
                          showAppSnackBar(
                            context,
                            'Switched to ${item['title']} map view',
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : scheme.outlineVariant.withValues(alpha: 0.4),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? color
                                            : scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['desc'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: color,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreProvider);
    final favorites = ref.watch(favoritesProvider);
    final selected = state.selected;
    final isFavorite =
        selected != null && favorites.any((place) => place.id == selected.id);
    final panelMaxHeight = MediaQuery.sizeOf(context).height * 0.52;

    ref.listen<Place?>(exploreProvider.select((value) => value.selected),
        (previous, next) {
      if (next != null) {
        if (next.id != previous?.id) {
          if (_searchController.text != next.name) {
            _searchController.text = next.name;
          }
          _focusOn(next.location, 15.5);
        }
      } else if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    ref.listen<RouteInfo?>(exploreProvider.select((value) => value.route),
        (previous, next) {
      if (next != null && next.hasPoints && !identical(next, previous)) {
        _fitRoute(next.points);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              controller: _canvas,
              me: state.me,
              selected: selected,
              places: state.showResults ? state.results : state.nearby,
              route: state.route?.points ?? const [],
              mapType: _mapType,
              isNavigating: state.isNavigating,
              onMarkerTap: (place) {
                ref.read(exploreProvider.notifier).selectPlace(place);
                _focusOn(place.location, 15.5);
              },
              onMapTap: _handleMapTap,
              onGoogleMapCreated: (controller) => _googleMap = controller,
            ),
          ),
          if (state.isNavigating && selected != null)
            NavigationTopBar(
              place: selected,
              route: state.route,
              stepIndex: state.currentStepIndex,
              onNextStep: () {
                ref.read(exploreProvider.notifier).nextStep();
                _focusOnCurrentStep();
              },
              onPreviousStep: () {
                ref.read(exploreProvider.notifier).previousStep();
                _focusOnCurrentStep();
              },
              onOpenStepsList: () => NavigationStepsSheet.show(
                context,
                place: selected,
                route: state.route,
                currentStepIndex: state.currentStepIndex,
                onSelectStep: (idx) {
                  ref.read(exploreProvider.notifier).setStepIndex(idx);
                  _focusOnCurrentStep();
                },
              ),
              onExit: () {
                ref.read(exploreProvider.notifier).stopNavigation();
                if (state.route != null) _fitRoute(state.route!.points);
              },
            )
          else
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExploreSearchBar(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          focused: _searchFocus.hasFocus,
                          hasText: state.query.isNotEmpty,
                          loading: state.searching,
                          onChanged: (value) => ref
                              .read(exploreProvider.notifier)
                              .updateQuery(value),
                          onClear: _clearSearch,
                          onCancel: _cancelSearch,
                        ),
                        if (selected == null &&
                            !_searchFocus.hasFocus &&
                            state.query.trim().isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: NearbyCategoryBar(
                              selected: state.nearbyCategory,
                              onSelected: (category) =>
                                  _toggleNearby(category, state.me),
                            ),
                          ),
                        if (state.showResults)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxHeight: panelMaxHeight),
                              child: SearchResultsPanel(
                                state: state,
                                onSelect: _selectPlace,
                                onRetry: () => ref
                                    .read(exploreProvider.notifier)
                                    .retrySearch(),
                                onRetryNearby: () => ref
                                    .read(exploreProvider.notifier)
                                    .retryNearby(
                                      center: state.me ?? _canvas.center,
                                    ),
                                onClearNearby: () => ref
                                    .read(exploreProvider.notifier)
                                    .dismissResults(),
                                onClearRecent: () => ref
                                    .read(exploreProvider.notifier)
                                    .clearRecent(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: state.isNavigating
                ? 120
                : (selected != null ? 320 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControl(
                  icon: Icons.layers_rounded,
                  tooltip: 'Map style: ${_mapTypeTitle(_mapType)}',
                  highlighted: _mapType != gmaps.MapType.normal,
                  onPressed: _showMapTypePicker,
                ),
                const SizedBox(height: 8),
                if (!MapView.usesGoogleMaps) ...[
                  _MapControl(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onPressed: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _MapControl(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onPressed: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                ],
                _MapControl(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My location',
                  highlighted: true,
                  onPressed: _locating ? null : _locate,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: selected == null
                      ? const SizedBox.shrink()
                      : state.isNavigating
                          ? NavigationBottomBar(
                              key: ValueKey('nav_${selected.id}'),
                              place: selected,
                              route: state.route,
                              mode: state.mode,
                              onRecenter: () =>
                                  _recenterOnUser(isNavigating: true),
                              onOpenStepsList: () => NavigationStepsSheet.show(
                                context,
                                place: selected,
                                route: state.route,
                                currentStepIndex: state.currentStepIndex,
                                onSelectStep: (idx) {
                                  ref
                                      .read(exploreProvider.notifier)
                                      .setStepIndex(idx);
                                  _focusOnCurrentStep();
                                },
                              ),
                              onExit: () {
                                ref
                                    .read(exploreProvider.notifier)
                                    .stopNavigation();
                                if (state.route != null) {
                                  _fitRoute(state.route!.points);
                                }
                              },
                            )
                          : PlaceSheet(
                              key: ValueKey(selected.id),
                              place: selected,
                              mode: state.mode,
                              isFavorite: isFavorite,
                              me: state.me,
                              route: state.route,
                              routeLoading: state.routeLoading,
                              routeError: state.routeError,
                              onModeChanged: (mode) => ref
                                  .read(exploreProvider.notifier)
                                  .setMode(mode),
                              onClose: () => ref
                                  .read(exploreProvider.notifier)
                                  .clearSelection(),
                              onRetry: () => ref
                                  .read(exploreProvider.notifier)
                                  .refreshRoute(),
                              onStart: () => _startNavigation(selected),
                              onToggleFavorite: () => ref
                                  .read(exploreProvider.notifier)
                                  .toggleFavorite(selected),
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    this.icon,
    this.tooltip,
    this.onPressed,
    this.highlighted = false,
    this.child,
  });

  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = highlighted ? scheme.primary : scheme.surface;
    final foreground = highlighted ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      color: background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: child ??
                  Icon(
                    icon,
                    size: 21,
                    color: onPressed == null
                        ? foreground.withValues(alpha: 0.5)
                        : foreground,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
