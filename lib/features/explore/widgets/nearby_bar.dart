import 'package:flutter/material.dart';

import '../../../models/nearby_category.dart';

IconData iconForNearbyCategory(NearbyCategory category) {
  return switch (category) {
    NearbyCategory.restaurant => Icons.restaurant_rounded,
    NearbyCategory.cafe => Icons.local_cafe_rounded,
    NearbyCategory.hotel => Icons.hotel_rounded,
    NearbyCategory.attraction => Icons.account_balance_rounded,
    NearbyCategory.park => Icons.park_rounded,
    NearbyCategory.market => Icons.storefront_rounded,
  };
}

/// Horizontal category chips used for quick discovery around the map.
class NearbyCategoryBar extends StatelessWidget {
  const NearbyCategoryBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NearbyCategory? selected;
  final ValueChanged<NearbyCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: NearbyCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = NearbyCategory.values[index];
          final isSelected = category == selected;
          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            avatar: Icon(
              iconForNearbyCategory(category),
              size: 17,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            label: Text(category.label),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? scheme.primary : scheme.onSurface,
            ),
            backgroundColor: scheme.surface,
            selectedColor: scheme.primary.withValues(alpha: 0.13),
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            side: BorderSide(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}
