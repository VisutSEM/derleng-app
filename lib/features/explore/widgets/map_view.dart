import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../core/config/app_config.dart';
import '../../../models/geo_point.dart';
import '../../../models/place.dart';
import 'map_canvas.dart';

gmaps.LatLng toGoogleLatLng(GeoPoint point) =>
    gmaps.LatLng(point.lat, point.lng);

/// Renders a live Google map on Android/iOS/web when a key is configured,
/// and the interactive preview canvas everywhere else.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.controller,
    required this.me,
    required this.selected,
    this.places = const [],
    required this.route,
    this.mapType = gmaps.MapType.normal,
    this.isNavigating = false,
    required this.onMarkerTap,
    required this.onMapTap,
    required this.onGoogleMapCreated,
  });

  final MapCanvasController controller;
  final GeoPoint? me;
  final Place? selected;
  final List<Place> places;
  final List<GeoPoint> route;
  final gmaps.MapType mapType;
  final bool isNavigating;
  final ValueChanged<Place> onMarkerTap;
  final VoidCallback onMapTap;
  final ValueChanged<gmaps.GoogleMapController> onGoogleMapCreated;

  static bool get usesGoogleMaps {
    if (!AppConfig.hasGoogleMapsKey) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!usesGoogleMaps) {
      return MapCanvas(
        controller: controller,
        me: me,
        selected: selected,
        route: route,
        onMarkerTap: onMarkerTap,
        onMapTap: onMapTap,
      );
    }
    return _GoogleMapView(
      me: me,
      selected: selected,
      places: places,
      route: route,
      mapType: mapType,
      isNavigating: isNavigating,
      onMarkerTap: onMarkerTap,
      onMapTap: onMapTap,
      onCreated: onGoogleMapCreated,
    );
  }
}

class _GoogleMapView extends StatefulWidget {
  const _GoogleMapView({
    required this.me,
    required this.selected,
    required this.places,
    required this.route,
    required this.mapType,
    this.isNavigating = false,
    required this.onMarkerTap,
    required this.onMapTap,
    required this.onCreated,
  });

  final GeoPoint? me;
  final Place? selected;
  final List<Place> places;
  final List<GeoPoint> route;
  final gmaps.MapType mapType;
  final bool isNavigating;
  final ValueChanged<Place> onMarkerTap;
  final VoidCallback onMapTap;
  final ValueChanged<gmaps.GoogleMapController> onCreated;

  @override
  State<_GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<_GoogleMapView> {
  double _markerHueForCategory(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('cafe') || cat.contains('coffee') || cat.contains('food') || cat.contains('restaurant')) {
      return gmaps.BitmapDescriptor.hueOrange;
    } else if (cat.contains('temple') || cat.contains('heritage') || cat.contains('museum')) {
      return gmaps.BitmapDescriptor.hueYellow;
    } else if (cat.contains('hotel') || cat.contains('resort')) {
      return gmaps.BitmapDescriptor.hueCyan;
    } else if (cat.contains('nature') || cat.contains('park') || cat.contains('mountain')) {
      return gmaps.BitmapDescriptor.hueGreen;
    }
    return gmaps.BitmapDescriptor.hueRed;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = widget.me;
    final selected = widget.selected;

    final markers = <gmaps.Marker>{};

    // 1. Discovered places / Nearby search results (hidden during navigation for clarity)
    if (!widget.isNavigating) {
      for (final place in widget.places) {
        if (selected != null && place.id == selected.id) continue;
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(place.id),
            position: toGoogleLatLng(place.location),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              _markerHueForCategory(place.category),
            ),
            infoWindow: gmaps.InfoWindow(
              title: place.name,
              snippet:
                  place.address.isNotEmpty ? place.address : place.category,
              onTap: () => widget.onMarkerTap(place),
            ),
            onTap: () => widget.onMarkerTap(place),
          ),
        );
      }
    }

    // 2. Selected Place (active destination)
    if (selected != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('selected_destination'),
          position: toGoogleLatLng(selected.location),
          zIndexInt: 10,
          infoWindow: gmaps.InfoWindow(
            title: selected.name,
            snippet: selected.address,
            onTap: () => widget.onMarkerTap(selected),
          ),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            widget.isNavigating
                ? gmaps.BitmapDescriptor.hueRose
                : gmaps.BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }

    // 3. User Location fallback marker (if native blue dot isn't available)
    if (me != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('me'),
          position: toGoogleLatLng(me),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const gmaps.InfoWindow(title: 'You are here'),
        ),
      );
    }

    return gmaps.GoogleMap(
      mapType: widget.mapType,
      initialCameraPosition: gmaps.CameraPosition(
        target: toGoogleLatLng(
          selected?.location ?? me ?? AppConfig.defaultLocation,
        ),
        zoom: selected != null ? 15.5 : 13.5,
      ),
      padding: widget.isNavigating
          ? const EdgeInsets.only(top: 140, bottom: 130)
          : EdgeInsets.zero,
      myLocationEnabled: me != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      onMapCreated: widget.onCreated,
      onTap: (_) => widget.onMapTap(),
      markers: markers,
      polylines: {
        if (widget.route.length > 1) ...[
          // Background casing for contrast against roads/satellite imagery
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('route_casing'),
            points: widget.route.map(toGoogleLatLng).toList(growable: false),
            width: widget.isNavigating ? 11 : 8,
            color: (widget.mapType == gmaps.MapType.satellite ||
                    widget.mapType == gmaps.MapType.hybrid)
                ? const Color(0xFF0369A1)
                : const Color(0xFF1E3A8A),
            jointType: gmaps.JointType.round,
            startCap: gmaps.Cap.roundCap,
            endCap: gmaps.Cap.roundCap,
            zIndex: 1,
          ),
          // Foreground navigation line
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('route'),
            points: widget.route.map(toGoogleLatLng).toList(growable: false),
            width: widget.isNavigating ? 7 : 5,
            color: (widget.mapType == gmaps.MapType.satellite ||
                    widget.mapType == gmaps.MapType.hybrid)
                ? const Color(0xFF38BDF8)
                : scheme.primary,
            jointType: gmaps.JointType.round,
            startCap: gmaps.Cap.roundCap,
            endCap: gmaps.Cap.roundCap,
            zIndex: 2,
          ),
        ],
      },
    );
  }
}
