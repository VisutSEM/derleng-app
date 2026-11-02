import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../models/geo_point.dart';
import '../../../models/place.dart';
import '../explore_controller.dart';
import 'nearby_bar.dart';
import 'place_visuals.dart';

class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onRetry,
    required this.onRetryNearby,
    required this.onClearNearby,
    required this.onClearRecent,
  });

  final ExploreState state;
  final ValueChanged<Place> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onRetryNearby;
  final VoidCallback onClearNearby;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        constraints: const BoxConstraints(maxHeight: 400),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final nearby = state.nearbyCategory;
    if (nearby != null) {
      if (state.nearbyLoading) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: const [
            _SkeletonTile(),
            _SkeletonTile(),
            _SkeletonTile(),
          ],
        );
      }

      if (state.nearbyError != null) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: ErrorBanner(
            message: state.nearbyError!,
            onRetry: onRetryNearby,
          ),
        );
      }

      if (state.nearby.isEmpty) {
        return _Message(
          icon: Icons.location_off_rounded,
          title: 'Nothing nearby',
          message:
              'No ${nearby.label.toLowerCase()} found around this spot. Try another category.',
        );
      }

      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
            child: Row(
              children: [
                Icon(
                  iconForNearbyCategory(nearby),
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Nearby ${nearby.label.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${state.nearby.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClearNearby,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Flexible(
            child: _ResultList(
              places: state.nearby,
              me: state.me,
              onSelect: onSelect,
              padded: false,
            ),
          ),
        ],
      );
    }

    if (state.searching) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: const [
          _SkeletonTile(),
          _SkeletonTile(),
          _SkeletonTile(),
        ],
      );
    }

    if (state.searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ErrorBanner(message: state.searchError!, onRetry: onRetry),
      );
    }

    final query = state.query.trim();
    if (query.length >= 2) {
      if (state.results.isEmpty) {
        return const _Message(
          icon: Icons.search_off_rounded,
          title: 'No places found',
          message: 'Try a different name, address or category.',
        );
      }
      return _ResultList(
        places: state.results,
        me: state.me,
        onSelect: onSelect,
      );
    }

    if (state.recent.isEmpty) {
      return const _Message(
        icon: Icons.travel_explore_rounded,
        title: 'Search Derleng',
        message: 'Type at least 2 characters to find places, food and landmarks.',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
          child: Row(
            children: [
              Text(
                'Recent',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClearRecent,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Flexible(
          child: _ResultList(
            places: state.recent,
            me: state.me,
            onSelect: onSelect,
            padded: false,
          ),
        ),
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.places,
    required this.me,
    required this.onSelect,
    this.padded = true,
  });

  final List<Place> places;
  final GeoPoint? me;
  final ValueChanged<Place> onSelect;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: padded ? 6 : 0),
      itemCount: places.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final place = places[index];
        final distance = me == null
            ? null
            : formatDistance(place.location.distanceTo(me!));
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          leading: PlaceAvatar(category: place.category),
          title: Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            place.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          trailing: distance == null
              ? const Icon(Icons.chevron_right_rounded, size: 20)
              : Text(
                  distance,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          onTap: () => onSelect(place),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: scheme.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar({required double width, double height = 10}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 150, height: 11),
              const SizedBox(height: 8),
              bar(width: 210),
            ],
          ),
        ],
      ),
    );
  }
}
