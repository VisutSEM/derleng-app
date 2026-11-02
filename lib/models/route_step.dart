import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import 'geo_point.dart';

/// Represents a turn-by-turn instruction or maneuver along a route.
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    this.streetName,
    this.maneuverType = 'turn',
    this.modifier,
  });

  final String instruction;
  final int distanceMeters;
  final int durationSeconds;
  final GeoPoint location;
  final String? streetName;
  final String maneuverType; // 'depart', 'turn', 'arrive', 'continue', etc.
  final String? modifier; // 'left', 'right', 'slight left', 'slight right', 'sharp left', 'sharp right', 'straight', 'uturn'

  String get distanceLabel => formatDistance(distanceMeters);
  String get durationLabel => formatDuration(durationSeconds);

  /// Appropriate icon for this maneuver.
  IconData get icon {
    final type = maneuverType.toLowerCase();
    final mod = (modifier ?? '').toLowerCase();

    if (type.contains('arrive')) {
      return Icons.flag_rounded;
    }
    if (type.contains('depart')) {
      return Icons.navigation_rounded;
    }
    if (type.contains('roundabout') || type.contains('rotary')) {
      return Icons.roundabout_right_rounded;
    }
    if (type.contains('uturn') || mod.contains('uturn')) {
      return Icons.u_turn_right_rounded;
    }

    if (mod.contains('sharp left')) {
      return Icons.turn_sharp_left_rounded;
    } else if (mod.contains('slight left')) {
      return Icons.turn_slight_left_rounded;
    } else if (mod.contains('left')) {
      return Icons.turn_left_rounded;
    } else if (mod.contains('sharp right')) {
      return Icons.turn_sharp_right_rounded;
    } else if (mod.contains('slight right')) {
      return Icons.turn_slight_right_rounded;
    } else if (mod.contains('right')) {
      return Icons.turn_right_rounded;
    }

    return Icons.straight_rounded;
  }
}
