import 'package:flutter/material.dart';

IconData iconForCategory(String? category) {
  return switch (category) {
    'landmark' => Icons.account_balance_rounded,
    'temple' => Icons.temple_buddhist_rounded,
    'museum' => Icons.museum_rounded,
    'market' => Icons.storefront_rounded,
    'mall' => Icons.local_mall_rounded,
    'park' || 'nature' => Icons.park_rounded,
    'restaurant' || 'food' => Icons.restaurant_rounded,
    'cafe' || 'coffee' => Icons.local_cafe_rounded,
    'hotel' => Icons.hotel_rounded,
    'airport' => Icons.flight_rounded,
    'stadium' => Icons.stadium_rounded,
    'nightlife' => Icons.nightlife_rounded,
    _ => Icons.place_rounded,
  };
}

Color colorForCategory(String? category) {
  return switch (category) {
    'landmark' => const Color(0xFF0F766E),
    'temple' => const Color(0xFFB45309),
    'museum' => const Color(0xFF7C3AED),
    'market' => const Color(0xFFDB2777),
    'mall' => const Color(0xFF2563EB),
    'park' || 'nature' => const Color(0xFF16A34A),
    'restaurant' || 'food' => const Color(0xFFEA580C),
    'cafe' || 'coffee' => const Color(0xFF92400E),
    'hotel' => const Color(0xFF0891B2),
    'airport' => const Color(0xFF475569),
    'stadium' => const Color(0xFF059669),
    'nightlife' => const Color(0xFFE11D48),
    _ => const Color(0xFF64748B),
  };
}

class PlaceAvatar extends StatelessWidget {
  const PlaceAvatar({
    super.key,
    required this.category,
    this.size = 42,
  });

  final String? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        iconForCategory(category),
        size: size * 0.5,
        color: isDark ? color.withValues(alpha: 0.95) : color,
      ),
    );
  }
}
