import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/geo_point.dart';
import '../../../models/place.dart';
import '../../../models/route_info.dart';
import '../../../models/travel_mode.dart';
import '../../home/widgets/create_post_sheet.dart';
import 'place_visuals.dart';

IconData iconForMode(TravelMode mode) {
  return switch (mode) {
    TravelMode.driving => Icons.directions_car_rounded,
    TravelMode.walking => Icons.directions_walk_rounded,
    TravelMode.transit => Icons.directions_transit_rounded,
    TravelMode.bicycling => Icons.directions_bike_rounded,
  };
}

class PlaceSheet extends StatelessWidget {
  const PlaceSheet({
    super.key,
    required this.place,
    required this.mode,
    required this.isFavorite,
    required this.me,
    required this.route,
    required this.routeLoading,
    required this.routeError,
    required this.onModeChanged,
    required this.onClose,
    required this.onRetry,
    required this.onStart,
    required this.onToggleFavorite,
  });

  final Place place;
  final TravelMode mode;
  final bool isFavorite;
  final GeoPoint? me;
  final RouteInfo? route;
  final bool routeLoading;
  final String? routeError;
  final ValueChanged<TravelMode> onModeChanged;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback onStart;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        elevation: 14,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlaceAvatar(category: place.category, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        _MetaLine(place: place, me: me, route: route),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleFavorite,
                    tooltip: isFavorite ? 'Remove from saved' : 'Save place',
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        CreatePostSheet.show(context, initialPlace: place),
                    tooltip: 'Post a story',
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TravelMode>(
                segments: TravelMode.values
                    .map(
                      (value) => ButtonSegment<TravelMode>(
                        value: value,
                        icon: Icon(iconForMode(value), size: 20),
                        tooltip: value.label,
                      ),
                    )
                    .toList(growable: false),
                selected: {mode},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: (selection) =>
                    onModeChanged(selection.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 12),
              _RouteSummary(
                mode: mode,
                route: route,
                loading: routeLoading,
                error: routeError,
                onRetry: onRetry,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text('Start navigation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.place, required this.me, required this.route});

  final Place place;
  final GeoPoint? me;
  final RouteInfo? route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    final distance = route?.distanceLabel ??
        (me == null ? null : formatDistance(place.location.distanceTo(me!)));

    return Row(
      children: [
        if (place.rating != null) ...[
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 2),
          Text(
            formatRating(place.rating!),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (place.ratingCount != null) ...[
            const SizedBox(width: 3),
            Text(
              '(${_compactCount(place.ratingCount!)})',
              style: muted,
            ),
          ],
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: scheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (distance != null)
          Flexible(
            child: Text(
              route != null ? '$distance route' : '$distance away',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          )
        else
          Flexible(
            child: Text(
              'Tap a travel mode to see the route',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
      ],
    );
  }

  static String _compactCount(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return '$value';
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.mode,
    required this.route,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final TravelMode mode;
  final RouteInfo? route;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (loading) {
      return _Surface(
        color: scheme.primary.withValues(alpha: 0.07),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Finding the best ${mode.label.toLowerCase()} route…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return _Surface(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final info = route;
    if (info == null) {
      return _Surface(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(iconForMode(mode), size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Directions are calculated from your current location.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return _Surface(
      color: scheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(iconForMode(mode), size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Text(
            info.durationLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text('·', style: TextStyle(color: scheme.outline)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.distanceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            mode.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
