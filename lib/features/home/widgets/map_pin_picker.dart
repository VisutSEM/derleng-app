import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../core/config/app_config.dart';
import '../../../core/utils/ui.dart';
import '../../../data/providers.dart';
import '../../../models/geo_point.dart';
import '../../../models/place.dart';
import '../../explore/widgets/map_canvas.dart';
import '../../explore/widgets/map_view.dart';

/// Full-screen interactive map interface to drop a pin anywhere,
/// inspect coordinates, switch satellite/terrain views, and tag a place.
class MapLocationPickerScreen extends ConsumerStatefulWidget {
  const MapLocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialTitle,
    this.initialAddress,
    this.initialCategory,
  });

  final GeoPoint? initialLocation;
  final String? initialTitle;
  final String? initialAddress;
  final String? initialCategory;

  static Future<Place?> pickLocation(
    BuildContext context, {
    GeoPoint? initialLocation,
    String? initialTitle,
    String? initialAddress,
    String? initialCategory,
  }) {
    return Navigator.of(context).push<Place>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MapLocationPickerScreen(
          initialLocation: initialLocation,
          initialTitle: initialTitle,
          initialAddress: initialAddress,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  @override
  ConsumerState<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState
    extends ConsumerState<MapLocationPickerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  late GeoPoint _currentLocation;
  late String _selectedCategory;
  gmaps.MapType _mapType = gmaps.MapType.normal;
  gmaps.GoogleMapController? _googleMap;
  late final MapCanvasController _canvas;

  bool _isMoving = false;
  bool _locating = false;

  static const List<Map<String, dynamic>> _tagCategories = [
    {
      'id': 'cafe',
      'label': 'Cafe',
      'icon': Icons.local_cafe_rounded,
      'color': Color(0xFF92400E),
    },
    {
      'id': 'restaurant',
      'label': 'Restaurant',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFEA580C),
    },
    {
      'id': 'landmark',
      'label': 'Landmark',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF0F766E),
    },
    {
      'id': 'temple',
      'label': 'Temple',
      'icon': Icons.temple_buddhist_rounded,
      'color': Color(0xFFB45309),
    },
    {
      'id': 'hotel',
      'label': 'Hotel',
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF0891B2),
    },
    {
      'id': 'park',
      'label': 'Park / Nature',
      'icon': Icons.park_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'id': 'market',
      'label': 'Market',
      'icon': Icons.storefront_rounded,
      'color': Color(0xFFDB2777),
    },
    {
      'id': 'nightlife',
      'label': 'Nightlife',
      'icon': Icons.nightlife_rounded,
      'color': Color(0xFFE11D48),
    },
    {
      'id': 'place',
      'label': 'Other',
      'icon': Icons.place_rounded,
      'color': Color(0xFF64748B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation ?? AppConfig.defaultLocation;
    _titleController.text = widget.initialTitle ?? '';
    _addressController.text = widget.initialAddress ?? '';
    _selectedCategory = widget.initialCategory ?? 'cafe';
    _canvas = MapCanvasController(center: _currentLocation, zoom: 16);

    // If no initial location was provided, attempt to locate user GPS
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateUser(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _canvas.dispose();
    super.dispose();
  }

  Future<void> _locateUser({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final loc = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      if (loc != null) {
        _animateTo(gmaps.LatLng(loc.lat, loc.lng));
      } else if (!silent) {
        showAppSnackBar(context, 'Could not retrieve GPS position.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _animateTo(gmaps.LatLng target) {
    setState(() {
      _currentLocation = GeoPoint(target.latitude, target.longitude);
    });
    _canvas.moveTo(_currentLocation, zoom: 16);
    _googleMap?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(target, 16.5),
    );
  }

  void _confirmPlace() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showAppSnackBar(
        context,
        'Please enter a place name for this pin.',
        isError: true,
      );
      return;
    }

    final addr = _addressController.text.trim();
    final place = Place(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      address: addr.isNotEmpty
          ? addr
          : '${_currentLocation.lat.toStringAsFixed(4)}, ${_currentLocation.lng.toStringAsFixed(4)}',
      location: _currentLocation,
      category: _selectedCategory,
      rating: 5.0,
      ratingCount: 1,
    );

    Navigator.of(context).pop(place);
  }

  void _toggleMapType() {
    setState(() {
      if (_mapType == gmaps.MapType.normal) {
        _mapType = gmaps.MapType.satellite;
      } else if (_mapType == gmaps.MapType.satellite) {
        _mapType = gmaps.MapType.hybrid;
      } else if (_mapType == gmaps.MapType.hybrid) {
        _mapType = gmaps.MapType.terrain;
      } else {
        _mapType = gmaps.MapType.normal;
      }
    });

    final label = _mapType == gmaps.MapType.satellite
        ? 'Satellite'
        : _mapType == gmaps.MapType.hybrid
            ? 'Hybrid'
            : _mapType == gmaps.MapType.terrain
                ? 'Terrain'
                : 'Default';
    showAppSnackBar(context, 'Map view: $label');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usesGoogle = MapView.usesGoogleMaps;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Full-screen map
          Positioned.fill(
            child: usesGoogle
                ? gmaps.GoogleMap(
                    mapType: _mapType,
                    initialCameraPosition: gmaps.CameraPosition(
                      target: toGoogleLatLng(_currentLocation),
                      zoom: 16.5,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    onMapCreated: (ctrl) => _googleMap = ctrl,
                    onCameraMoveStarted: () {
                      if (!_isMoving) setState(() => _isMoving = true);
                    },
                    onCameraMove: (position) {
                      _currentLocation = GeoPoint(
                        position.target.latitude,
                        position.target.longitude,
                      );
                    },
                    onCameraIdle: () {
                      if (_isMoving) {
                        setState(() => _isMoving = false);
                      }
                    },
                    onTap: _animateTo,
                  )
                : MapCanvas(
                    controller: _canvas,
                    me: _currentLocation,
                    onMapTap: () {},
                  ),
          ),

          // 2. Center Dropping Pin with floating lift animation
          Center(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                transform: Matrix4.translationValues(
                  0,
                  _isMoving ? -24 : -12,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'Drop pin here',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.location_on_rounded,
                      size: 46,
                      color: scheme.primary,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // Shadow on the ground
                    Container(
                      width: 14,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isMoving ? 0.15 : 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FloatingCircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pin_drop_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Move map to drop pin',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FloatingCircleButton(
                    icon: _mapType == gmaps.MapType.satellite ||
                            _mapType == gmaps.MapType.hybrid
                        ? Icons.satellite_alt_rounded
                        : Icons.layers_rounded,
                    tooltip: 'Switch Map View',
                    highlighted: _mapType != gmaps.MapType.normal,
                    onPressed: _toggleMapType,
                  ),
                ],
              ),
            ),
          ),

          // 4. GPS Re-center FAB
          Positioned(
            right: 16,
            bottom: 270,
            child: _FloatingCircleButton(
              icon: Icons.my_location_rounded,
              tooltip: 'Current GPS Location',
              highlighted: true,
              onPressed: _locating ? null : () => _locateUser(),
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
          ),

          // 5. Bottom Pin Details & Confirmation Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Coordinates badge & category
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 13,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_currentLocation.lat.toStringAsFixed(5)}, ${_currentLocation.lng.toStringAsFixed(5)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _isMoving ? 'Moving…' : 'Pin Dropped',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _isMoving
                                  ? scheme.secondary
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Place Name Field
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Place name (e.g. Amazon Cafe BKK1, Riverfront…) *',
                          prefixIcon: const Icon(Icons.business_rounded, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Address / Area Field
                      TextField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.words,
                        style: theme.textTheme.bodySmall,
                        decoration: InputDecoration(
                          hintText: 'Address or Area (e.g. St. 302, BKK1, Phnom Penh)',
                          prefixIcon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category selection row
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tagCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _tagCategories[index];
                            final id = cat['id'] as String;
                            final isSel = _selectedCategory == id;
                            final color = cat['color'] as Color;

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() => _selectedCategory = id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? color
                                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel ? color : scheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat['icon'] as IconData,
                                      size: 14,
                                      color: isSel ? Colors.white : color,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      cat['label'] as String,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: isSel ? Colors.white : scheme.onSurface,
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Confirm & Tag Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _confirmPlace,
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text(
                            'Confirm & Tag This Place',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.highlighted = false,
    this.child,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlighted ? scheme.primary : scheme.surface;
    final fg = highlighted ? scheme.onPrimary : scheme.onSurface;

    return Material(
      color: bg,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: child ?? Icon(icon, size: 22, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
