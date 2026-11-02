import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/geo_point.dart';
import '../../../models/place.dart';

/// Web-Mercator projection helpers shared by the canvas map and the screen.
class MapProjection {
  const MapProjection._();

  static const double tileSize = 256;

  static Offset world(GeoPoint point, double zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final x = (point.lng + 180) / 360 * scale;
    final sinLat = math.sin(point.lat * math.pi / 180).clamp(-0.9999, 0.9999);
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x.toDouble(), y.toDouble());
  }

  static GeoPoint unproject(Offset world, double zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final lng = world.dx / scale * 360 - 180;
    final n = math.pi - 2 * math.pi * world.dy / scale;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return GeoPoint(lat, lng);
  }

  /// Ground resolution at the given latitude (meters per screen pixel).
  static double metersPerPixel(GeoPoint center, double zoom) {
    return 156543.03392 *
        math.cos(center.lat * math.pi / 180) /
        math.pow(2, zoom);
  }
}

class MapCanvasController extends ChangeNotifier {
  MapCanvasController({required this.center, double zoom = 14})
      : zoom = zoom.clamp(3.0, 18.0).toDouble();

  GeoPoint center;
  double zoom;

  void moveTo(GeoPoint center, {double? zoom}) {
    this.center = center;
    if (zoom != null) this.zoom = zoom.clamp(3.0, 18.0).toDouble();
    notifyListeners();
  }

  void setCamera(GeoPoint center, double zoom) {
    this.center = GeoPoint(center.lat.clamp(-85.0, 85.0), center.lng);
    this.zoom = zoom.clamp(3.0, 18.0).toDouble();
    notifyListeners();
  }
}

class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.controller,
    this.me,
    this.selected,
    this.route = const [],
    this.onMarkerTap,
    this.onMapTap,
  });

  final MapCanvasController controller;
  final GeoPoint? me;
  final Place? selected;
  final List<GeoPoint> route;
  final ValueChanged<Place>? onMarkerTap;
  final VoidCallback? onMapTap;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  late GeoPoint _center;
  late double _zoom;

  late GeoPoint _gestureCenter;
  late double _gestureZoom;
  Offset _gestureFocal = Offset.zero;
  Size _viewport = Size.zero;
  bool _applyingProgrammaticMove = false;

  @override
  void initState() {
    super.initState();
    _center = widget.controller.center;
    _zoom = widget.controller.zoom;
    _gestureCenter = _center;
    _gestureZoom = _zoom;
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _handleControllerChange();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted || _applyingProgrammaticMove) return;
    setState(() {
      _center = widget.controller.center;
      _zoom = widget.controller.zoom;
    });
  }

  void _applyCamera(GeoPoint center, double zoom) {
    _applyingProgrammaticMove = true;
    widget.controller.setCamera(center, zoom);
    _applyingProgrammaticMove = false;
    if (!mounted) return;
    setState(() {
      _center = widget.controller.center;
      _zoom = widget.controller.zoom;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureCenter = _center;
    _gestureZoom = _zoom;
    _gestureFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_viewport.isEmpty) return;
    final newZoom = (_gestureZoom + math.log(details.scale) / math.ln2)
        .clamp(3.0, 18.0)
        .toDouble();
    final screenCenter = Offset(_viewport.width / 2, _viewport.height / 2);
    final anchorWorld =
        MapProjection.world(_gestureCenter, _gestureZoom) +
            (_gestureFocal - screenCenter);
    final anchor = MapProjection.unproject(anchorWorld, _gestureZoom);
    final movedWorld = MapProjection.world(anchor, newZoom) -
        (details.localFocalPoint - screenCenter);
    final newCenter = MapProjection.unproject(movedWorld, newZoom);
    _applyCamera(newCenter, newZoom);
  }

  void _onTapUp(TapUpDetails details) {
    final selected = widget.selected;
    if (selected != null) {
      final projection = _ViewProjection(_center, _zoom, _viewport);
      final position = projection.toScreen(selected.location);
      if ((position - details.localPosition).distance <= 48) {
        widget.onMarkerTap?.call(selected);
        return;
      }
    }
    widget.onMapTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapUp: _onTapUp,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MapPainter(
                center: _center,
                zoom: _zoom,
                me: widget.me,
                selected: widget.selected,
                route: widget.route,
                isDark: theme.brightness == Brightness.dark,
                surface: theme.colorScheme.surface,
                primary: theme.colorScheme.primary,
                onSurface: theme.colorScheme.onSurface,
                onSurfaceVariant: theme.colorScheme.onSurfaceVariant,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewProjection {
  _ViewProjection(this.center, this.zoom, this.size)
      : _centerWorld = MapProjection.world(center, zoom);

  final GeoPoint center;
  final double zoom;
  final Size size;
  final Offset _centerWorld;

  Offset toScreen(GeoPoint point) {
    return MapProjection.world(point, zoom) -
        _centerWorld +
        Offset(size.width / 2, size.height / 2);
  }

  GeoPoint fromScreen(Offset position) {
    final world = _centerWorld +
        (position - Offset(size.width / 2, size.height / 2));
    return MapProjection.unproject(world, zoom);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.center,
    required this.zoom,
    required this.me,
    required this.selected,
    required this.route,
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.textDirection,
  });

  final GeoPoint center;
  final double zoom;
  final GeoPoint? me;
  final Place? selected;
  final List<GeoPoint> route;
  final bool isDark;
  final Color surface;
  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final TextDirection textDirection;

  static const List<double> _steps = [
    0.0005,
    0.001,
    0.002,
    0.004,
    0.008,
    0.016,
    0.032,
    0.064,
    0.125,
    0.25,
    0.5,
    1,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final projection = _ViewProjection(center, zoom, size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = isDark ? const Color(0xFF0E1915) : const Color(0xFFEDF2EC),
    );

    final step = _stepForZoom();
    final northWest = projection.fromScreen(Offset.zero);
    final southEast = projection.fromScreen(Offset(size.width, size.height));
    final south = math.min(northWest.lat, southEast.lat);
    final north = math.max(northWest.lat, southEast.lat);
    final west = math.min(northWest.lng, southEast.lng);
    final east = math.max(northWest.lng, southEast.lng);

    _paintBlocks(canvas, size, projection, step, south, north, west, east);
    _paintWater(canvas, projection);
    _paintRoads(canvas, size, projection, step, south, north, west, east);
    _paintRoute(canvas, projection);
    _paintMarkers(canvas, size, projection);
    _paintScale(canvas, size);
  }

  double _stepForZoom() {
    final pixelsPerDegree = MapProjection.tileSize * math.pow(2, zoom) / 360;
    for (final step in _steps) {
      if (step * pixelsPerDegree >= 88) return step;
    }
    return _steps.last;
  }

  void _paintBlocks(
    Canvas canvas,
    Size size,
    _ViewProjection projection,
    double step,
    double south,
    double north,
    double west,
    double east,
  ) {
    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF16231E) : const Color(0xFFF7FAF6);
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF1C3326) : const Color(0xFFD8EBD6);
    final buildingPaint = Paint()
      ..color = isDark ? const Color(0xFF1B2A24) : const Color(0xFFE3EBE4);

    final latStart = (south / step).floor();
    final latEnd = (north / step).ceil();
    final lngStart = (west / step).floor();
    final lngEnd = (east / step).ceil();
    if ((latEnd - latStart) * (lngEnd - lngStart) > 4000) return;

    for (var latIndex = latStart; latIndex <= latEnd; latIndex++) {
      for (var lngIndex = lngStart; lngIndex <= lngEnd; lngIndex++) {
        final lat = latIndex * step;
        final lng = lngIndex * step;
        final topLeft = projection.toScreen(GeoPoint(lat + step, lng));
        final bottomRight = projection.toScreen(GeoPoint(lat, lng + step));
        final rect = Rect.fromPoints(topLeft, bottomRight).deflate(5);
        if (rect.width <= 1 || rect.height <= 1) continue;

        final hash = _hash(latIndex, lngIndex);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          blockPaint,
        );

        if (hash % 7 == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            parkPaint,
          );
          continue;
        }

        if (hash % 3 == 0) {
          final inset = rect.deflate(rect.width * 0.22);
          if (inset.width > 3 && inset.height > 3) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(inset, const Radius.circular(2)),
              buildingPaint,
            );
          }
        }
      }
    }
  }

  void _paintWater(Canvas canvas, _ViewProjection projection) {
    const river = [
      GeoPoint(11.625, 104.900),
      GeoPoint(11.604, 104.906),
      GeoPoint(11.586, 104.914),
      GeoPoint(11.570, 104.926),
      GeoPoint(11.556, 104.934),
      GeoPoint(11.540, 104.944),
      GeoPoint(11.520, 104.956),
      GeoPoint(11.498, 104.974),
    ];
    const branch = [
      GeoPoint(11.592, 104.914),
      GeoPoint(11.578, 104.920),
      GeoPoint(11.566, 104.925),
    ];

    final waterPaint = Paint()
      ..color = isDark ? const Color(0xFF14303A) : const Color(0xFFB9DCEA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawRiver(List<GeoPoint> points, double width) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final position = projection.toScreen(points[i]);
        if (i == 0) {
          path.moveTo(position.dx, position.dy);
        } else {
          path.lineTo(position.dx, position.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = waterPaint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawRiver(river, 28);
    drawRiver(branch, 14);
  }

  void _paintRoads(
    Canvas canvas,
    Size size,
    _ViewProjection projection,
    double step,
    double south,
    double north,
    double west,
    double east,
  ) {
    final casing = Paint()
      ..color = isDark ? const Color(0xFF1A2722) : const Color(0xFFDCE5DD)
      ..style = PaintingStyle.stroke;
    final majorPaint = Paint()
      ..color = isDark ? const Color(0xFF2B3A34) : Colors.white
      ..style = PaintingStyle.stroke;
    final minorPaint = Paint()
      ..color = isDark ? const Color(0xFF212F29) : const Color(0xFFF8FBF8)
      ..style = PaintingStyle.stroke;

    final latStart = (south / step).floor();
    final latEnd = (north / step).ceil();
    for (var latIndex = latStart; latIndex <= latEnd; latIndex++) {
      final y = projection.toScreen(GeoPoint(latIndex * step, center.lng)).dy;
      if (y < -20 || y > size.height + 20) continue;
      final major = latIndex % 4 == 0;
      if (major) {
        canvas.drawLine(
          Offset(-10, y),
          Offset(size.width + 10, y),
          casing..strokeWidth = 9,
        );
        canvas.drawLine(
          Offset(-10, y),
          Offset(size.width + 10, y),
          majorPaint..strokeWidth = 6.5,
        );
      } else {
        canvas.drawLine(
          Offset(-10, y),
          Offset(size.width + 10, y),
          minorPaint..strokeWidth = 2.4,
        );
      }
    }

    final lngStart = (west / step).floor();
    final lngEnd = (east / step).ceil();
    for (var lngIndex = lngStart; lngIndex <= lngEnd; lngIndex++) {
      final x = projection.toScreen(GeoPoint(center.lat, lngIndex * step)).dx;
      if (x < -20 || x > size.width + 20) continue;
      final major = lngIndex % 4 == 0;
      if (major) {
        canvas.drawLine(
          Offset(x, -10),
          Offset(x, size.height + 10),
          casing..strokeWidth = 9,
        );
        canvas.drawLine(
          Offset(x, -10),
          Offset(x, size.height + 10),
          majorPaint..strokeWidth = 6.5,
        );
      } else {
        canvas.drawLine(
          Offset(x, -10),
          Offset(x, size.height + 10),
          minorPaint..strokeWidth = 2.4,
        );
      }
    }
  }

  void _paintRoute(Canvas canvas, _ViewProjection projection) {
    if (route.length < 2) return;
    final path = Path();
    for (var i = 0; i < route.length; i++) {
      final position = projection.toScreen(route[i]);
      if (i == 0) {
        path.moveTo(position.dx, position.dy);
      } else {
        path.lineTo(position.dx, position.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = isDark ? const Color(0xFF0B1411) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintMarkers(Canvas canvas, Size size, _ViewProjection projection) {
    final viewport = Offset.zero & size;

    final mePoint = me;
    if (mePoint != null) {
      final position = projection.toScreen(mePoint);
      if (viewport.inflate(40).contains(position)) {
        canvas.drawCircle(
          position,
          22,
          Paint()..color = const Color(0xFF2F80ED).withValues(alpha: 0.16),
        );
        canvas.drawCircle(position, 8.5, Paint()..color = Colors.white);
        canvas.drawCircle(position, 6, Paint()..color = const Color(0xFF2F80ED));
      }
    }

    final place = selected;
    if (place == null) return;
    final tip = projection.toScreen(place.location);
    if (!viewport.inflate(80).contains(tip)) return;

    const radius = 13.0;
    final circleCenter = tip - const Offset(0, 19);

    final shadow = Path()
      ..addOval(
        Rect.fromCenter(center: circleCenter, width: radius * 2, height: radius * 2),
      )
      ..moveTo(circleCenter.dx - radius * 0.7, circleCenter.dy + radius * 0.6)
      ..lineTo(circleCenter.dx + radius * 0.7, circleCenter.dy + radius * 0.6)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(shadow, Colors.black, 8, false);

    final pin = Path()
      ..addOval(
        Rect.fromCenter(center: circleCenter, width: radius * 2, height: radius * 2),
      )
      ..moveTo(circleCenter.dx - radius * 0.7, circleCenter.dy + radius * 0.6)
      ..lineTo(circleCenter.dx + radius * 0.7, circleCenter.dy + radius * 0.6)
      ..lineTo(tip.dx, tip.dy)
      ..close();

    canvas.drawPath(pin, Paint()..color = primary);
    canvas.drawCircle(circleCenter, 5, Paint()..color = Colors.white);

    final label = TextPainter(
      text: TextSpan(
        text: place.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: textDirection,
    )..layout(maxWidth: 190);

    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          circleCenter.dx,
          circleCenter.dy - radius - 10 - label.height / 2,
        ),
        width: label.width + 20,
        height: label.height + 10,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bubble, Paint()..color = surface);
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = onSurfaceVariant.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    label.paint(
      canvas,
      Offset(bubble.left + 10, bubble.top + 5),
    );
  }

  void _paintScale(Canvas canvas, Size size) {
    final metersPerPixel = MapProjection.metersPerPixel(center, zoom);
    const candidates = [25, 50, 100, 200, 500, 1000, 2000, 5000, 10000];
    var target = candidates.first;
    var targetPixels = target / metersPerPixel;
    for (final candidate in candidates) {
      final pixels = candidate / metersPerPixel;
      if (pixels >= 56 && pixels <= 132) {
        target = candidate;
        targetPixels = pixels;
        break;
      }
    }

    final y = size.height - 22;
    const x = 18.0;
    final paint = Paint()
      ..color = onSurface.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y), Offset(x + targetPixels, y), paint);
    canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), paint);
    canvas.drawLine(
      Offset(x + targetPixels, y - 4),
      Offset(x + targetPixels, y + 4),
      paint,
    );

    final label = TextPainter(
      text: TextSpan(
        text: target >= 1000
            ? '${(target / 1000).toStringAsFixed(target % 1000 == 0 ? 0 : 1)} km'
            : '$target m',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariant,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    label.paint(canvas, Offset(x, y - label.height - 8));
  }

  static int _hash(int x, int y) {
    var value = x * 374761393 + y * 668265263;
    value = (value ^ (value >> 13)) * 1274126177;
    return value & 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.zoom != zoom ||
        oldDelegate.me != me ||
        oldDelegate.selected != selected ||
        oldDelegate.isDark != isDark ||
        !listEquals(oldDelegate.route, route);
  }
}
